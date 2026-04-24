// Package websocket 管理长连接与 Hub 广播/转发逻辑（可配合 gorilla/websocket 等实现）。
package websocket

import (
	"log"
)

// Hub 在内存中保持客户端集合与广播通道（骨架占位，后续与真实 Conn 类型对接）。
type Hub struct {
	// 示例字段：register / unregister / broadcast
}

// NewHub 创建 Hub 实例。
func NewHub() *Hub {
	return &Hub{}
}

// Run 在独立 goroutine 中处理消息循环。占位：仅打日志，避免空转。
func (h *Hub) Run() {
	log.Print("websocket hub: background loop (placeholder)")
}
