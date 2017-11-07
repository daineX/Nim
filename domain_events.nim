from json import JsonNode, parseJson, `{}`, `[]`, getNum, getStr, getFNum, JsonParsingError
import tables
from sequtils import insert, concat, deduplicate
from librabbitmq import exchange_declare, queue_declare, queue_bind, Channel, PConnectionState, connect, MAX_CHANNELS, cstring_bytes, empty_table, Boolean, basic_qos, empty_bytes, basic_consume, get_message, ack_message, check, channel_open, bytes_string, reject_message
from strutils import `%`


type
    DomainEvent* = ref object of RootObj
        routing_key: string
        data: JsonNode
        domain_object_id: int
        uuid_string: string
        timestamp: float
        retries: uint
    consume_callback* = proc(event: DomainEvent)
    Transport* = ref object of RootObj
        current_channel: Channel
        conn: PConnectionState
        exchange: cstring
        handlers: Table[string, consume_callback]
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
    discard exchange_declare(conn, channel, cstring_bytes(exchange), cstring_bytes(exchange_type), FALSE, TRUE, FALSE, FALSE, empty_table)
    check(conn)
    return Transport(conn: conn,
                     current_channel: channel,
                     exchange: exchange,
                     handlers: initTable[string, consume_callback]())


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


proc bind_routing_keys(transport: Transport, queue_name: cstring, binding_keys: seq[string], handler: consume_callback) =
    for binding_key in binding_keys:
        queue_bind(transport.conn, transport.channel, cstring_bytes(queue_name), cstring_bytes(transport.exchange), cstring_bytes(binding_key), empty_table)
        transport.check

proc register*(transport: Transport, handler: consume_callback, name: string, binding_keys: seq[string], dead_letter: bool = false, durable: bool = true, exclusive: bool = false, auto_delete: bool = false, max_retries: uint = 0) =
    let channel = transport.channel
    discard queue_declare(transport.conn, channel, cstring_bytes(name), FALSE, Boolean(durable), Boolean(exclusive), Boolean(auto_delete), empty_table)
    transport.bind_routing_keys(name, binding_keys, handler)
    discard basic_qos(transport.conn, channel, prefetch_count=1)
    transport.check
    discard basic_consume(transport.conn, channel, cstring_bytes(name), cstring_bytes(name), FALSE, FALSE, FALSE, empty_table)
    transport.check
    transport.handlers[name] = handler

proc start_consuming*(transport: Transport) =
    while true:
        let
            msg = get_message(transport.conn)
            handler = transport.handlers[msg.consumer_tag]
        echo msg.content
        try:
            let event = newDomainEventFromJson(msg.content)
            handler(event)
            ack_message(transport.conn, msg.channel, msg)
        except JsonParsingError:
            echo """Invalid JSON "$#"""" % [msg.content]
            reject_message(transport.conn, msg.channel, msg)


when isMainModule:
    from librabbitmq import destroy_connection
    from json import pretty
    var t = newTransport("localhost", 5672, "/", "guest", "guest")
    proc handle_keyboard_interrupt() {.noconv.} =
        destroy_connection(t.conn)
        echo "Destroyed connection."
        quit 0
    setControlCHook(handle_keyboard_interrupt)

    proc print_message(event:DomainEvent) =
        echo "Routing Key: $#" % [event.routing_key]
        echo "Message: $#" % [event.data.pretty()]
        echo()

    proc handle_foobar(event:DomainEvent) =
        echo "This is foobar: $#" % [event.data.pretty()]
        echo()

    t.register(print_message, "print-message", @["#"])
    t.register(handle_foobar, "foobar-handler", @["foobar"])
    t.start_consuming()
