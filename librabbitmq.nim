{.deadCodeElim: on.}
when defined(windows):
  const
    rmqdll* = "librabbitmq.dll"
elif defined(macosx):
  const
    rmqdll* = "librabbitmq.dylib"
else:
  const
    rmqdll* = "librabbitmq.so.1"

from posix import Timeval

type
    Bytes* = object
        len*: csize
        bytes*: ptr cchar
    FramePayloadProperties* = object
        class_id: cushort
        body_size: culong
        decoded: pointer
        raw: Bytes

    FramePayloadProtocolHeader* = object
        transport_high: cuchar
        transport_low: cuchar
        protocol_version_major: cuchar
        protocol_version_minor: cuchar

    FramePayload* {.union.} = object
        method_method: Method
        properties: FramePayloadProperties
        body_fragment: Bytes
        protocol_header: FramePayloadProtocolHeader
    Frame* {.final, pure.} = object
        frame_type: cuchar
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
    Table* {.final, pure.} = object
        num_entries*: cint
        entries*: ptr TableEntry
    TableEntry* {.final, pure.} = object
        key*: Bytes

    Socket* {.final, pure.} = object
    PSocket* = ptr Socket
    ConnectionState* {.final, pure.} = object
    PConnectionState* = ptr ConnectionState
    SASL_METHOD_ENUM = enum
        AMQP_SASL_METHOD_UNDEFINED = -1
        AMQP_SASL_METHOD_PLAIN = 0
        AMQP_SASL_METHOD_EXTERNAL = 1

    Properties* {.final, pure.} = object
        flags: cuint
        content_type: Bytes
        content_encoding: Bytes
        headers: Table
        delivery_mode: cushort
        priority: cushort
        correlation_id: Bytes
        reply_to: Bytes
        expiration: Bytes
        message_id: Bytes
        timestamp: culong
        type_type: Bytes
        user_id: Bytes
        app_id: Bytes
        cluster_id: Bytes

    Message* {.final, pure.} = object
        properties*: Properties
        body*: Bytes
        pool*: Pool

    Channel* = cushort
    Envelope* {.final.} = object
        channel: Channel
        consumer_tag*: Bytes
        delivery_tag*: culong
        redelivered*: cuchar
        exchange*: Bytes
        routing_key*: Bytes
        message*: Message
    ConsumeOK = object
        consumer_tag*: ptr Bytes
    Boolean = cuchar
    QueueDeclareOK = object
        queue: Bytes
        message_count: cuint
        consumer_count: cuint
    BasicMessage* = object
        content: string
        delivery_tag: culong

const
    empty_bytes = Bytes(len: 0, bytes: nil)
    empty_table = Table(num_entries: 0, entries: nil)
    AMQP_BASIC_CONTENT_TYPE_FLAG = (1 shl 15)
    AMQP_BASIC_CONTENT_ENCODING_FLAG = (1 shl 14)
    AMQP_BASIC_HEADERS_FLAG = (1 shl 13)
    AMQP_BASIC_DELIVERY_MODE_FLAG = (1 shl 12)
    AMQP_BASIC_PRIORITY_FLAG = (1 shl 11)
    AMQP_BASIC_CORRELATION_ID_FLAG = (1 shl 10)
    AMQP_BASIC_REPLY_TO_FLAG= (1 shl 9)
    AMQP_BASIC_EXPIRATION_FLAG= (1 shl 8)
    AMQP_BASIC_MESSAGE_ID_FLAG= (1 shl 7)
    AMQP_BASIC_TIMESTAMP_FLAG= (1 shl 6)
    AMQP_BASIC_TYPE_FLAG= (1 shl 5)
    AMQP_BASIC_USER_ID_FLAG= (1 shl 4)
    AMQP_BASIC_APP_ID_FLAG= (1 shl 3)
    AMQP_BASIC_CLUSTER_ID_FLAG= (1 shl 2)

