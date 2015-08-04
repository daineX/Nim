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


type
#     Time* = object
#         time_point_ns*: culong
    Bytes* = object
        len*: csize
        bytes*: pointer
#     ConnectionStateEnum* = enum
#         CONNECTION_STATE_IDLE = 0
#         CONNECTION_STATE_INITIAL = 1
#         CONNECTION_STATE_HEADER = 2
#         CONNECTION_STATE_BODY = 3
#     Decimal* {.final, pure.} = object
#         decimals*: cuchar
#         value*: cuint
#     FieldValueUnion* {.union.} = object
#         boolean*: cint
#         i8*: cchar
#         u8*: cuchar
#         i16*: cshort
#         u16*: cushort
#         i32*: cint
#         u32*: cuint
#         i64*: clong
#         u64*: culong
#         f32*: cfloat
#         f64*: cdouble
#         decimal*: Decimal
#         bytes*: Bytes
#         table*: Table
#         array*: Array
#     Array* {.final, pure.} = object
#         num_entries*: cint
#         entries: ptr FieldValue
#     FieldValue* {.final, pure.} = object
#         kind*: cchar
#         value*: FieldValueUnion
#     Link* {.final, pure.} = object
#         next: ptr Link
#         data: pointer
    Method* {.final, pure.} = object
        id: cuint
        decoded: pointer
#     PoolBlockList* {.final, pure.} = object
#         num_blocks*: cint
#         blocklist*: ptr pointer
#     Pool* {.final, pure.} = object
#         pagesize*: csize
#         pages*: PoolBlockList
#         lage_blocks*: PoolBlockList
#         next_page*: cint
#         alloc_block*: ptr cchar
#         alloc_size*: csize
#     PoolTableEntry* {.final, pure.} = object
#         next*: ptr PoolTableEntry
#         pool*: Pool
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
#         klass*: pointer
#         sockfd: cint
#         internal_error: cint
#         state: cint
    PSocket* = ptr Socket
    ConnectionState* {.final, pure.} = object
#         pool_table*: ptr PoolTableEntry
#         state*: ConnectionStateEnum
#         channel_max*: cint
#         frame_max*: cint
#         heartbeat*: cint
#         next_recv_heartbeat*: Time
#         next_send_heartbeat*: Time
#         header_buffer*: cchar
#         inbound_buffer*: Bytes
#         inbound_offset*: csize
#         target_size*: csize
#
#         outbound_buffer*: Bytes
#         socket*: PSocket
#
#         sock_inbound_buffer*: Bytes
#         sock_inbound_offset*: csize
#         sock_inbound_limit*: csize
#
#         first_queued_frame*: ptr Link
#         last_queued_frame*: ptr Link
#         most_recent_api_result*: RPCReply
#         server_properties*: Table
#         client_properties*: Table
#         properties_pool*: Pool
    PConnectionState* = ptr ConnectionState
    SASL_METHOD_ENUM = enum
        AMQP_SASL_METHOD_UNDEFINED = -1
        AMQP_SASL_METHOD_PLAIN = 0
        AMQP_SASL_METHOD_EXTERNAL = 1


proc new_connection: PConnectionState {.cdecl, importc: "amqp_new_connection", dynlib: rmqdll.}
proc tcp_socket_new(state: PConnectionState): PSocket {.cdecl, importc: "amqp_tcp_socket_new", dynlib: rmqdll.}
proc socket_open(self: PSocket, host: cstring, port: cint): int {.cdecl, importc: "amqp_socket_open", dynlib: rmqdll.}
proc login(state: PConnectionState, vhost: cstring, channel_max: cint, frame_max: cint, heartbeat: cint, sasl_method: SASL_METHOD_ENUM): RPCReply {.cdecl, importc: "amqp_login", dynlib: rmqdll, varargs.}
proc error_string2(err: int): cstring {.cdecl, importc: "amqp_error_string2", dynlib: rmqdll.}
proc channel_open(conn: PConnectionState, channel: int): int {.cdecl, importc: "amqp_channel_open", dynlib: rmqdll.}
proc get_rpc_reply(conn: PConnectionState): RPCReply {.cdecl, importc: "amqp_get_rpc_reply", dynlib: rmqdll.}
proc basic_consume(conn: PConnectionState, channel: int, queue: Bytes, consumer_tag: Bytes, no_local: cuchar, no_ack: cuchar, exclusive: cuchar, arguments: Table) {.cdecl, importc: "amqp_basic_consume", dynlib: rmqdll.}
proc cstring_bytes(cstr: cstring): Bytes {.cdecl, importc: "amqp_cstring_bytes", dynlib: rmqdll.}

when isMainModule:
    var conn = new_connection()
    var socket = tcp_socket_new(conn)
    var status = socket_open(socket, "localhost", 5672)
    assert (status == 0)
    var reply = login(conn, "/", 0, 131072, 0, SASL_METHOD_ENUM.AMQP_SASL_METHOD_PLAIN, "guest", "guest")
    if reply.reply_type == ResponseTypeEnum.AMQP_RESPONSE_LIBRARY_EXCEPTION:
        echo ($ error_string2(reply.library_error))
    discard channel_open(conn, 1)
    reply = get_rpc_reply(conn)
    assert reply.reply_type == ResponseTypeEnum.AMQP_RESPONSE_NORMAL

    basic_consume(conn, 1, cstring_bytes("celery:http_dispatch"), Bytes(0, null), 0, 0, 0, Table(0, null))

