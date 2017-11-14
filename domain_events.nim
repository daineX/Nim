from logging import debug, info, warn, addHandler, newConsoleLogger
from json import JsonNode, parseJson, `{}`, `[]`, getNum, getStr, getFNum, JsonParsingError, contains, `%*`, `%`
from sequtils import insert, concat, deduplicate
from strutils import `%`
from tables import Table, initTable, `[]`, `[]=`

import librabbitmq

type
    DomainEvent* = ref object of RootObj
        routing_key: string
        data: JsonNode
        domain_object_id: int
        uuid_string: string
        timestamp: float
        retries: uint
    consume_callback* = proc(event: DomainEvent)
    Handler* = ref object of RootObj
        callback: consume_callback
        max_retries: uint
    Transport* = ref object of RootObj
        current_channel: Channel
        conn: PConnectionState
        exchange: cstring
        exchange_type: cstring
        handlers: Table[string, Handler]
    Retry* = ref object of Exception
        delay: float

const
    FALSE* = Boolean(false)
    TRUE* = Boolean(true)


proc channel*(transport: Transport): Channel =
    return transport.current_channel

proc `channel=`*(transport: Transport, new_channel: Channel) =
    transport.current_channel = new_channel

proc check*(transport: Transport) =
    check(transport.conn)

proc next_channel*(transport: Transport): Channel =
    let channel = transport.channel
    if channel <= MAX_CHANNELS:
        transport.channel = channel
        return transport.channel
    return 0

proc newTransport*(host: cstring, port: cint, vhost: cstring, user: cstring, password: cstring, exchange: cstring = "domain-events", exchange_type: cstring = "topic"): Transport =
    var
        conn = connect(host, port, vhost, user, password)
        channel: Channel = 1
    discard channel_open(conn, channel)
    discard exchange_declare(conn, channel, cstring_bytes(exchange), cstring_bytes(exchange_type), FALSE, TRUE, FALSE, FALSE, empty_arguments)
    check(conn)
    return Transport(conn: conn,
                     current_channel: channel,
                     exchange: exchange,
                     exchange_type: exchange_type,
                     handlers: initTable[string, Handler]())


proc exchange_declare*(transport: Transport, exchange: string, passive: bool = false, durable: bool = false, auto_delete: bool = false, internal: bool = false, arguments: Arguments = empty_arguments) =
    discard exchange_declare(transport.conn, transport.channel, cstring_bytes(exchange), cstring_bytes(transport.exchange_type), Boolean(passive), Boolean(durable), Boolean(auto_delete), Boolean(internal), arguments)

proc queue_declare*(transport: Transport, queue_name: string, passive: bool = false, durable: bool = false, exclusive: bool = false, auto_delete: bool = false, arguments: Arguments = empty_arguments) =
    discard queue_declare(transport.conn, transport.channel, cstring_bytes(queue_name), Boolean(passive), Boolean(durable), Boolean(exclusive), Boolean(auto_delete), arguments)

proc newDomainEvent*(data: JsonNode, routing_key: string = "", domain_object_id: int = 0, uuid_string: string = "", timestamp: float = 0.0, retries: uint = 0): DomainEvent =
    return DomainEvent(routing_key: routing_key,
                       data: data,
                       domain_object_id: domain_object_id,
                       uuid_string: uuid_string,
                       timestamp: timestamp,
                       retries: retries)


proc newDomainEventFromJson*(json_msg: string): DomainEvent =
    let
        jsonNode = parseJson(json_msg)
        data = jsonNode["data"]
        routing_key = jsonNode{"routing_key"}.getStr()
        domain_object_id = int(jsonNode{"domain_object_id"}.getNum())
        uuid_string = jsonNode{"uuid_string"}.getStr()
        timestamp = jsonNode{"timestamp"}.getFNum()
        retries = uint(jsonNode{"retries"}.getNum())
    return newDomainEvent(routing_key=routing_key,
                          data=data,
                          domain_object_id=domain_object_id,
                          uuid_string=uuid_string,
                          timestamp=timestamp,
                          retries=retries)


proc bind_routing_keys(transport: Transport, exchange: cstring, queue_name: cstring, binding_keys: seq[string]) =
    for binding_key in binding_keys:
        queue_bind(transport.conn, transport.channel, cstring_bytes(queue_name), cstring_bytes(exchange), cstring_bytes(binding_key), empty_arguments)
        transport.check

