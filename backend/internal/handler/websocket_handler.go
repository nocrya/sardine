package handler

import (
	"context"
	"net/http"

	"github.com/gin-gonic/gin"
	gws "github.com/gorilla/websocket"
	"github.com/nocrya/sardine/internal/app"
	"github.com/nocrya/sardine/internal/websocket"
)

type WebSocketHandler struct {
	app      *app.App
	upgrader gws.Upgrader
}

type websocketCommand struct {
	Type           string `json:"type"`
	ServerID       int64  `json:"server_id"`
	ChannelID      int64  `json:"channel_id"`
	ConversationID int64  `json:"conversation_id"`
	MessageID      int64  `json:"message_id"`
}

func NewWebSocketHandler(application *app.App) *WebSocketHandler {
	return &WebSocketHandler{
		app: application,
		upgrader: gws.Upgrader{
			CheckOrigin: func(r *http.Request) bool {
				return true
			},
		},
	}
}

func (h *WebSocketHandler) Serve(c *gin.Context) {
	token := c.Query("token")
	if token == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "missing token"})
		return
	}

	claims, err := h.app.AuthService.ParseToken(token)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid token"})
		return
	}
	user, err := h.app.AuthService.GetCurrentUser(c.Request.Context(), claims.UserID)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "user not found"})
		return
	}

	conn, err := h.upgrader.Upgrade(c.Writer, c.Request, nil)
	if err != nil {
		return
	}

	client := h.app.Hub.Register(conn, claims.UserID, user.DisplayName)
	go client.WritePump()
	h.readLoop(c.Request.Context(), client)
}

func (h *WebSocketHandler) readLoop(ctx context.Context, client *websocket.Client) {
	defer client.Close()

	for {
		var command websocketCommand
		if err := client.ReadJSON(&command); err != nil {
			return
		}

		switch command.Type {
		case "subscribe":
			if err := h.app.ServerService.CanAccessChannel(ctx, client.UserID(), command.ChannelID); err != nil {
				continue
			}
			serverID, err := h.app.ServerService.ResolveServerIDByChannel(ctx, command.ChannelID)
			if err != nil {
				continue
			}
			h.app.Hub.Subscribe(client, serverID, command.ChannelID)
		case "direct.subscribe":
			if err := h.app.DirectMessageService.CanAccessConversation(ctx, client.UserID(), command.ConversationID); err != nil {
				continue
			}
			readStates, err := h.app.DirectMessageService.ListReadStates(ctx, client.UserID(), command.ConversationID)
			if err != nil {
				continue
			}
			h.app.Hub.SubscribeToDirectConversation(client, command.ConversationID, readStates)
		case "unsubscribe":
			h.app.Hub.Unsubscribe(client, command.ChannelID)
		case "direct.unsubscribe":
			h.app.Hub.UnsubscribeFromDirectConversation(client, command.ConversationID)
		case "typing.start":
			if err := h.app.ServerService.CanAccessChannel(ctx, client.UserID(), command.ChannelID); err != nil {
				continue
			}
			profile := h.app.Hub.Touch(client.UserID())
			h.app.Hub.PublishToChannel(
				command.ChannelID,
				websocket.NewTypingStartedEvent(command.ChannelID, profile),
			)
		case "typing.stop":
			if err := h.app.ServerService.CanAccessChannel(ctx, client.UserID(), command.ChannelID); err != nil {
				continue
			}
			profile := h.app.Hub.Touch(client.UserID())
			h.app.Hub.PublishToChannel(
				command.ChannelID,
				websocket.NewTypingStoppedEvent(command.ChannelID, profile),
			)
		case "direct.typing.start":
			if err := h.app.DirectMessageService.CanAccessConversation(ctx, client.UserID(), command.ConversationID); err != nil {
				continue
			}
			profile := h.app.Hub.Touch(client.UserID())
			h.app.Hub.PublishToDirectConversation(
				command.ConversationID,
				websocket.NewDirectTypingStartedEvent(command.ConversationID, profile),
			)
		case "direct.typing.stop":
			if err := h.app.DirectMessageService.CanAccessConversation(ctx, client.UserID(), command.ConversationID); err != nil {
				continue
			}
			profile := h.app.Hub.Touch(client.UserID())
			h.app.Hub.PublishToDirectConversation(
				command.ConversationID,
				websocket.NewDirectTypingStoppedEvent(command.ConversationID, profile),
			)
		case "direct.read":
			if err := h.app.DirectMessageService.CanAccessConversation(ctx, client.UserID(), command.ConversationID); err != nil {
				continue
			}
			readState, err := h.app.DirectMessageService.MarkRead(ctx, client.UserID(), command.ConversationID, command.MessageID)
			if err != nil {
				continue
			}
			h.app.Hub.PublishToDirectConversation(
				command.ConversationID,
				websocket.NewDirectReadUpdatedEvent(command.ConversationID, readState),
			)
		case "presence.sync":
			if err := h.app.ServerService.CanAccessServer(ctx, client.UserID(), command.ServerID); err != nil {
				continue
			}
			h.app.Hub.PublishToServer(
				command.ServerID,
				websocket.NewServerPresenceUpdatedEvent(command.ServerID, h.app.Hub.Touch(client.UserID())),
			)
		}
	}
}