proc new_connection: PConnectionState {.cdecl, importc: "amqp_new_connection", dynlib: rmqdll.}
proc tcp_socket_new(state: PConnectionState): PSocket {.cdecl, importc: "amqp_tcp_socket_new", dynlib: rmqdll.}
proc socket_open(self: PSocket, host: cstring, port: cint): int {.cdecl, importc: "amqp_socket_open", dynlib: rmqdll.}
proc login(state: PConnectionState, vhost: cstring, channel_max: cint, frame_max: cint, heartbeat: cint, sasl_method: SASL_METHOD_ENUM): RPCReply {.cdecl, importc: "amqp_login", dynlib: rmqdll, varargs.}
proc error_string2(err: int): cstring {.cdecl, importc: "amqp_error_string2", dynlib: rmqdll.}
proc channel_open(conn: PConnectionState, channel: Channel): int {.cdecl, importc: "amqp_channel_open", dynlib: rmqdll.}
proc get_rpc_reply(conn: PConnectionState): RPCReply {.cdecl, importc: "amqp_get_rpc_reply", dynlib: rmqdll.}
proc basic_consume(conn: PConnectionState, channel: Channel, queue: Bytes, consumer_tag: Bytes, no_local: Boolean, no_ack: Boolean, exclusive: Boolean, arguments: Table): ConsumeOK {.cdecl, importc: "amqp_basic_consume", dynlib: rmqdll.}
proc cstring_bytes(cstr: cstring): Bytes {.cdecl, importc: "amqp_cstring_bytes", dynlib: rmqdll.}
proc queue_declare(conn: PConnectionState, channel: Channel, queue: Bytes, passive: Boolean, durable: Boolean, exclusive: Boolean, auto_delete: Boolean, arguments: Table): ptr QueueDeclareOK {.cdecl, importc: "amqp_queue_declare", dynlib: rmqdll.}
proc queue_bind(conn: PConnectionState, channel: Channel, queue: Bytes, exchange: Bytes, bindingKey: Bytes, arguments: Table) {.cdecl, importc: "amqp_queue_bind", dynlib: rmqdll.}
proc consume_message(conn: PConnectionState, envelope: ptr Envelope, timeout: ptr Timeval, flags: cint): RPCReply {.cdecl, importc: "amqp_consume_message", dynlib: rmqdll.}
proc maybe_release_buffers(conn: PConnectionState) {.cdecl, importc: "amqp_maybe_release_buffers", dynlib: rmqdll.}
proc read_message(conn: PConnectionState, channel: Channel, message: ptr Message, n: cuint): RPCReply {.cdecl, importc: "amqp_read_message", dynlib: rmqdll.}
proc destroy_envelope(envelope: ptr Envelope) {.cdecl, importc: "amqp_destroy_envelope", dynlib: rmqdll.}

proc bytes_malloc_dup(b: Bytes): Bytes {.cdecl, importc: "amqp_bytes_malloc_dup", dynlib: rmqdll.}

proc simple_wait_frame_noblock(conn: PConnectionState, frame: ptr Frame, timeout: ptr Timeval): cint {.cdecl, importc: "amqp_simple_wait_frame_noblock", dynlib: rmqdll.}

proc basic_ack(conn: PConnectionState, channel: Channel, delivery_tag: culong, multiple: Boolean): cint {.cdecl, importc: "amqp_basic_ack", dynlib: rmqdll.}


proc `$`(b: Bytes): string =
    if b.len > 0:
        return ($ b.bytes)[0..b.len - 1]
    else:
        return ""

proc check_reply(reply: RPCReply) =
    if reply.reply_type == ResponseTypeEnum.AMQP_RESPONSE_LIBRARY_EXCEPTION:
        echo error_string2(reply.library_error)
    assert reply.reply_type == ResponseTypeEnum.AMQP_RESPONSE_NORMAL

proc check(conn: PConnectionState) =
    check_reply(get_rpc_reply(conn))

proc connect(host: cstring, port: cint, vhost: cstring, user: cstring, password: cstring): PConnectionState =
    var conn = new_connection()
    var socket = tcp_socket_new(conn)
    assert (socket_open(socket, host, port) == 0)
    check_reply(login(conn, vhost, 0, 131072, 0, SASL_METHOD_ENUM.AMQP_SASL_METHOD_PLAIN, user, password))
    discard channel_open(conn, 1)
    check(conn)
    return conn

proc setup_queue(conn: PConnectionState, queuename: string, no_local: bool, no_ack: bool, exclusive: bool) =
    let ok = basic_consume(conn, 1, cstring_bytes(queuename), empty_bytes, cuchar(no_local), cuchar(no_ack), cuchar(exclusive), empty_table)
    check(conn)

proc get_message(conn: PConnectionState, timeout: ptr Timeval = nil, flags: cint = 0): BasicMessage =
    var envelope: Envelope
    maybe_release_buffers(conn)
    check_reply(consume_message(conn, addr envelope, timeout, flags))
    var msg = BasicMessage(content: $ envelope.message.body, delivery_tag: envelope.delivery_tag)
    destroy_envelope(addr envelope)
    return msg

proc ack_message(conn: PConnectionState, msg: BasicMessage) =
    let ok = basic_ack(conn, 1, msg.delivery_tag, cuchar(0))
    assert (ok == 0)

when isMainModule:
    var conn = connect("localhost", 5672, "/", "guest", "guest")

    setup_queue(conn, "celery:http_dispatch", false, false, false)

    while true:
        let msg = get_message(conn)
        echo msg.content
        ack_message(conn, msg)
