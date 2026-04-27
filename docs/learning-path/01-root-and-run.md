# 第一阶段：先看根目录和运行方式

这一阶段只做一件事：搞清楚项目是什么、怎么跑、目录怎么分。

## 根目录文件

### `README.md`

- 作用：项目总说明。
- 先看什么：技术栈、前后端目录、基本启动命令。
- 读完你应该知道：这是一个 Go 后端 + Flutter 前端的类 Discord 学习项目。

### `BASELINE_AND_V2_PLAN.md`

- 作用：项目路线图。
- 先看什么：第一版完成标准、第二版优化方向。
- 读完你应该知道：哪些功能已经在做，哪些是后续扩展。

### `NEXT_STEPS.md`

- 作用：更偏开发节奏的任务拆解文档。
- 先看什么：每个阶段为什么这么排。
- 读完你应该知道：这个项目不是一次成型的，而是按阶段推进的。

### `Makefile`

- 作用：把常用命令收起来。
- 重点命令：
  - `make run-backend`
  - `make run-frontend`
  - `make test`
  - `make docker-up`
- 初学者要理解：它不是业务逻辑，只是命令入口。

### `docker-compose.yml`

- 作用：本地开发依赖服务。
- 当前重点：
  - PostgreSQL
  - LiveKit
- 初学者要理解：应用代码不在这里，但没有这些服务，很多功能跑不起来。

### `.gitignore`

- 作用：告诉 Git 哪些文件不要提交。
- 初学者要理解：这和业务无关，但和协作习惯很相关。

## 后端入口相关文件

### `backend/go.mod`

- 作用：Go 模块定义和依赖声明。
- 重点依赖：
  - `gin`
  - `pgx`
  - `gorilla/websocket`
  - `jwt`
  - `viper`
- 初学者要理解：看依赖就能大致猜到后端能力边界。

### `backend/.env.example`

- 作用：后端环境变量示例。
- 重点看什么：
  - HTTP 地址
  - PostgreSQL 连接
  - JWT 配置
  - LiveKit 配置
- 读它的意义：这是“后端运行需要什么”的最短答案。

### `backend/cmd/server/main.go`

- 作用：后端真正启动的入口。
- 重点流程：
  - 读取配置
  - 创建 `App`
  - 启动 WebSocket Hub
  - 创建 Gin Router
  - 注册中间件和路由
  - 启动 HTTP 服务
- 初学者要理解：这是后端“总装配点”。

## 前端入口相关文件

### `frontend/pubspec.yaml`

- 作用：Flutter 项目的依赖和元信息。
- 重点依赖：
  - `flutter_bloc`
  - `get_it`
  - `dio`
  - `shared_preferences`
  - `web_socket_channel`
  - `livekit_client`
- 初学者要理解：它决定了前端采用什么架构工具。

### `frontend/analysis_options.yaml`

- 作用：Dart 静态检查规则。
- 对初学者的意义：这是代码风格和质量约束，不是业务。

### `frontend/lib/main.dart`

- 作用：Flutter 入口。
- 重点流程：
  - `WidgetsFlutterBinding.ensureInitialized()`
  - `configureDependencies()`
  - `runApp()`
- 初学者要理解：前端启动比后端更轻，很多东西交给 `lib/app.dart` 和依赖注入。

### `frontend/lib/app.dart`

- 作用：整个应用的 `MaterialApp` 壳。
- 重点看什么：
  - `theme`
  - `routes`
  - `onGenerateRoute`
  - 环境 banner
- 初学者要理解：这是前端“页面系统”的总入口。

### `frontend/test/widget_test.dart`

- 作用：最基础的挂载测试。
- 初学者要理解：它不是业务测试，但能说明应用至少能启动。

## 这一阶段读完后的检查题

你应该能回答：

- 后端从哪个文件启动？
- 前端从哪个文件启动？
- 本地数据库和 LiveKit 是怎么起来的？
- 项目第一版到底想做到什么程度？
