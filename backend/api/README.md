# api

- OpenAPI (Swagger) 或 gRPC 的 `*.proto` 等可放在本目录
- 可为「契约优先」的接口定义，与 `internal/handler` 中实现对应

## 规划

- `openapi/` 或 `openapi.yaml`：REST 契约（可选生成）
- `proto/`：若引入 gRPC（可选）
