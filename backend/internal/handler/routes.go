// Package handler 提供 HTTP 与 WebSocket 的入口，负责请求解析、响应与委托业务层。
package handler

import (
	"database/sql"
	"net/http"

	"github.com/gin-gonic/gin"
	"github.com/nocrya/sardine/internal/app"
	"github.com/nocrya/sardine/internal/middleware"
)

// RegisterRoutes 在路由引擎上注册当前版本 API 与健康检查等路由。
func RegisterRoutes(r *gin.Engine, application *app.App) {
	authHandler := NewAuthHandler(application)
	serverHandler := NewServerHandler(application)
	directMessageHandler := NewDirectMessageHandler(application)
	websocketHandler := NewWebSocketHandler(application)

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
	api.GET("/invites/:code", serverHandler.PreviewInvite)
	api.POST("/auth/register", authHandler.Register)
	api.POST("/auth/login", authHandler.Login)
	api.GET("/me", middleware.RequireAuth(application.AuthService), authHandler.Me)
	authed := api.Group("/")
	authed.Use(middleware.RequireAuth(application.AuthService))
	authed.POST("/invites/join", serverHandler.JoinByInviteCode)
	authed.GET("/servers", serverHandler.ListServers)
	authed.POST("/servers", serverHandler.CreateServer)
	authed.POST("/servers/:serverId/leave", serverHandler.LeaveServer)
	authed.GET("/servers/:serverId/members", serverHandler.ListMembers)
	authed.POST("/servers/:serverId/invites", serverHandler.InviteMember)
	authed.POST("/servers/:serverId/invite-links", serverHandler.CreateInviteLink)
	authed.POST("/servers/:serverId/transfer-ownership", serverHandler.TransferOwnership)
	authed.PATCH("/servers/:serverId/members/:memberId", serverHandler.UpdateMemberRole)
	authed.DELETE("/servers/:serverId/members/:memberId", serverHandler.RemoveMember)
	authed.GET("/servers/:serverId/channels", serverHandler.ListChannels)
	authed.POST("/servers/:serverId/channels", serverHandler.CreateChannel)
	authed.GET("/channels/:channelId/messages", serverHandler.ListMessages)
	authed.POST("/channels/:channelId/messages", serverHandler.CreateMessage)
	authed.POST("/channels/:channelId/read", serverHandler.MarkChannelRead)
	authed.POST("/channels/:channelId/voice/join", serverHandler.JoinVoiceChannel)
	authed.GET("/direct-conversations", directMessageHandler.ListConversations)
	authed.POST("/direct-conversations", directMessageHandler.CreateConversation)
	authed.GET("/direct-conversations/:conversationId/messages", directMessageHandler.ListMessages)
	authed.POST("/direct-conversations/:conversationId/messages", directMessageHandler.CreateMessage)

	r.GET("/ws", websocketHandler.Serve)
}

func pingDB(db *sql.DB) error {
	if db == nil {
		return nil
	}
	return db.Ping()
}
