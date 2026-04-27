# 6. 前端聊天、私聊和邀请阶段

## 学习目标

这一阶段学完后，你应该能做到：

- 讲清楚 server workspace 是怎么加载和更新的
- 讲清楚私聊列表和已读是怎么工作的
- 讲清楚邀请页是怎么从 code 走到 join 的

## 必读文件

- [frontend/lib/features/server/data/server_models.dart](../../frontend/lib/features/server/data/server_models.dart)
- [frontend/lib/features/server/data/server_remote_datasource.dart](../../frontend/lib/features/server/data/server_remote_datasource.dart)
- [frontend/lib/features/server/data/workspace_realtime_service.dart](../../frontend/lib/features/server/data/workspace_realtime_service.dart)
- [frontend/lib/features/server/presentation/server_cubit.dart](../../frontend/lib/features/server/presentation/server_cubit.dart)
- [frontend/lib/features/server/presentation/server_page.dart](../../frontend/lib/features/server/presentation/server_page.dart)
- [frontend/lib/features/direct_message/data/direct_message_models.dart](../../frontend/lib/features/direct_message/data/direct_message_models.dart)
- [frontend/lib/features/direct_message/data/direct_message_remote_datasource.dart](../../frontend/lib/features/direct_message/data/direct_message_remote_datasource.dart)
- [frontend/lib/features/direct_message/presentation/direct_message_page.dart](../../frontend/lib/features/direct_message/presentation/direct_message_page.dart)
- [frontend/lib/features/invite/data/invite_models.dart](../../frontend/lib/features/invite/data/invite_models.dart)
- [frontend/lib/features/invite/presentation/invite_page.dart](../../frontend/lib/features/invite/presentation/invite_page.dart)

## 阅读任务

1. 找出 server 列表、channel 列表、message 列表分别在哪请求。
2. 找出发消息后本地“发送中”占位消息是怎么处理的。
3. 找出未读数归零逻辑写在哪。
4. 找出 DM 的 typing、read receipt、presence 是怎么处理的。
5. 找出 invite preview 和 join server 分别对应哪个接口。
6. 找出 WebSocket 自动重连和自动重订阅逻辑写在哪。

## 动手任务

1. 给 server 页面某个空状态提示文案改得更清楚。
2. 给 invite 页面增加一段你自己的提示文字。
3. 触发一次真实加入流程，确认页面和接口都正常。

## 练习题

1. 为什么 `ServerCubit` 比 `ServerPage` 更适合承载主状态？
2. 为什么 DM 页面目前没有再单独拆一个 Cubit 也能工作？
3. 为什么未读归零要同时依赖前端状态和后端 read 接口？
4. 自动重连时，为什么要恢复“期望订阅状态”？

## 过关标准

你能清楚讲出：

“server workspace 通过 REST 拉初始数据，通过 WebSocket 收实时事件，通过 read 接口维护未读；DM 和 invite 也是同样的‘接口 + 状态 + 页面’组合。”
