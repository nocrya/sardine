# 第二阶段：后端启动、配置和 HTTP 骨架

这一阶段的目标是把后端主干看明白，不碰太深的业务细节。

## 配置与资源初始化

### `backend/internal/config/config.go`

- 作用：把环境变量整理成结构化配置。
- 重点关注：
  - HTTP 配置
  - 数据库配置
  - Auth 配置
  - CORS 配置
  - LiveKit 配置
- 初学者阅读重点：配置为什么不在 `main.go` 里直接散着写。

### `backend/internal/database/postgres.go`

- 作用：创建 PostgreSQL 连接。
- 重点看什么：
  - DSN 如何被读取
  - 数据库何时返回 `nil`
  - 连接失败如何返回错误
- 初学者要理解：数据库连接失败，项目为什么就启动不完整。

### `backend/internal/database/migrations.go`

- 作用：用代码方式创建当前版本所需表结构。
- 初学者重点：
  - 这里不是高级迁移工具，而是项目当前阶段的“自动建表”
  - 理解有哪些核心表：`users`、`servers`、`channels`、`messages`、`direct_*`

### `backend/internal/app/app.go`

- 作用：应用容器。
- 它做的事：
  - 初始化 DB
  - 跑 migrations
  - 创建 repository
  - 创建 service
  - 创建 WebSocket hub
- 初学者要理解：它相当于“后端依赖注入容器”。

## 路由和中间件

### `backend/internal/handler/routes.go`

- 作用：集中注册所有 HTTP 路由。
- 重点看什么：
  - 公开接口和鉴权接口的分组
  - `auth`、`server`、`direct message`、`voice`、`invite` 的入口
  - `/ws` 为什么不走普通 REST 路由
- 初学者要理解：你找接口时先来这里。

### `backend/internal/middleware/middleware.go`

- 作用：放通用中间件。
- 当前重点一般是：
  - 鉴权中间件
  - CORS 处理
- 初学者要理解：中间件做的是“横切逻辑”，不是具体业务。

## Handler 层

Handler 的职责很稳定：

- 解析请求
- 做参数校验
- 调用 service
- 把错误转成 HTTP 状态码和 JSON

### `backend/internal/handler/auth_handler.go`

- 作用：处理注册、登录、当前用户信息。
- 初学者要关注：
  - `register / login / me` 三个动作怎么拆开
  - handler 不负责密码哈希

### `backend/internal/handler/server_handler.go`

- 作用：处理 server、channel、message、invite、member、voice 相关请求。
- 它是当前后端最重的 handler。
- 初学者要关注：
  - 创建 server
  - 列出频道
  - 发消息
  - 创建邀请码
  - 邀请加入
  - 标记已读
  - 语音 join

### `backend/internal/handler/direct_message_handler.go`

- 作用：处理私聊会话和私聊消息。
- 初学者要理解：私聊虽然也是“消息”，但数据模型和 server channel 不同。

### `backend/internal/handler/websocket_handler.go`

- 作用：建立 WebSocket 连接，并把客户端命令交给 Hub。
- 初学者要理解：它只负责握手和入口，不自己维护全部实时状态。

## 这一阶段读完后的检查题

你应该能回答：

- 为什么要有 `App` 这个容器？
- 一个 HTTP 请求先经过哪里，再到哪里？
- `routes.go` 和各个 `*_handler.go` 的分工是什么？
