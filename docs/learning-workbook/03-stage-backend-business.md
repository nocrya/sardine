# 3. 后端业务与数据库阶段

## 学习目标

这一阶段学完后，你应该能做到：

- 分清 model、repository、service 三层职责
- 讲清楚 auth、server、direct message 三块后端业务怎么分开
- 知道权限、邀请码、未读数这些规则主要写在哪层

## 必读文件

- [backend/internal/model/user.go](../../backend/internal/model/user.go)
- [backend/internal/model/server.go](../../backend/internal/model/server.go)
- [backend/internal/model/direct_message.go](../../backend/internal/model/direct_message.go)
- [backend/internal/repository/user_repository.go](../../backend/internal/repository/user_repository.go)
- [backend/internal/repository/server_repository.go](../../backend/internal/repository/server_repository.go)
- [backend/internal/repository/direct_message_repository.go](../../backend/internal/repository/direct_message_repository.go)
- [backend/internal/service/auth_service.go](../../backend/internal/service/auth_service.go)
- [backend/internal/service/server_service.go](../../backend/internal/service/server_service.go)
- [backend/internal/service/direct_message_service.go](../../backend/internal/service/direct_message_service.go)

## 阅读任务

1. 找出用户注册时密码哈希发生在哪。
2. 找出创建 server 时默认频道是在哪里生成的。
3. 找出 owner/admin/member 的权限判断写在哪。
4. 找出邀请码的生成、预览、消费流程写在哪。
5. 找出未读数的数据库计算逻辑写在哪。

## 动手任务

1. 给 server 创建逻辑增加一个新的默认文本频道。
2. 启动后端并创建一个新 server。
3. 确认这个新频道确实被自动创建出来了。

## 练习题

1. 为什么“业务规则”更适合写在 service，而不是 handler？
2. 为什么 repository 要尽量只关心数据库读写？
3. 为什么未读数不能完全依赖前端自己算？

## 过关标准

你能清楚解释：

“model 定义数据长什么样，repository 定义怎么查存，service 定义业务规则怎么运转。”
