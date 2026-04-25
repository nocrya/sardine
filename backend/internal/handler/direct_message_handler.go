package handler

import (
	"errors"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
	"github.com/nocrya/sardine/internal/app"
	"github.com/nocrya/sardine/internal/model"
	"github.com/nocrya/sardine/internal/repository"
	"github.com/nocrya/sardine/internal/service"
	"github.com/nocrya/sardine/internal/websocket"
)

type DirectMessageHandler struct {
	app *app.App
}

type createConversationRequest struct {
	PeerUserID int64 `json:"peer_user_id" binding:"required"`
}

type createDirectMessageRequest struct {
	Content string `json:"content" binding:"required,max=4000"`
}

func NewDirectMessageHandler(application *app.App) *DirectMessageHandler {
	return &DirectMessageHandler{app: application}
}

func (h *DirectMessageHandler) ListConversations(c *gin.Context) {
	userID, ok := authUserID(c)
	if !ok {
		return
	}
	items, err := h.app.DirectMessageService.ListConversations(c.Request.Context(), userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "list direct conversations failed"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"conversations": items})
}

func (h *DirectMessageHandler) CreateConversation(c *gin.Context) {
	userID, ok := authUserID(c)
	if !ok {
		return
	}
	var req createConversationRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	conversationID, err := h.app.DirectMessageService.CreateOrFindConversation(c.Request.Context(), userID, req.PeerUserID)
	if err != nil {
		switch {
		case errors.Is(err, service.ErrInvalidDirectPeer):
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		default:
			c.JSON(http.StatusInternalServerError, gin.H{"error": "create direct conversation failed"})
		}
		return
	}
	c.JSON(http.StatusCreated, gin.H{"conversation_id": conversationID})
}

func (h *DirectMessageHandler) ListMessages(c *gin.Context) {
	userID, ok := authUserID(c)
	if !ok {
		return
	}
	conversationID, err := parseInt64Param(c, "conversationId")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid conversation id"})
		return
	}
	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "50"))
	items, err := h.app.DirectMessageService.ListMessages(c.Request.Context(), userID, conversationID, limit)
	if err != nil {
		switch {
		case errors.Is(err, repository.ErrDirectConversationNotFound):
			c.JSON(http.StatusForbidden, gin.H{"error": "direct conversation access denied"})
		default:
			c.JSON(http.StatusInternalServerError, gin.H{"error": "list direct messages failed"})
		}
		return
	}
	c.JSON(http.StatusOK, gin.H{"messages": items})
}

func (h *DirectMessageHandler) CreateMessage(c *gin.Context) {
	userID, ok := authUserID(c)
	if !ok {
		return
	}
	conversationID, err := parseInt64Param(c, "conversationId")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid conversation id"})
		return
	}
	var req createDirectMessageRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}
	message, err := h.app.DirectMessageService.CreateMessage(c.Request.Context(), userID, conversationID, req.Content)
	if err != nil {
		switch {
		case errors.Is(err, service.ErrInvalidDirectMessage):
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		case errors.Is(err, repository.ErrDirectConversationNotFound):
			c.JSON(http.StatusForbidden, gin.H{"error": "direct conversation access denied"})
		default:
			c.JSON(http.StatusInternalServerError, gin.H{"error": "create direct message failed"})
		}
		return
	}
	h.app.Hub.PublishToDirectConversation(
		conversationID,
		websocket.NewDirectMessageCreatedEvent(conversationID, directMessagePayload(message)),
	)
	c.JSON(http.StatusCreated, gin.H{"message": message})
}

func directMessagePayload(message *model.DirectMessage) map[string]any {
	return map[string]any{
		"id":                  message.ID,
		"conversation_id":     message.ConversationID,
		"sender_id":           message.SenderID,
		"sender_display_name": message.SenderDisplayName,
		"content":             message.Content,
		"created_at":          message.CreatedAt,
		"updated_at":          message.UpdatedAt,
	}
}
