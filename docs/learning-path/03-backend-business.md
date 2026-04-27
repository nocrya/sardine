# 第三阶段：后端业务层、数据层和模型

这一阶段开始看真正的业务逻辑。

## Model：项目里的核心数据长什么样

### `backend/internal/model/user.go`

- 作用：用户相关结构。
- 重点理解：
  - 用户公开信息
  - 用户认证相关字段
- 学习价值：它决定 auth 和成员系统都围着什么字段转。

### `backend/internal/model/server.go`

- 作用：server、member、channel、message、invite、voice session 的核心结构。
- 初学者重点：
  - `Server`
  - `Channel`
  - `Message`
  - `ServerInvite`
  - `ServerInvitePreview`
  - `VoiceJoinSession`
- 学习价值：这是项目里最密集的业务模型文件。

### `backend/internal/model/direct_message.go`

- 作用：私聊会话、私聊消息、已读状态模型。
- 初学者重点：
  - 私聊会话和群聊频道不是一回事
  - 私聊也要解决未读、已读、实时事件

## Repository：如何访问数据库

Repository 负责直接和 SQL 打交道。

### `backend/internal/repository/user_repository.go`

- 作用：用户表的 CRUD。
- 重点看什么：
  - 按邮箱/用户名查用户
  - 创建用户
  - 按 ID 取用户

### `backend/internal/repository/server_repository.go`

- 作用：server domain 的数据库访问中心。
- 它通常包含：
  - server 增删查
  - member 角色操作
  - channel 操作
  - message 操作
  - unread/read 游标
  - invite 查询与消费
- 初学者要理解：这是后端最重的 repository，也是最值得慢慢看的文件。

### `backend/internal/repository/direct_message_repository.go`

- 作用：私聊会话、消息、已读的数据库访问。
- 初学者重点：
  - 如何列出会话
  - 如何计算未读
  - 如何保存 read receipt

## Service：真正的业务规则

Service 负责“业务上的对错”，而不是纯数据库读写。

### `backend/internal/service/auth_service.go`

- 作用：注册、登录、JWT、密码哈希。
- 重点看什么：
  - 注册时做哪些校验
  - 登录时如何验证密码
  - token 如何签发和解析

### `backend/internal/service/server_service.go`

- 作用：server 相关所有业务规则。
- 重点看什么：
  - 创建 server 时为什么自动建默认频道
  - owner / admin / member 的权限边界
  - 邀请码的生成、预览、加入
  - unread 为什么要有单独的 read 标记
  - 语音 join token 是怎么返回的
- 初学者要理解：如果你想改业务规则，第一站通常是这里。

### `backend/internal/service/direct_message_service.go`

- 作用：私聊业务规则。
- 重点看什么：
  - 如何创建会话
  - 如何发私聊消息
  - 如何处理已读

## 推荐阅读顺序

建议这样读：

1. `model`
2. `repository`
3. `service`

原因很简单：

- 先知道数据长什么样
- 再看怎么存取
- 最后看业务规则怎么套上去

## 这一阶段读完后的检查题

你应该能回答：

- 为什么 server 和 direct message 要拆成两套 repository/service？
- “权限控制”主要写在 repository 还是 service？
- unread 为什么不能只靠前端本地算？