proc register*(transport: Transport, callback: consume_callback, name: string, binding_keys: seq[string], dead_letter: bool = false, durable: bool = true, exclusive: bool = false, auto_delete: bool = false, max_retries: uint = 0) =
    let
        channel = transport.channel
        retry_exchange = name & "-retry"
        delay_exchange = name & "-delay"
        dead_letter_exchange = name & "-dlx"
        wait_queue = name & "-wait"
        dead_letter_queue = name & "-dl"

    var
        arguments: Arguments
        retry_arguments: Arguments

    # Create main queue
    if dead_letter:
        transport.queue_declare(dead_letter_queue, durable=true)
        transport.exchange_declare(dead_letter_exchange)
        transport.bind_routing_keys(dead_letter_exchange, dead_letter_queue, binding_keys)
        arguments = makeArguments(%* {"x-dead-letter-exchange": dead_letter_exchange})
    else:
        arguments = empty_arguments
    transport.queue_declare(name, durable=durable, exclusive=exclusive, auto_delete=auto_delete, arguments=arguments)
    transport.check
    transport.bind_routing_keys(transport.exchange, name, binding_keys)

    # Create wait queue for retries
    transport.exchange_declare(retry_exchange)
    transport.exchange_declare(delay_exchange)
    retry_arguments = makeArguments(%* {"x-dead-letter-exchange": retry_exchange})
    transport.queue_declare(wait_queue, durable=durable, arguments=retry_arguments)

    transport.bind_routing_keys(delay_exchange, wait_queue, binding_keys)
    transport.bind_routing_keys(retry_exchange, name, binding_keys)

    discard basic_qos(transport.conn, channel, prefetch_count=1)
    transport.check
    discard basic_consume(transport.conn, channel, cstring_bytes(name), cstring_bytes(name), FALSE, FALSE, FALSE, empty_arguments)
    transport.check
    transport.handlers[name] = Handler(callback: callback, max_retries: max_retries)

proc start_consuming*(transport: Transport) =
    while true:
        let
            msg = get_message(transport.conn)
            handler = transport.handlers[msg.consumer_tag]
        var
            event: DomainEvent
            headers = jsonFromArguments(msg.properties.headers)
            props = msg.properties
        try:
            event = newDomainEventFromJson(msg.content)
        except JsonParsingError, KeyError:
            warn "Invalid JSON \"$#\"" % [msg.content]
            reject_message(transport.conn, msg.channel, msg, requeue=false)
            continue

        if headers.contains("x-death"):
            event.retries = uint(headers{"x-death"}[0]{"count"}.getNum)

        try:
            handler.callback(event)
            ack_message(transport.conn, msg.channel, msg)
        except Retry:
            let
                error = Retry(getCurrentException())
                delay_exchange = msg.consumer_tag & "-delay"
            if event.retries < handler.max_retries:
                info "Retrying event \"$#\" in $#s" % [msg.routing_key, $ error.delay]
                ack_message(transport.conn, msg.channel, msg)

                props.setExpiration(error.delay)
                publish_message(transport.conn, msg.channel, exchange=delay_exchange, routing_key=msg.routing_key, body=msg.content, properties=props)
            else:
                info "Exceeded max retries ($#) for event \"$#\"" % [$ handler.max_retries, event.routing_key]
                reject_message(transport.conn, msg.channel, msg, requeue=false)
        except:
            reject_message(transport.conn, msg.channel, msg, requeue=false)


when isMainModule:
    from json import pretty
    from math import pow

    addHandler(newConsoleLogger())

    var t = newTransport("localhost", 5672, "/", "guest", "guest")
    proc handle_keyboard_interrupt() {.noconv.} =
        destroy_connection(t.conn)
        debug "Destroyed connection."
        quit 0
    setControlCHook(handle_keyboard_interrupt)

    proc print_message(event: DomainEvent) =
        info "Routing Key: " & event.routing_key
        info "Message: " & event.data.pretty()

    proc handle_foobar(event: DomainEvent) =
        info "This is foobar: " & event.data.pretty()

    proc always_retry(event: DomainEvent) =
        raise Retry(delay: pow(2, float(event.retries) + 1.0))

    t.register(print_message, "print-message", @["#"], dead_letter=true)
    t.register(handle_foobar, "foobar-handler", @["foobar"], dead_letter=true)
    t.register(always_retry, "retry-handler", @["retry"], max_retries=3)
    t.start_consuming()
