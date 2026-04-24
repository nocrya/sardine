// Package handler 提供 HTTP 与 WebSocket 的入口，负责请求解析、响应与委托业务层。
package handler

import (
	"database/sql"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/nocrya/sardine/internal/app"
	"github.com/nocrya/sardine/internal/middleware"
	"github.com/nocrya/sardine/internal/websocket"
)

// RegisterRoutes 在路由引擎上注册当前版本 API 与健康检查等路由。
func RegisterRoutes(r *gin.Engine, application *app.App) {
	hub := websocket.NewHub()
	go hub.Run() // 占位：后续在应用生命周期中管理
	authHandler := NewAuthHandler(application)

	r.GET("/healthz", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{"status": "ok"})
	})

	api := r.Group("/api/v1")
	api.GET("/healthz", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"status": "ok",
			"env":    application.Config.Env,
		})
	})
	api.GET("/meta", func(c *gin.Context) {
		c.JSON(http.StatusOK, gin.H{
			"service": "sardine-backend",
			"env":     application.Config.Env,
			"http": gin.H{
				"addr": application.Config.HTTPAddr,
			},
			"database": gin.H{
				"configured": application.Config.Database.DSN != "",
				"connected":  application.DB != nil && pingDB(application.DB) == nil,
			},
		})
	})
	api.POST("/auth/register", authHandler.Register)
	api.POST("/auth/login", authHandler.Login)
	api.GET("/me", middleware.RequireAuth(application.AuthService), authHandler.Me)

	r.GET("/ws", func(c *gin.Context) {
		c.String(http.StatusNotImplemented, "websocket: use Upgrade handler")
	})
}

func pingDB(db *sql.DB) error {
	if db == nil {
		return nil
	}
	return db.Ping()
}
