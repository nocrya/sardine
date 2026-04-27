# 1. 根目录与运行阶段

## 学习目标

这一阶段学完后，你应该能做到：

- 说清楚项目的前后端结构
- 知道本地运行依赖哪些服务
- 知道从哪个文件开始看后端和前端

## 必读文件

- [README.md](../../README.md)
- [BASELINE_AND_V2_PLAN.md](../../BASELINE_AND_V2_PLAN.md)
- [Makefile](../../Makefile)
- [docker-compose.yml](../../docker-compose.yml)
- [backend/.env.example](../../backend/.env.example)
- [backend/cmd/server/main.go](../../backend/cmd/server/main.go)
- [frontend/pubspec.yaml](../../frontend/pubspec.yaml)
- [frontend/lib/main.dart](../../frontend/lib/main.dart)
- [frontend/lib/app.dart](../../frontend/lib/app.dart)

## 阅读任务

1. 找出项目使用的主要技术栈。
2. 找出后端启动入口。
3. 找出前端启动入口。
4. 找出本地数据库和 LiveKit 的启动方式。
5. 找出第一版完成标准写在哪个文档里。

## 动手任务

1. 在仓库根目录执行一次：
   - `make run-backend`
   - `make run-frontend`
2. 修改 `frontend/lib/app.dart` 里的应用标题或 banner 颜色。
3. 再次运行前端，确认你的修改真的生效。

## 练习题

1. 为什么 `main.go` 和 `main.dart` 都很短？
2. 为什么 `docker-compose.yml` 不写业务逻辑，却依然重要？
3. `Makefile` 对初学者最大的帮助是什么？

## 过关标准

如果你能不看文档回答下面这句话，说明这一阶段过关了：

“Sardine 是一个 Go 后端 + Flutter 前端的类 Discord 学习项目，本地依赖 PostgreSQL 和 LiveKit，前后端各有明确入口文件。”
