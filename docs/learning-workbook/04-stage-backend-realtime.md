# 4. 后端实时系统阶段

## 学习目标

这一阶段学完后，你应该能做到：

- 讲清楚 WebSocket 消息是怎么建立和广播的
- 讲清楚 presence 和 typing 为什么要用内存状态
- 讲清楚 voice join token 为什么要由后端发

## 必读文件

- [backend/internal/handler/websocket_handler.go](../../backend/internal/handler/websocket_handler.go)
- [backend/internal/websocket/events.go](../../backend/internal/websocket/events.go)
- [backend/internal/websocket/hub.go](../../backend/internal/websocket/hub.go)
- [backend/internal/handler/server_handler.go](../../backend/internal/handler/server_handler.go)
- [backend/internal/service/server_service.go](../../backend/internal/service/server_service.go)

## 阅读任务

1. 找出 WebSocket 连接鉴权发生在哪。
2. 找出客户端订阅频道的命令是怎么处理的。
3. 找出消息创建后广播是在什么地方触发的。
4. 找出 `presence.snapshot` 和 `server.presence.snapshot` 的差别。
5. 找出语音 token 是怎么生成的。

## 动手任务

1. 在一个实时事件 payload 里临时增加一个简单字段，比如 `source: "server"`。
2. 让前端或调试输出能看到它。
3. 然后把这个改动恢复，练习一次“从事件定义到消费”的追踪。

## 练习题

1. 为什么 Hub 比较适合维护在线状态？
2. 为什么消息是“先写库，再广播”而不是“只广播不写库”？
3. 为什么 LiveKit token 不应该由前端自己生成？

## 过关标准

你能讲清楚这条链路：

“客户端建立 WS 连接并订阅，后端写库后通过 Hub 广播事件，客户端再据此更新界面状态。”
