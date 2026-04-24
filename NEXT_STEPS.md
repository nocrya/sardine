# Sardine 下一步开发文档

## 1. 项目现状判断

当前仓库已经有一个适合继续演进的基础骨架，但离“可用的类 Discord 即时通讯项目”还有明显距离。

现状可以概括为：

- 前后端已经分仓目录，方向是对的
- 后端使用 Go + Gin，已经有配置加载、HTTP 入口、路由注册、WebSocket Hub 占位
- 前端使用 Flutter，已经有基础主题、Dio、GetIt、Bloc 和 feature 目录结构
- `auth`、`home`、`server`、`voice` 等模块已经预留，但大部分还是占位页面或空数据源
- README 里提到的 PostgreSQL、Redis、GORM、LiveKit 目前基本还没有真正落地到代码

结论：

这个项目现在更像“技术选型和目录结构已经确定的脚手架”，不是“已有核心 IM 能力的半成品”。

这其实是个好状态，因为如果你的目标是做一个学习项目，现在最重要的不是继续堆目录，而是尽快做出一个小而完整的闭环。

## 2. 如果目标是做类似 Discord 的学习项目，建议先收缩目标

不要一开始就追求完整 Discord。

Discord 本质上至少包含下面几类系统：

- 用户系统：注册、登录、鉴权、个人信息
- 社区系统：Server、Channel、Member、Role、Permission
- 文本消息系统：频道消息、消息列表、历史拉取、已读、编辑、删除
- 实时系统：在线状态、WebSocket 推送、typing、消息广播
- 语音系统：语音房间、麦克风状态、成员上下麦、音视频 RTC
- 基础设施：数据库、缓存、对象存储、日志、监控、部署

如果你是为了学习，建议把第一阶段目标定义成：

**做一个“支持登录、Server/Channel 列表、频道文字聊天、WebSocket 实时收发”的 IM MVP。**

LiveKit 语音能力放到第二阶段更合理。

原因很直接：

- 文本 IM 能把后端分层、数据库建模、实时推送、前端状态管理全部串起来
- 语音 RTC 的学习曲线更陡，排障成本也更高
- 先把文字聊天闭环跑通，再接 LiveKit，项目推进会稳定很多

## 3. 当前项目的主要问题

### 3.1 后端问题

- 只有 `/healthz` 真正可用，`/ws` 还是未实现占位
- 没有数据库接入，没有业务模型，没有 repository/service 层落地
- WebSocket Hub 只有空结构，没有连接管理、广播、订阅、鉴权
- 没有用户、服务器、频道、消息等核心领域对象
- 没有鉴权体系，比如 JWT、刷新令牌、中间件
- 没有错误码约定、请求 DTO、响应模型

### 3.2 前端问题

- `MaterialApp` 仍然是单页占位，没有真正的导航和页面流转
- feature 已分目录，但还没有形成完整的数据流：UI -> Cubit/Bloc -> Repository/DataSource -> API
- 没有登录态管理，没有 token 持久化，没有路由守卫
- 没有消息页、频道页、会话状态管理
- 还没有接入 WebSocket 事件流

### 3.3 产品设计问题

- 目前仓库偏“语音社区”命名，但如果你要做类似 Discord，核心模型应该先围绕 `server/channel/message/member`
- 现在还没有明确 MVP 边界，容易在“语音、权限、好友、通知、UI 细节”之间分散精力

## 4. 推荐的开发顺序

开发顺序建议严格按“先闭环，再扩展”。

### 阶段 1：把基础骨架变成可开发状态

目标：

- 后端能稳定启动
- 前端能访问后端
- 有统一配置和本地开发方式

要做的事：

- 在后端补充配置项：数据库 DSN、Redis、JWT 密钥、CORS、WebSocket 配置
- 接入 PostgreSQL，先只做最基础连接
- 建立后端分层目录：`handler`、`service`、`repository`、`model`
- 设计统一 API 前缀，比如 `/api/v1`
- 前端增加环境配置方案，区分本地和生产 API 地址
- 前端增加基础路由结构，而不是直接把占位页挂在 `home`

阶段产物：

- 前端可请求后端接口
- 后端可连数据库
- 目录结构稳定，不再频繁改骨架

### 阶段 2：先做用户系统

目标：

- 有登录态，后续所有 IM 功能都能建立在用户身份之上

要做的事：

- 后端实现注册、登录、获取当前用户信息接口
- 使用 JWT 做访问令牌
- 增加认证中间件
- 建立用户表
- 前端完成登录页、注册页、token 存储、启动自动恢复登录态

建议数据模型：

- `users`
  - `id`
  - `email` 或 `username`
  - `password_hash`
  - `display_name`
  - `avatar_url`
  - `created_at`

阶段产物：

- 用户可以注册并登录
- 前端能带 token 请求受保护接口

### 阶段 3：做 Discord 最核心的数据模型

目标：

- 先把“社区”和“频道”的静态结构建立起来

要做的事：

- 设计并实现这些核心表：
  - `servers`
  - `server_members`
  - `channels`
  - `messages`
- 先不做复杂权限，先保证一个用户能创建 server 和 channel
- 实现这些基础接口：
  - 创建 server
  - 获取我的 server 列表
  - 获取 server 下 channel 列表
  - 获取 channel 消息历史
  - 发送消息

建议频道先只支持两种：

- `text`
- `voice`

阶段产物：

