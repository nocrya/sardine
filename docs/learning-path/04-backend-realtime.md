# 第四阶段：后端实时系统和语音接入

这一阶段专门看“为什么这个项目能实时收消息、显示 presence、接语音房间”。

## WebSocket 事件协议

### `backend/internal/websocket/events.go`

- 作用：定义服务端和客户端之间交换的事件结构。
- 你会在这里看到：
  - `message.created`
  - `typing.started / typing.stopped`
  - `presence.*`
  - `direct.*`
- 初学者要理解：事件名其实就是实时协议的一部分。

## Hub：实时状态中心

### `backend/internal/websocket/hub.go`

- 作用：维护在线连接、频道订阅、私聊订阅、presence 状态和广播。
- 重点看什么：
  - 连接注册/注销
  - 频道订阅
  - 私聊订阅
  - presence 广播
  - typing 广播
- 初学者要理解：Hub 是“实时世界里的内存状态中心”。

## WebSocket 入口

### `backend/internal/handler/websocket_handler.go`

- 作用：把 HTTP 升级为 WebSocket，然后把命令交给 Hub。
- 初学者重点：
  - token 鉴权怎么接入
  - 为什么客户端命令是 `subscribe`、`typing.start`、`direct.read` 这种形式

## 语音接入

### `backend/internal/service/server_service.go`

- 在这个文件里，语音主要体现为 join room 的业务规则。
- 初学者重点：
  - 为什么要先校验是否有权限进入 voice channel
  - 为什么后端只发 token，不直接传音频

### `backend/internal/handler/server_handler.go`

- `voice join` 的 HTTP 接口在这里。
- 初学者重点：voice 也是普通 HTTP 接口起步，而不是直接从 Flutter 连 LiveKit。

## 你需要形成的整体图

后端实时主线是：

`客户端连 /ws -> websocket handler 鉴权 -> hub 记录连接 -> 客户端订阅 -> 业务接口写库 -> hub 广播事件`

语音主线是：

`客户端请求 voice join -> 后端校验权限 -> 后端签发 LiveKit token -> 客户端拿 token 连 LiveKit`

## 这一阶段读完后的检查题

你应该能回答：

- 为什么实时消息不是直接从数据库推，而是先经过 Hub？
- 为什么 voice 还需要一个后端 join 接口？
- presence 和 typing 为什么更适合放内存而不是直接落库？
