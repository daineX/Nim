when defined(windows):
  const
    rmqdll* = "librabbitmq.dll"
elif defined(macosx):
  const
    rmqdll* = "librabbitmq.dylib"
else:
  const
    rmqdll* = "librabbitmq.so.4"

from posix import Timeval
from json import JsonNode, newJArray, newJString, newJObject, add, newJInt, len, pairs, JString, JInt, getNum, JObject

type
    Decimal* = object
        decimals*: Boolean
        value*: cuint
    FieldValueValue* {.union.} = object
        boolean*: Boolean
        i8*: cchar
        u8*: Boolean
        i16*: cshort
        u16*: cushort
        i32*: cint
        u32*: cuint
        i64*: clong
        u64*: culong
        f32*: cfloat
        f64*: cdouble
        decimal*: Decimal
        bytes*: Bytes
        table*: Arguments
        array_array*: Array
    FieldValue* {.final, pure.} = object
        kind*: Boolean
        value*: FieldValueValue
    Array* = object
        num_entries*: cint
        entries: ptr FieldValue
    FieldValueArray* {.unchecked.} = array[0, FieldValue]
    Bytes* = object
        len*: csize
        bytes*: ptr cchar
    FramePayloadProperties* = object
        class_id: cushort
        body_size: culong
        decoded: pointer
        raw: Bytes

    FramePayloadProtocolHeader* = object
        transport_high: Boolean
        transport_low: Boolean
        protocol_version_major: Boolean
        protocol_version_minor: Boolean

    FramePayload* {.union.} = object
        method_method: Method
        properties: FramePayloadProperties
        body_fragment: Bytes
        protocol_header: FramePayloadProtocolHeader
    Frame* {.final, pure.} = object
        frame_type: Boolean
        channel: Channel
        payload: FramePayload

    Method* {.final, pure.} = object
        id: cuint
        decoded: pointer
    PoolBlockList* {.final, pure.} = object
        num_blocks*: cint
        blocklist*: ptr pointer
    Pool* {.final, pure.} = object
        pagesize*: csize
        pages*: PoolBlockList
        lage_blocks*: PoolBlockList
        next_page*: cint
        alloc_block*: ptr cchar
        alloc_size*: csize
    ResponseTypeEnum* = enum
        AMQP_RESPONSE_NONE
        AMQP_RESPONSE_NORMAL
        AMQP_RESPONSE_LIBRARY_EXCEPTION
        AMQP_RESPONSE_SERVER_EXCEPTION
    RPCReply* {.final, pure.} = object
        reply_type*: ResponseTypeEnum
        reply*: Method
        library_error: cint
    ArgumentArray* {.unchecked.} = array[0, Argument]
    Arguments* {.final, pure.} = object
        num_entries*: cint
        entries*: ptr Argument
    Argument* {.final, pure.} = object
        key*: Bytes
        value*: FieldValue
    Socket* {.final, pure.} = object
    PSocket* = ptr Socket
    ConnectionState* {.final, pure.} = object
    PConnectionState* = ptr ConnectionState
    SASL_METHOD_ENUM = enum
        AMQP_SASL_METHOD_UNDEFINED = -1
        AMQP_SASL_METHOD_PLAIN = 0
        AMQP_SASL_METHOD_EXTERNAL = 1

    Properties* {.final, pure.} = object
        flags*: cuint
        content_type*: Bytes
        content_encoding*: Bytes
        headers*: Arguments
        delivery_mode*: cushort
        priority*: cushort
        correlation_id*: Bytes
        reply_to*: Bytes
        expiration*: Bytes
        message_id*: Bytes
        timestamp*: culong
        type_type*: Bytes
        user_id*: Bytes
        app_id*: Bytes
        cluster_id*: Bytes

    Message* {.final, pure.} = object
        properties*: Properties
        body*: Bytes
        pool*: Pool

    Channel* = cushort
    Envelope* {.final.} = object
        channel: Channel
        consumer_tag*: Bytes
        delivery_tag*: culong
        redelivered*: Boolean
        exchange*: Bytes
        routing_key*: Bytes
        message*: Message
    ConsumeOK = object
        consumer_tag*: ptr Bytes
    Boolean* = cuchar
    QueueDeclareOK* = object
        queue*: Bytes
        message_count*: cuint
        consumer_count*: cuint
    ExchangeDeclareOk = object
        dummy: char
    BasicQoSOK = object
        dummy: char
    BasicMessage* = object
        content*: string
        delivery_tag*: culong
        channel*: Channel
        routing_key*: string
        consumer_tag*: string
        properties*: Properties
    CheckError* = ref object of Exception


