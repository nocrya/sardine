# Sardine

Sardine 是一个语音聊天社区应用。仓库采用**前后端分离**布局：`backend` 为 Go 服务（Gin、WebSocket、LiveKit 等），`frontend` 为 Flutter 客户端。

## 技术栈

| 层级 | 技术 |
| --- | --- |
| 后端 | Go、Gin、GORM、PostgreSQL、Redis、Viper、LiveKit Server SDK |
| 实时 | WebSocket、LiveKit |
| 前端 | Flutter、flutter_bloc、get_it、Dio、livekit_client |
| 通信 | REST、WebSocket |

## 本地运行

### 环境要求

- Go 1.22+（以本机 `go version` 为准）
- Flutter SDK（[安装](https://docs.flutter.cn/get-started/install)），并将 `flutter` 加入 `PATH`
- 若 `frontend` 中仅有本仓库提供的源码与 `pubspec.yaml`、**还未生成** Android / iOS 等平台目录，在 `frontend` 下执行一次 `flutter create .` 以补齐平台工程（不会覆盖已存在的 `lib`）

### 后端

```bash
cd backend
go run ./cmd/server
```

或从仓库根目录使用：

```bash
make run-backend
```

默认监听地址在配置中定义；占位阶段可在 `backend/internal/config` 中调整。

### 前端

```bash
cd frontend
flutter pub get
flutter run
```

或：

```bash
make run-frontend
```

## 开发命令（Makefile）

| 目标 | 说明 |
| --- | --- |
| `make run-backend` | 运行 Go 服务 |
| `make run-frontend` | 运行 Flutter 应用（默认设备） |
| `make test` | 运行后端与前端测试 |

## 目录说明

- `backend/`：Go 服务，分层为 Handler → Service → Repository
- `frontend/`：Flutter 应用，按 `features` 划分功能模块
- 详细结构见各子目录内注释与占位文件
