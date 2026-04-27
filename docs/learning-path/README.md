# Sardine 学习文档

这组文档是给初学者准备的，目标不是把所有实现细节一次讲完，而是给你一条能走通的阅读路径。

## 怎么使用

按下面顺序读：

1. [00-file-index.md](./00-file-index.md)
2. [01-root-and-run.md](./01-root-and-run.md)
3. [02-backend-startup.md](./02-backend-startup.md)
4. [03-backend-business.md](./03-backend-business.md)
5. [04-backend-realtime.md](./04-backend-realtime.md)
6. [05-frontend-app-and-auth.md](./05-frontend-app-and-auth.md)
7. [06-frontend-chat-and-invite.md](./06-frontend-chat-and-invite.md)
8. [07-frontend-voice-and-platform.md](./07-frontend-voice-and-platform.md)

## 这套文档覆盖哪些文件

重点覆盖三类文件：

- 根目录下决定怎么运行项目的文件
- `backend` 里真正承载业务逻辑的文件
- `frontend/lib` 里真正承载界面、状态和网络逻辑的文件

## 哪些文件先不要逐个硬啃

为了适合初学者，这套文档不会逐个解释下面这些文件：

- Flutter / Android / iOS / macOS / Windows / Linux 的自动生成图标和资源文件
- `go.sum`、`pubspec.lock` 这类依赖锁文件
- 平台工程里只有样板作用、几乎不承载业务的文件

这些文件不是不重要，而是它们对“先理解 Sardine 这个项目怎么工作”帮助不大。

## 建议的学习方法

- 每读完一个阶段，就自己画一张“请求流转图”或“状态变化图”
- 每看完一组文件，就跑一次对应功能
- 先理解“数据从哪来，到哪去”，再去看语法细节

## 项目阅读总顺序

如果你只能记一条主线，就记这个：

`启动 -> 配置 -> 路由 -> handler -> service -> repository -> model -> 前端 datasource -> state -> 页面`

这基本就是 Sardine 的主路径。