const
    empty_bytes* = Bytes(len: 0, bytes: nil)
    empty_arguments* = Arguments(num_entries: 0, entries: nil)
    AMQP_BASIC_CONTENT_TYPE_FLAG = (1 shl 15)
    AMQP_BASIC_CONTENT_ENCODING_FLAG = (1 shl 14)
    AMQP_BASIC_HEADERS_FLAG = (1 shl 13)
    AMQP_BASIC_DELIVERY_MODE_FLAG = (1 shl 12)
    AMQP_BASIC_PRIORITY_FLAG = (1 shl 11)
    AMQP_BASIC_CORRELATION_ID_FLAG = (1 shl 10)
    AMQP_BASIC_REPLY_TO_FLAG = (1 shl 9)
    AMQP_BASIC_EXPIRATION_FLAG = (1 shl 8)
    AMQP_BASIC_MESSAGE_ID_FLAG = (1 shl 7)
    AMQP_BASIC_TIMESTAMP_FLAG = (1 shl 6)
    AMQP_BASIC_TYPE_FLAG = (1 shl 5)
    AMQP_BASIC_USER_ID_FLAG = (1 shl 4)
    AMQP_BASIC_APP_ID_FLAG = (1 shl 3)
    AMQP_BASIC_CLUSTER_ID_FLAG = (1 shl 2)
    MAX_CHANNELS* = 32768
    AMQP_TRUE* = Boolean(true)
    AMQP_FALSE* = Boolean(false)

proc new_connection*: PConnectionState {.cdecl, importc: "amqp_new_connection", dynlib: rmqdll.}
proc destroy_connection*(conn: PConnectionState) {.cdecl, importc: "amqp_destroy_connection", dynlib: rmqdll.}
proc tcp_socket_new*(state: PConnectionState): PSocket {.cdecl, importc: "amqp_tcp_socket_new", dynlib: rmqdll.}
proc socket_open*(self: PSocket, host: cstring, port: cint): int {.cdecl, importc: "amqp_socket_open", dynlib: rmqdll.}
proc login*(state: PConnectionState, vhost: cstring, channel_max: cint, frame_max: cint, heartbeat: cint, sasl_method: SASL_METHOD_ENUM): RPCReply {.cdecl, importc: "amqp_login", dynlib: rmqdll, varargs.}
proc error_string2*(err: int): cstring {.cdecl, importc: "amqp_error_string2", dynlib: rmqdll.}
proc channel_open*(conn: PConnectionState, channel: Channel): int {.cdecl, importc: "amqp_channel_open", dynlib: rmqdll.}
proc get_rpc_reply*(conn: PConnectionState): RPCReply {.cdecl, importc: "amqp_get_rpc_reply", dynlib: rmqdll.}
proc basic_consume*(conn: PConnectionState, channel: Channel, queue: Bytes, consumer_tag: Bytes, no_local: Boolean, no_ack: Boolean, exclusive: Boolean, arguments: Arguments): ConsumeOK {.cdecl, importc: "amqp_basic_consume", dynlib: rmqdll.}
proc cstring_bytes*(cstr: cstring): Bytes {.cdecl, importc: "amqp_cstring_bytes", dynlib: rmqdll.}
proc queue_declare*(conn: PConnectionState, channel: Channel, queue: Bytes, passive: Boolean, durable: Boolean, exclusive: Boolean, auto_delete: Boolean, arguments: Arguments): ptr QueueDeclareOK {.cdecl, importc: "amqp_queue_declare", dynlib: rmqdll.}
proc queue_bind*(conn: PConnectionState, channel: Channel, queue: Bytes, exchange: Bytes, bindingKey: Bytes, arguments: Arguments) {.cdecl, importc: "amqp_queue_bind", dynlib: rmqdll.}
proc consume_message(conn: PConnectionState, envelope: ptr Envelope, timeout: ptr Timeval, flags: cint): RPCReply {.cdecl, importc: "amqp_consume_message", dynlib: rmqdll.}
proc maybe_release_buffers*(conn: PConnectionState) {.cdecl, importc: "amqp_maybe_release_buffers", dynlib: rmqdll.}
proc read_message*(conn: PConnectionState, channel: Channel, message: ptr Message, n: cuint): RPCReply {.cdecl, importc: "amqp_read_message", dynlib: rmqdll.}
proc destroy_envelope*(envelope: ptr Envelope) {.cdecl, importc: "amqp_destroy_envelope", dynlib: rmqdll.}

