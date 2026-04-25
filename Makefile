.PHONY: help run-backend run-frontend test fmt-backend fmt-frontend docker-up docker-down

help:
	@echo "Sardine 常用目标:"
	@echo "  make run-backend   - 运行 Go 服务 (cd backend && go run ./cmd/server)"
	@echo "  make run-frontend  - 运行 Flutter 应用 (cd frontend && flutter run)"
	@echo "  make test         - 运行前后端测试"
	@echo "  make fmt-backend  - go fmt ./..."
	@echo "  make fmt-frontend - dart format ."
	@echo "  make docker-up    - 后台启动 PostgreSQL + LiveKit (docker compose)"
	@echo "  make docker-down  - 停止并移除容器（保留卷）"

run-backend:
	cd backend && go run ./cmd/server

run-frontend:
	cd frontend && flutter run

test:
	cd backend && go test ./...
	cd frontend && flutter test

fmt-backend:
	cd backend && go fmt ./...

fmt-frontend:
	cd frontend && dart format lib test

docker-up:
	docker compose up -d postgres livekit

docker-down:
	docker compose down
