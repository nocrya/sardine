# 2. 后端启动与 HTTP 骨架阶段

## 学习目标

这一阶段学完后，你应该能做到：

- 讲清楚后端是怎么启动起来的
- 讲清楚请求是怎么进入 handler 的
- 分清 `config / app / routes / handler / middleware` 的职责

## 必读文件

- [backend/internal/config/config.go](../../backend/internal/config/config.go)
- [backend/internal/database/postgres.go](../../backend/internal/database/postgres.go)
- [backend/internal/database/migrations.go](../../backend/internal/database/migrations.go)
- [backend/internal/app/app.go](../../backend/internal/app/app.go)
- [backend/internal/handler/routes.go](../../backend/internal/handler/routes.go)
- [backend/internal/middleware/middleware.go](../../backend/internal/middleware/middleware.go)
- [backend/internal/handler/auth_handler.go](../../backend/internal/handler/auth_handler.go)
- [backend/internal/handler/server_handler.go](../../backend/internal/handler/server_handler.go)
- [backend/internal/handler/direct_message_handler.go](../../backend/internal/handler/direct_message_handler.go)

## 阅读任务

1. 画出 `main.go -> app.New -> RegisterRoutes` 的调用链。
2. 找出数据库连接是在什么地方创建的。
3. 找出自动建表是在什么地方触发的。
4. 找出公开接口和鉴权接口是怎么分组的。
5. 找出 CORS 是怎么挂进去的。

## 动手任务

1. 给 `GET /api/v1/meta` 的返回里新增一个简单字段，比如 `version: "local-dev"`。
2. 启动后端并用浏览器或 Postman 访问它。
3. 确认返回 JSON 里真的有这个字段。

## 练习题

1. `App` 容器存在的意义是什么？
2. 为什么 `routes.go` 不直接写具体业务？
3. 为什么 handler 层通常不直接写 SQL？

## 过关标准

你能完整讲出：

“配置先加载，`App` 再初始化共享资源，Gin Router 注册中间件和路由，请求进入 handler 后再交给 service。”