proc bytes_malloc_dup*(b: Bytes): Bytes {.cdecl, importc: "amqp_bytes_malloc_dup", dynlib: rmqdll.}

proc simple_wait_frame_noblock*(conn: PConnectionState, frame: ptr Frame, timeout: ptr Timeval): cint {.cdecl, importc: "amqp_simple_wait_frame_noblock", dynlib: rmqdll.}

proc basic_ack*(conn: PConnectionState, channel: Channel, delivery_tag: culong, multiple: Boolean): cint {.cdecl, importc: "amqp_basic_ack", dynlib: rmqdll.}

proc basic_reject*(conn: PConnectionState, channel: Channel, delivery_tag: culong, multiple: Boolean, requeue: Boolean): cint {.cdecl, importc: "amqp_basic_reject", dynlib: rmqdll.}

proc basic_publish*(conn: PConnectionState, channel: Channel, exchange: Bytes, routing_key: Bytes, mandatory: Boolean, immediate: Boolean, properties: Properties, body: Bytes): cint {.cdecl, importc: "amqp_basic_publish", dynlib: rmqdll.}

proc amqp_exchange_declare(conn: PConnectionState, channel: Channel, exchange: Bytes, type_type: Bytes, passive: Boolean, durable: Boolean, auto_delete: Boolean, internal: Boolean, arguments: Arguments): ExchangeDeclareOk {.cdecl, importc: "amqp_exchange_declare", dynlib: rmqdll.}

proc exchange_declare*(conn: PConnectionState, channel: Channel, exchange: cstring, type_type: cstring, passive: bool = false, durable: bool = false, auto_delete: bool = false, internal: bool = false, arguments: Arguments = empty_arguments) =
    discard amqp_exchange_declare(conn, channel, cstring_bytes(exchange), cstring_bytes(type_type), Boolean(passive), Boolean(durable), Boolean(auto_delete), Boolean(internal), arguments)

proc basic_qos*(conn: PConnectionState, channel: Channel, prefetch_size: cuint = 0, prefetch_count: cushort = 0, global_global: Boolean = Boolean(false)): BasicQoSOK {.cdecl, importc: "amqp_basic_qos", dynlib: rmqdll.}

proc pool_alloc*(pool: ptr Pool, amount: csize): pointer {.cdecl, importc: "amqp_pool_alloc", dynlib: rmqdll.}

proc init_pool*(pool: ptr Pool, pagesize: csize) {.cdecl, importc: "init_amqp_pool", dynlib: rmqdll.}

proc setExpiration*(props: var Properties, amount: float) =
    props.expiration = cstring_bytes($ (amount * 1000).toInt)
    props.flags = props.flags or AMQP_BASIC_EXPIRATION_FLAG

proc bytes_string*(b: Bytes): string =
    if b.len > 0:
        return ($ b.bytes)[0..b.len - 1]
    else:
        return ""

proc `$`(b: Bytes): string =
    return bytes_string(b)

proc check_reply*(reply: RPCReply) =
    if reply.reply_type == ResponseTypeEnum.AMQP_RESPONSE_LIBRARY_EXCEPTION:
        echo error_string2(reply.library_error)
    if reply.reply_type != ResponseTypeEnum.AMQP_RESPONSE_NORMAL:
        raise CheckError(msg: ($ reply.reply_type))

proc check*(conn: PConnectionState) =
    check_reply(get_rpc_reply(conn))

proc connect*(host: cstring, port: cint, vhost: cstring, user: cstring, password: cstring): PConnectionState =
    var conn = new_connection()
    var socket = tcp_socket_new(conn)
    assert socket_open(socket, host, port) == 0
    check_reply(login(conn, vhost, 0, 131072, 0, SASL_METHOD_ENUM.AMQP_SASL_METHOD_PLAIN, user, password))
    return conn

proc setup_queue*(conn: PConnectionState, channel: Channel, queuename: string, no_local: bool = false, no_ack: bool = false, exclusive: bool = false, passive: bool = false, durable: bool = true, auto_delete: bool = false) =
    discard channel_open(conn, cushort(channel))
    check(conn)
    discard queue_declare(conn, cushort(channel), cstring_bytes(queuename), Boolean(passive), Boolean(durable), Boolean(exclusive), Boolean(auto_delete), empty_arguments)
    discard basic_consume(conn, cushort(channel), cstring_bytes(queuename), empty_bytes, Boolean(no_local), Boolean(no_ack), Boolean(exclusive), empty_arguments)
    check(conn)