- 前端左侧可以看到 server 列表
- 进入 server 后可以看到 channel 列表
- 点击 text channel 能拉取历史消息

### 阶段 4：做文字聊天 MVP

目标：

- 先实现“像聊天软件”的真实体验

要做的事：

- 前端完成消息列表页、输入框、发送消息交互
- 后端消息接口支持分页拉取
- 数据库消息表至少支持：
  - `id`
  - `channel_id`
  - `sender_id`
  - `content`
  - `created_at`
- 前端消息列表按时间排序展示
- 处理消息发送中的加载状态和失败状态

阶段产物：

- 即使还没有 WebSocket，也已经可以像一个基础论坛/聊天室那样使用

### 阶段 5：接入 WebSocket 做实时消息

目标：

- 文本消息从“刷新后看到”升级成“实时到达”

要做的事：

- 重新设计 `internal/websocket/hub.go`
- 实现真实连接升级和客户端注册
- 按 `channel_id` 或 `server_id` 做订阅广播
- WebSocket 建连时校验 token
- 定义事件协议，例如：
  - `message.created`
  - `channel.joined`
  - `typing.started`
- 前端增加 WebSocket 服务层，把实时事件同步到消息状态中

这一阶段的关键原则：

- WebSocket 只负责“推送事件”
- 消息持久化仍然走后端正常业务逻辑和数据库
- 不要把所有业务都塞进 Hub

阶段产物：

- 两个客户端能在同一个频道实时收发文字消息

### 阶段 6：再做语音房间

目标：

- 基于现有 `voice` feature 真正引入 LiveKit

要做的事：

- 后端生成 LiveKit room/token
- 将 voice channel 和 LiveKit room 关联
- 前端加入语音频道时请求 token 并连接 LiveKit
- 实现最基础的：
  - 加入房间
  - 离开房间
  - 成员列表
  - 静音/取消静音

这时才建议处理：

- speaking 状态
- 房间在线成员
- UI 上的“谁在说话”

## 5. 推荐的 MVP 范围

如果你想在较短时间内做出一个能演示的版本，建议只做下面这些：

- 注册 / 登录
- 我的 Server 列表
- 创建 Server
- Server 下的 text channel 列表
- 进入 channel 查看历史消息
- 发送文本消息
- WebSocket 实时接收新消息

先不要做：

- 权限系统
- 好友系统
- 私聊系统
- 消息编辑 / 删除
- 文件上传
- 已读回执
- 通知系统
- 复杂角色管理
- 完整语音控制台

这些都是真需求，但不适合第一轮学习项目。

## 6. 代码层面的具体建议

### 后端建议

建议逐步演进成类似结构：

```text
backend/
  cmd/server
  internal/config
  internal/handler
  internal/middleware
  internal/service
  internal/repository
  internal/model
  internal/websocket
  pkg
```

每层职责：

- `handler`：HTTP 请求解析、参数校验、返回响应
- `service`：业务逻辑
- `repository`：数据库访问
- `model`：领域模型、数据库模型
- `middleware`：鉴权、日志、错误恢复
- `websocket`：连接管理和事件分发

后端第一批接口建议：

- `POST /api/v1/auth/register`
- `POST /api/v1/auth/login`
- `GET /api/v1/me`
- `GET /api/v1/servers`
- `POST /api/v1/servers`
- `GET /api/v1/servers/:serverId/channels`
- `POST /api/v1/servers/:serverId/channels`
- `GET /api/v1/channels/:channelId/messages`
- `POST /api/v1/channels/:channelId/messages`
- `GET /ws`

### 前端建议

Flutter 侧建议尽快补齐真正的数据流：

```text
feature/
  presentation/
  application/
  domain/
  data/
```

如果你暂时不想分太细，也至少保证：

- `presentation` 只关心页面和状态
- `data` 只关心接口请求、DTO、序列化
- 不要在 Widget 里直接写 Dio 请求

前端优先页面建议：

- 登录页
- Server 列表页
- Channel 列表页
- 消息页
- 语音页先保留占位

## 7. 接下来 2 周的落地任务

### 第 1 周

1. 接入 PostgreSQL，并建立用户、server、channel、message 四张基础表
2. 完成后端注册、登录、当前用户接口
3. Flutter 完成登录页和登录态持久化
4. 完成 server 列表和 channel 列表接口
5. Flutter 做出基础三栏布局雏形

### 第 2 周

1. 完成消息历史查询和发送消息接口
2. Flutter 完成消息列表与发送输入框
3. 实现 WebSocket 鉴权与频道广播
4. 前端接入实时消息
5. 两个客户端互发消息联调通过

## 8. 最推荐你先做的第一批具体事项

如果现在立刻开始开发，我建议按这个顺序提交代码：

1. 后端接 PostgreSQL，并补一份本地配置
2. 后端实现 `auth register/login/me`
3. Flutter 做登录页和 token 管理
4. 后端实现 `servers/channels/messages` 基础表和接口
5. Flutter 做 server 列表、channel 列表、消息页
6. 最后再补 WebSocket 实时收发

## 9. 一句话判断

这个项目的基础方向没问题，但现在还没有真正进入 IM 核心实现阶段。

对学习项目来说，最正确的推进方式不是“继续加更多模块名”，而是先做出：

**登录 -> 进入 Server -> 进入 Channel -> 拉消息 -> 发消息 -> 实时收到消息**

只要这个闭环跑通，你的项目就从“脚手架”正式进入“产品原型”阶段了。
