# 第五阶段：前端应用骨架、网络层和认证

这一阶段的目标是理解 Flutter 端的基本组织方式。

## 应用骨架

### `frontend/lib/main.dart`

- 作用：Flutter 程序入口。
- 要点：先初始化依赖，再 `runApp`。

### `frontend/lib/app.dart`

- 作用：应用壳。
- 重点：
  - 注册静态路由
  - 注册动态路由
  - 使用统一主题
  - 展示环境 banner

### `frontend/lib/core/router/app_router.dart`

- 作用：集中管理页面路由。
- 当前重点：
  - 首页、认证页、server、私聊、voice、invite
  - 动态的 `/invite/<code>`
- 初学者要理解：路由路径本身也是产品设计的一部分。

### `frontend/lib/shared/theme/app_theme.dart`

- 作用：全局主题。
- 初学者要理解：这决定应用默认的视觉基调。

### `frontend/lib/shared/widgets/app_gap.dart`

- 作用：统一留白组件。
- 初学者要理解：小组件能减少重复 UI 代码。

## 配置、常量和依赖注入

### `frontend/lib/core/config/app_config.dart`

- 作用：读取 `--dart-define` 配置。
- 重点：
  - 环境名
  - API base URL

### `frontend/lib/core/constants/app_constants.dart`

- 作用：项目常量，尤其是 WebSocket URL 拼接。
- 初学者重点：前端是如何从 HTTP 地址推出 WS 地址的。

### `frontend/lib/core/di/dependency_injection.dart`

- 作用：注册 `Dio`、`SharedPreferences`、datasource、realtime service。
- 初学者要理解：这里是前端版的“应用容器”。

## 网络基础设施

### `frontend/lib/core/network/dio_client.dart`

- 作用：创建统一的 `Dio` 客户端。
- 重点：
  - base URL
  - timeout
  - interceptor

### `frontend/lib/core/network/dio_interceptors.dart`

- 作用：当前主要是日志拦截器。
- 初学者要理解：拦截器很适合放日志、鉴权、刷新 token 逻辑。

### `frontend/lib/core/utils/logger.dart`

- 作用：轻量日志封装。
- 初学者要理解：它只是工具，不是业务。

### `frontend/lib/core/errors/failures.dart`

- 作用：错误抽象占位。
- 当前状态：还很轻，说明项目未来可能向更完整的 clean architecture 演化。

## 认证模块

### `frontend/lib/features/auth/data/auth_session.dart`

- 作用：保存 token 和当前用户信息。
- 学习点：为什么登录态需要本地持久化。

### `frontend/lib/features/auth/data/auth_remote_datasource.dart`

- 作用：认证相关的 API 调用。
- 重点：
  - register
  - login
  - me
  - 保存/读取 session

### `frontend/lib/features/auth/presentation/auth_cubit.dart`

- 作用：认证状态管理。
- 重点看什么：
  - 初始状态
  - loading
  - authenticated
  - error
- 初学者要理解：Cubit 把“网络请求结果”变成“页面状态”。

### `frontend/lib/features/auth/presentation/auth_page.dart`

- 作用：认证页 UI。
- 重点：
  - 登录和注册切换
  - 已登录状态展示
  - 从 invite 页回跳

## 首页模块

### `frontend/lib/features/home/presentation/home_page.dart`

- 作用：项目功能导航页。
- 初学者要理解：它更像一个 demo dashboard，而不是最终产品首页。

### `frontend/lib/features/home/data/home_remote_datasource.dart`

- 作用：当前几乎是占位。
- 初学者要理解：不是每个文件现在都很重，有些是为了未来扩展先占位。

## 这一阶段读完后的检查题

你应该能回答：

- 前端是如何拿到后端 base URL 的？
- 为什么 `AuthCubit` 不直接写在页面里？
- `get_it` 和 `flutter_bloc` 在这个项目里各自负责什么？
