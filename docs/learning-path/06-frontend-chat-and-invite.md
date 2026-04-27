# 第六阶段：前端聊天工作区、私聊和邀请页

这一阶段是前端最核心的业务部分。

## Server Workspace

### `frontend/lib/features/server/data/server_models.dart`

- 作用：承载 server、channel、message、member、invite 的前端模型。
- 初学者重点：
  - `WorkspaceServer`
  - `WorkspaceChannel`
  - `WorkspaceMessage`
  - `WorkspaceServerInvite`

### `frontend/lib/features/server/data/server_remote_datasource.dart`

- 作用：server domain 的所有 HTTP 请求。
- 重点看什么：
  - list servers / channels / messages
  - create server / create channel
  - invite member / create invite link / join by invite code
  - mark channel read

### `frontend/lib/features/server/data/workspace_realtime_service.dart`

- 作用：前端实时服务。
- 重点看什么：
  - WebSocket connect
  - channel subscribe
  - direct subscribe
  - presence sync
  - 自动重连
  - 自动重订阅
- 初学者要理解：这是前端实时能力的核心文件。

### `frontend/lib/features/server/presentation/server_cubit.dart`

- 作用：server workspace 的状态管理中心。
- 它负责：
  - 初始化 server / channel / message
  - 发送消息
  - 加载更早消息
  - 邀请成员
  - 角色更新
  - owner 转移
  - 已读归零
  - 处理实时事件
- 初学者要理解：如果你想理解“文本频道是怎么跑起来的”，这个文件必须认真看。

### `frontend/lib/features/server/presentation/server_page.dart`

- 作用：workspace 主页面。
- 页面里你能看到：
  - server 列表
  - channel 列表
  - message 区域
  - members 面板
  - invite link 入口
  - unread badge
- 初学者要理解：这个页面是“后端多条 API + WebSocket + 本地状态”的集中展示。

## 私聊模块

### `frontend/lib/features/direct_message/data/direct_message_models.dart`

- 作用：私聊会话、消息、已读模型。

### `frontend/lib/features/direct_message/data/direct_message_remote_datasource.dart`

- 作用：私聊 HTTP 请求。
- 重点：
  - 列会话
  - 建会话
  - 拉消息
  - 发消息

### `frontend/lib/features/direct_message/presentation/direct_message_page.dart`

- 作用：私聊页 UI + 状态。
- 当前特点：
  - 页面内自己维护状态
  - 复用同一个 realtime service
  - 显示未读、typing、peer online、read receipt
- 初学者要理解：它和 `ServerCubit` 形成了两种不同的前端组织方式。

## 邀请页模块

### `frontend/lib/features/invite/data/invite_models.dart`

- 作用：邀请预览模型。
- 重点字段：
  - server 名称
  - role
  - member/channel 数
  - 过期状态

### `frontend/lib/features/invite/presentation/invite_page.dart`

- 作用：真正的邀请码落地页。
- 它做的事：
  - 解析 code
  - 请求 invite preview
  - 引导去登录
  - 登录后加入 server
- 初学者要理解：这就是“产品化入口页”的例子。

## 推荐阅读顺序

建议这样读：

1. `server_models.dart`
2. `server_remote_datasource.dart`
3. `workspace_realtime_service.dart`
4. `server_cubit.dart`
5. `server_page.dart`
6. `direct_message_*`
7. `invite_*`

## 这一阶段读完后的检查题

你应该能回答：

- server workspace 为什么适合用 Cubit？
- 私聊页为什么也能复用同一个 realtime service？
- unread badge 的数据到底来自后端还是前端？
