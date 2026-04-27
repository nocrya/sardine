# 第七阶段：语音页、平台工程和可跳过文件

这一阶段的目标是理解语音功能和平台工程，不要求你一开始就完全掌握。

## 语音模块

### `frontend/lib/features/voice/data/voice_session_data.dart`

- 作用：语音 join 成功后返回的数据模型。
- 重点：
  - room name
  - server URL
  - access token
  - participant info

### `frontend/lib/features/voice/data/voice_remote_datasource.dart`

- 作用：请求后端 voice join 接口。
- 初学者要理解：前端不是自己生成 LiveKit token。

### `frontend/lib/features/voice/presentation/voice_page.dart`

- 作用：最小语音演示页。
- 当前已经具备：
  - 选 server
  - 选 voice channel
  - join / leave room
  - mic on/off
  - participant list
  - speaking 状态展示
  - 加入失败时错误提示
- 初学者要理解：这已经足够展示“语音功能的最小闭环”。

## 前端平台工程：怎么理解就够了

下面这些目录你现在不用逐文件精读，但要知道它们是干什么的。

### `frontend/android/`

- 作用：Android 工程。
- 先关注的文件：
  - `app/build.gradle.kts`
  - `app/src/main/AndroidManifest.xml`
- 其余大多数资源文件、图标文件先不用细读。

### `frontend/ios/`

- 作用：iOS 工程。
- 先关注的文件：
  - `Runner/Info.plist`
  - `Runner/AppDelegate.swift`
- 其余 storyboard、图标资源先知道存在即可。

### `frontend/web/`

- 作用：Flutter Web 壳。
- 先关注的文件：
  - `index.html`
  - `manifest.json`
- 如果你要做 Web 端 invite 直达，这个目录的重要性会提高。

### `frontend/windows/` / `frontend/linux/` / `frontend/macos/`

- 作用：桌面平台壳。
- 初学者阶段建议：
  - 先知道这些目录是 Flutter 自动生成的平台工程
  - 业务主要不在这里

## 其他值得知道但不急着深究的文件

### `backend/api/README.md`

- 作用：API 目录占位说明。

### `backend/pkg/README.md`

- 作用：公共包目录占位说明。

### `frontend/README.md`

- 作用：Flutter 子项目说明。

## 读到这里你应该形成的完整认知

Sardine 的结构大致是：

- 后端：
  - `handler` 接 HTTP / WS
  - `service` 放业务规则
  - `repository` 访问数据库
  - `websocket` 维护实时状态
- 前端：
  - `data` 访问接口和定义模型
  - `presentation` 管页面和状态
  - `core` 放全局基础设施

## 下一步如何练习

适合初学者的练习顺序：

1. 自己加一个新的只读接口，例如“列出我加入的 server 数量”
2. 自己在前端首页加一个统计卡片
3. 自己给某个页面补一个更友好的空状态
4. 自己追一遍“发消息”从页面到数据库的全链路
5. 自己追一遍“join voice”从按钮到 LiveKit 的全链路

如果这五步你都能独立做下来，说明这个项目你已经真正开始上手了。
