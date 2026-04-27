# 7. 语音与第一版收口阶段

## 学习目标

这一阶段学完后，你应该能做到：

- 讲清楚语音房间加入的完整链路
- 讲清楚 speaking 状态是怎么展示的
- 结合第一版完成标准判断项目是否已经成型

## 必读文件

- [frontend/lib/features/voice/data/voice_remote_datasource.dart](../../frontend/lib/features/voice/data/voice_remote_datasource.dart)
- [frontend/lib/features/voice/data/voice_session_data.dart](../../frontend/lib/features/voice/data/voice_session_data.dart)
- [frontend/lib/features/voice/presentation/voice_page.dart](../../frontend/lib/features/voice/presentation/voice_page.dart)
- [BASELINE_AND_V2_PLAN.md](../../BASELINE_AND_V2_PLAN.md)

## 阅读任务

1. 找出 join voice 的 HTTP 请求在哪发。
2. 找出 LiveKit token 是前端从哪里拿到的。
3. 找出 participant 列表和 speaking 状态展示写在哪。
4. 对照第一版完成标准，列出当前已经实现的项。
5. 对照文档，列出当前还属于“工程化提升”的项。

## 动手任务

1. 修改 voice 页面里一个状态文案，比如把 `Not connected` 改成你更喜欢的说法。
2. 实际进入一次 voice room，验证：
   - 能加入
   - 能离开
   - 能看到 participant
   - 能看到 speaking / idle
3. 把你的观察记录成 5 行笔记。

## 练习题

1. 为什么语音页没有直接复用 server 页面？
2. speaking 状态为什么更适合实时显示，而不是持久化到数据库？
3. “第一版完成”为什么不等于“工程上已经完全成熟”？

## 过关标准

如果你能独立讲清下面这段话，这一阶段就过关了：

“前端先请求后端获取 voice join 数据，再用 LiveKit 客户端连入房间，参与者列表和 speaking 状态实时展示；从产品能力上，这个项目已经满足第一版演示目标。”
