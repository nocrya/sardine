# 5. 前端应用骨架与认证阶段

## 学习目标

这一阶段学完后，你应该能做到：

- 知道前端的依赖注入是怎么组织的
- 知道 Dio 请求从哪里发起
- 知道认证状态是怎么恢复和展示的

## 必读文件

- [frontend/lib/app.dart](../../frontend/lib/app.dart)
- [frontend/lib/core/router/app_router.dart](../../frontend/lib/core/router/app_router.dart)
- [frontend/lib/core/config/app_config.dart](../../frontend/lib/core/config/app_config.dart)
- [frontend/lib/core/constants/app_constants.dart](../../frontend/lib/core/constants/app_constants.dart)
- [frontend/lib/core/di/dependency_injection.dart](../../frontend/lib/core/di/dependency_injection.dart)
- [frontend/lib/core/network/dio_client.dart](../../frontend/lib/core/network/dio_client.dart)
- [frontend/lib/core/network/dio_interceptors.dart](../../frontend/lib/core/network/dio_interceptors.dart)
- [frontend/lib/features/auth/data/auth_session.dart](../../frontend/lib/features/auth/data/auth_session.dart)
- [frontend/lib/features/auth/data/auth_remote_datasource.dart](../../frontend/lib/features/auth/data/auth_remote_datasource.dart)
- [frontend/lib/features/auth/presentation/auth_cubit.dart](../../frontend/lib/features/auth/presentation/auth_cubit.dart)
- [frontend/lib/features/auth/presentation/auth_page.dart](../../frontend/lib/features/auth/presentation/auth_page.dart)
- [frontend/lib/features/home/presentation/home_page.dart](../../frontend/lib/features/home/presentation/home_page.dart)

## 阅读任务

1. 找出 `Dio` 是在哪里注册成单例的。
2. 找出 `SharedPreferences` 是在哪里接入的。
3. 找出认证 token 是在哪里保存和恢复的。
4. 找出 `AuthCubit` 是怎么区分登录中、已登录、失败状态的。
5. 找出 invite 登录回跳入口写在哪。

## 动手任务

1. 在首页增加一个新的导航卡片，标题自己定。
2. 让它跳到一个现有页面。
3. 重新运行前端，确认卡片能点、路由能通。

## 练习题

1. `get_it` 在这个项目里主要解决什么问题？
2. `Cubit` 和 `StatefulWidget` 管状态有什么区别？
3. 为什么 token 的保存逻辑不直接写在页面里？

## 过关标准

你能讲清楚：

“前端启动时先注册依赖，认证模块通过 datasource 请求接口并持久化 session，再由 Cubit 把结果映射成页面状态。”