proc get_message*(conn: PConnectionState, timeout: ptr Timeval = nil, flags: cint = 0): BasicMessage =
    var envelope: Envelope
    maybe_release_buffers(conn)
    discard consume_message(conn, addr envelope, timeout, flags)
    return BasicMessage(content: $ envelope.message.body,
                        delivery_tag: envelope.delivery_tag,
                        channel: envelope.channel,
                        routing_key: $ envelope.routing_key,
                        consumer_tag: $ envelope.consumer_tag,
                        properties: envelope.message.properties)

proc ack_message*(conn: PConnectionState, channel: Channel, msg: BasicMessage) =
    let ok = basic_ack(conn, channel, msg.delivery_tag, Boolean(0))
    assert ok == 0

proc reject_message*(conn: PConnectionState, channel: Channel, msg: BasicMessage, multiple: bool = false, requeue: bool = false) =
    let ok = basic_reject(conn, channel, msg.delivery_tag, Boolean(multiple), Boolean(requeue))
    assert ok == 0

proc publish_message*(conn: PConnectionState, channel: Channel, exchange: string, routing_key: string, mandatory: bool = false, immediate: bool = false, properties: Properties, body: string) =
    let ok = basic_publish(conn, channel, cstring_bytes(exchange), cstring_bytes(routing_key), Boolean(mandatory), Boolean(immediate), properties,
    cstring_bytes(body))
    assert ok == 0

proc makeArguments*(j: JsonNode): Arguments

proc makeArgument*(key: string, value: JsonNode): Argument =
    var arg: Argument
    arg.key = cstring_bytes(key)
    arg.value = FieldValue()
    case value.kind
        of JString:
            arg.value.kind = 'S'
            arg.value.value.bytes = cstring_bytes(value.str)
        of JInt:
            arg.value.kind = 'l'
            arg.value.value.u64 = culong(value.getNum)
        of JObject:
            arg.value.kind = 'F'
            arg.value.value.table = makeArguments(value)
        else:
            discard
    return arg

proc makeArguments*(j: JsonNode): Arguments =
    var
        pool: Pool
        argument_array: ptr ArgumentArray
        arguments: Arguments
    arguments = Arguments(num_entries: 0, entries: nil)
    init_pool(addr pool, 1024)
    argument_array = cast[ptr ArgumentArray](pool_alloc(addr pool, j.len * sizeof(Argument)))
    for key, node in j.pairs:
        let arg = makeArgument(key, node)
        argument_array[arguments.num_entries] = arg
        arguments.num_entries += 1
    arguments.entries = cast[ptr Argument](argument_array)
    return arguments

proc jsonFromArguments*(arguments: Arguments): JsonNode

proc jsonFromFieldValue*(value: FieldValue): JsonNode =
    if value.kind == 'S':
        return newJString($ value.value.bytes)
    elif value.kind == 'l':
        return newJInt(BiggestInt(value.value.u64))
    elif value.kind == 'A' and value.value.array_array.num_entries > 0:
        var
            arr = newJArray()
            f = cast[ptr FieldValueArray](value.value.array_array.entries)
        for idx in 0 .. value.value.array_array.num_entries - 1:
            let node = jsonFromFieldValue(f[idx])
            if node != nil:
                arr.add(node)
        return arr
    elif value.kind == 'F':
        return jsonFromArguments(value.value.table)

proc jsonFromArguments*(arguments: Arguments): JsonNode =
    var
        idx = 0
        j = newJObject()
        arguments_array: ptr ArgumentArray = nil
    if arguments.num_entries > 0:
        arguments_array = cast[ptr ArgumentArray](arguments.entries)
        while idx < arguments.num_entries:
            let
                arg = arguments_array[idx]
                node = jsonFromFieldValue(arg.value)
            if node != nil:
                j.add($ arg.key, node)
            idx += 1
    return j

when isMainModule:
    var
        conn = connect("localhost", 5672, "/", "guest", "guest")
        channel: Channel = 1

    proc handle_keyboard_interrupt() {.noconv.} =
        destroy_connection(conn)
        echo "Destroyed connection."
        quit 0
    setControlCHook(handle_keyboard_interrupt)

    setup_queue(conn, channel, "foobar")
    while true:
        let msg = get_message(conn)
        echo msg.content
        ack_message(conn, channel, msg)
