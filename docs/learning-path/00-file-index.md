# 核心文件索引

这个索引的用途很简单：当你看到某个文件时，能立刻知道应该去看哪一阶段的文档。

## 根目录

- `README.md` -> `01-root-and-run.md`
- `BASELINE_AND_V2_PLAN.md` -> `01-root-and-run.md`
- `NEXT_STEPS.md` -> `01-root-and-run.md`
- `Makefile` -> `01-root-and-run.md`
- `docker-compose.yml` -> `01-root-and-run.md`

## 后端：启动与配置

- `backend/.env.example` -> `01-root-and-run.md`
- `backend/go.mod` -> `01-root-and-run.md`
- `backend/cmd/server/main.go` -> `01-root-and-run.md`
- `backend/internal/config/config.go` -> `02-backend-startup.md`
- `backend/internal/database/postgres.go` -> `02-backend-startup.md`
- `backend/internal/database/migrations.go` -> `02-backend-startup.md`
- `backend/internal/app/app.go` -> `02-backend-startup.md`
- `backend/internal/handler/routes.go` -> `02-backend-startup.md`
- `backend/internal/middleware/middleware.go` -> `02-backend-startup.md`
- `backend/internal/handler/auth_handler.go` -> `02-backend-startup.md`
- `backend/internal/handler/server_handler.go` -> `02-backend-startup.md`
- `backend/internal/handler/direct_message_handler.go` -> `02-backend-startup.md`
- `backend/internal/handler/websocket_handler.go` -> `02-backend-startup.md`

## 后端：业务与数据库

- `backend/internal/model/user.go` -> `03-backend-business.md`
- `backend/internal/model/server.go` -> `03-backend-business.md`
- `backend/internal/model/direct_message.go` -> `03-backend-business.md`
- `backend/internal/repository/user_repository.go` -> `03-backend-business.md`
- `backend/internal/repository/server_repository.go` -> `03-backend-business.md`
- `backend/internal/repository/direct_message_repository.go` -> `03-backend-business.md`
- `backend/internal/service/auth_service.go` -> `03-backend-business.md`
- `backend/internal/service/server_service.go` -> `03-backend-business.md`
- `backend/internal/service/direct_message_service.go` -> `03-backend-business.md`

## 后端：实时与语音

- `backend/internal/websocket/events.go` -> `04-backend-realtime.md`
- `backend/internal/websocket/hub.go` -> `04-backend-realtime.md`
- `backend/internal/handler/websocket_handler.go` -> `04-backend-realtime.md`
- `backend/internal/handler/server_handler.go` -> `04-backend-realtime.md`
- `backend/internal/service/server_service.go` -> `04-backend-realtime.md`

## 前端：应用骨架与认证

- `frontend/pubspec.yaml` -> `01-root-and-run.md`
- `frontend/analysis_options.yaml` -> `01-root-and-run.md`
- `frontend/lib/main.dart` -> `01-root-and-run.md`
- `frontend/lib/app.dart` -> `01-root-and-run.md`
- `frontend/lib/core/router/app_router.dart` -> `05-frontend-app-and-auth.md`
- `frontend/lib/shared/theme/app_theme.dart` -> `05-frontend-app-and-auth.md`
- `frontend/lib/shared/widgets/app_gap.dart` -> `05-frontend-app-and-auth.md`
- `frontend/lib/core/config/app_config.dart` -> `05-frontend-app-and-auth.md`
- `frontend/lib/core/constants/app_constants.dart` -> `05-frontend-app-and-auth.md`
- `frontend/lib/core/di/dependency_injection.dart` -> `05-frontend-app-and-auth.md`
- `frontend/lib/core/network/dio_client.dart` -> `05-frontend-app-and-auth.md`
- `frontend/lib/core/network/dio_interceptors.dart` -> `05-frontend-app-and-auth.md`
- `frontend/lib/core/utils/logger.dart` -> `05-frontend-app-and-auth.md`
- `frontend/lib/core/errors/failures.dart` -> `05-frontend-app-and-auth.md`
- `frontend/lib/features/auth/data/auth_session.dart` -> `05-frontend-app-and-auth.md`
- `frontend/lib/features/auth/data/auth_remote_datasource.dart` -> `05-frontend-app-and-auth.md`
- `frontend/lib/features/auth/presentation/auth_cubit.dart` -> `05-frontend-app-and-auth.md`
- `frontend/lib/features/auth/presentation/auth_page.dart` -> `05-frontend-app-and-auth.md`
- `frontend/lib/features/home/data/home_remote_datasource.dart` -> `05-frontend-app-and-auth.md`
- `frontend/lib/features/home/presentation/home_page.dart` -> `05-frontend-app-and-auth.md`

## 前端：聊天与邀请

- `frontend/lib/features/server/data/server_models.dart` -> `06-frontend-chat-and-invite.md`
- `frontend/lib/features/server/data/server_remote_datasource.dart` -> `06-frontend-chat-and-invite.md`
- `frontend/lib/features/server/data/workspace_realtime_service.dart` -> `06-frontend-chat-and-invite.md`
- `frontend/lib/features/server/presentation/server_cubit.dart` -> `06-frontend-chat-and-invite.md`
- `frontend/lib/features/server/presentation/server_page.dart` -> `06-frontend-chat-and-invite.md`
- `frontend/lib/features/direct_message/data/direct_message_models.dart` -> `06-frontend-chat-and-invite.md`
- `frontend/lib/features/direct_message/data/direct_message_remote_datasource.dart` -> `06-frontend-chat-and-invite.md`
- `frontend/lib/features/direct_message/presentation/direct_message_page.dart` -> `06-frontend-chat-and-invite.md`
- `frontend/lib/features/invite/data/invite_models.dart` -> `06-frontend-chat-and-invite.md`
- `frontend/lib/features/invite/presentation/invite_page.dart` -> `06-frontend-chat-and-invite.md`

## 前端：语音

- `frontend/lib/features/voice/data/voice_session_data.dart` -> `07-frontend-voice-and-platform.md`
- `frontend/lib/features/voice/data/voice_remote_datasource.dart` -> `07-frontend-voice-and-platform.md`
- `frontend/lib/features/voice/presentation/voice_page.dart` -> `07-frontend-voice-and-platform.md`

## 测试与说明文件

- `frontend/test/widget_test.dart` -> `01-root-and-run.md`
- `backend/api/README.md` -> `07-frontend-voice-and-platform.md`
- `backend/pkg/README.md` -> `07-frontend-voice-and-platform.md`
- `frontend/README.md` -> `07-frontend-voice-and-platform.md`

## 当前不逐个展开的文件

下面这些目录目前统一按“平台样板或静态资源”处理：

- `frontend/android/`
- `frontend/ios/`
- `frontend/web/`
- `frontend/windows/`
- `frontend/linux/`
- `frontend/macos/`

如果你后面要做平台权限、打包、桌面端适配，再单独读这些目录。
