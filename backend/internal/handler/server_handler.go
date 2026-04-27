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

type ServerHandler struct {
	app *app.App
}

func NewServerHandler(application *app.App) *ServerHandler {
	return &ServerHandler{app: application}
}

type createServerRequest struct {
	Name        string `json:"name" binding:"required,min=2,max=64"`
	Description string `json:"description" binding:"max=240"`
}

type createChannelRequest struct {
	Name  string `json:"name" binding:"required,min=2,max=64"`
	Kind  string `json:"kind" binding:"max=16"`
	Topic string `json:"topic" binding:"max=240"`
}

type createMessageRequest struct {
	Content string `json:"content" binding:"required,max=4000"`
}

type inviteMemberRequest struct {
	Email string `json:"email" binding:"required,email"`
	Role  string `json:"role" binding:"max=16"`
}

type createInviteLinkRequest struct {
	Role    string `json:"role" binding:"max=16"`
	MaxUses int64  `json:"max_uses" binding:"min=0,max=9999"`
}

type updateMemberRoleRequest struct {
	Role string `json:"role" binding:"required,max=16"`
}

type transferOwnershipRequest struct {
	NextOwnerUserID int64 `json:"next_owner_user_id" binding:"required"`
}

type joinServerByInviteRequest struct {
	Code string `json:"code" binding:"required"`
}

type markChannelReadRequest struct {
	MessageID int64 `json:"message_id" binding:"required"`
}

func (h *ServerHandler) ListServers(c *gin.Context) {
	userID, ok := authUserID(c)
	if !ok {
		return
	}

	servers, err := h.app.ServerService.ListServers(c.Request.Context(), userID)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "list servers failed"})
		return
	}
	c.JSON(http.StatusOK, gin.H{"servers": servers})
}

func (h *ServerHandler) CreateServer(c *gin.Context) {
	userID, ok := authUserID(c)
	if !ok {
		return
	}

	var req createServerRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	server, channels, err := h.app.ServerService.CreateServer(c.Request.Context(), service.CreateServerInput{
		OwnerID:     userID,
		Name:        req.Name,
		Description: req.Description,
	})
	if err != nil {
		switch {
		case errors.Is(err, service.ErrInvalidServerName):
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		default:
			c.JSON(http.StatusInternalServerError, gin.H{"error": "create server failed"})
		}
		return
	}

	c.JSON(http.StatusCreated, gin.H{
		"server":   server,
		"channels": channels,
	})
}

func (h *ServerHandler) ListChannels(c *gin.Context) {
	userID, ok := authUserID(c)
	if !ok {
		return
	}

	serverID, err := parseInt64Param(c, "serverId")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid server id"})
		return
	}

	channels, err := h.app.ServerService.ListChannels(c.Request.Context(), userID, serverID)
	if err != nil {
		switch {
		case errors.Is(err, repository.ErrNotMember):
			c.JSON(http.StatusForbidden, gin.H{"error": "server access denied"})
		default:
			c.JSON(http.StatusInternalServerError, gin.H{"error": "list channels failed"})
		}
		return
	}
	c.JSON(http.StatusOK, gin.H{"channels": channels})
}

func (h *ServerHandler) CreateChannel(c *gin.Context) {
	userID, ok := authUserID(c)
	if !ok {
		return
	}

	serverID, err := parseInt64Param(c, "serverId")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid server id"})
		return
	}

	var req createChannelRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	channel, err := h.app.ServerService.CreateChannel(c.Request.Context(), service.CreateChannelInput{
		UserID:   userID,
		ServerID: serverID,
		Name:     req.Name,
		Kind:     req.Kind,
		Topic:    req.Topic,
	})
	if err != nil {
		switch {
		case errors.Is(err, service.ErrInvalidChannelName), errors.Is(err, service.ErrUnsupportedChannelKind):
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		case errors.Is(err, service.ErrPermissionDenied):
			c.JSON(http.StatusForbidden, gin.H{"error": "missing manage channel permission"})
		case errors.Is(err, repository.ErrNotMember):
			c.JSON(http.StatusForbidden, gin.H{"error": "server access denied"})
		default:
			c.JSON(http.StatusInternalServerError, gin.H{"error": "create channel failed"})
		}
		return
	}
	c.JSON(http.StatusCreated, gin.H{"channel": channel})
}

func (h *ServerHandler) ListMessages(c *gin.Context) {
	userID, ok := authUserID(c)
	if !ok {
		return
	}

	channelID, err := parseInt64Param(c, "channelId")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid channel id"})
		return
	}

	limit, _ := strconv.Atoi(c.DefaultQuery("limit", "50"))
	beforeID, _ := strconv.ParseInt(c.DefaultQuery("before_id", "0"), 10, 64)
	page, err := h.app.ServerService.ListMessages(c.Request.Context(), userID, channelID, limit, beforeID)
	if err != nil {
		switch {
		case errors.Is(err, repository.ErrNotMember):
			c.JSON(http.StatusForbidden, gin.H{"error": "channel access denied"})
		case errors.Is(err, repository.ErrChannelNotFound):
			c.JSON(http.StatusNotFound, gin.H{"error": "channel not found"})
		default:
			c.JSON(http.StatusInternalServerError, gin.H{"error": "list messages failed"})
		}
		return
	}
	c.JSON(http.StatusOK, gin.H{
		"messages":       page.Messages,
		"has_more":       page.HasMore,
		"next_before_id": page.NextBeforeID,
	})
}

func (h *ServerHandler) CreateMessage(c *gin.Context) {
	userID, ok := authUserID(c)
	if !ok {
		return
	}

	channelID, err := parseInt64Param(c, "channelId")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid channel id"})
		return
	}

	var req createMessageRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	message, err := h.app.ServerService.CreateMessage(c.Request.Context(), service.CreateMessageInput{
		UserID:    userID,
		ChannelID: channelID,
		Content:   req.Content,
	})
	if err != nil {
		switch {
		case errors.Is(err, service.ErrInvalidMessage):
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		case errors.Is(err, repository.ErrNotMember):
			c.JSON(http.StatusForbidden, gin.H{"error": "channel access denied"})
		case errors.Is(err, repository.ErrChannelNotFound):
			c.JSON(http.StatusNotFound, gin.H{"error": "channel not found"})
		default:
			c.JSON(http.StatusInternalServerError, gin.H{"error": "create message failed"})
		}
		return
	}
	h.app.Hub.PublishToChannel(
		channelID,
		websocket.NewMessageCreatedWithPayload(channelID, messagePayload(message)),
	)
	c.JSON(http.StatusCreated, gin.H{"message": message})
}

func (h *ServerHandler) MarkChannelRead(c *gin.Context) {
	userID, ok := authUserID(c)
	if !ok {
		return
	}

	channelID, err := parseInt64Param(c, "channelId")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid channel id"})
		return
	}

	var req markChannelReadRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	if err := h.app.ServerService.MarkChannelRead(c.Request.Context(), userID, channelID, req.MessageID); err != nil {
		switch {
		case errors.Is(err, service.ErrInvalidMessage):
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		case errors.Is(err, repository.ErrNotMember):
			c.JSON(http.StatusForbidden, gin.H{"error": "channel access denied"})
		case errors.Is(err, repository.ErrChannelNotFound):
			c.JSON(http.StatusNotFound, gin.H{"error": "channel not found"})
		default:
			c.JSON(http.StatusInternalServerError, gin.H{"error": "mark channel read failed"})
		}
		return
	}
	c.JSON(http.StatusOK, gin.H{"status": "read"})
}

func (h *ServerHandler) ListMembers(c *gin.Context) {
	userID, ok := authUserID(c)
	if !ok {
		return
	}

	serverID, err := parseInt64Param(c, "serverId")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid server id"})
		return
	}

	members, err := h.app.ServerService.ListMembers(c.Request.Context(), userID, serverID)
	if err != nil {
		switch {
		case errors.Is(err, repository.ErrNotMember):
			c.JSON(http.StatusForbidden, gin.H{"error": "server access denied"})
		default:
			c.JSON(http.StatusInternalServerError, gin.H{"error": "list members failed"})
		}
		return
	}
	c.JSON(http.StatusOK, gin.H{"members": members})
}

func (h *ServerHandler) InviteMember(c *gin.Context) {
	userID, ok := authUserID(c)
	if !ok {
		return
	}

	serverID, err := parseInt64Param(c, "serverId")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid server id"})
		return
	}

	var req inviteMemberRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	members, err := h.app.ServerService.InviteMember(c.Request.Context(), service.InviteMemberInput{
		ActorUserID: userID,
		ServerID:    serverID,
		Email:       req.Email,
		Role:        req.Role,
	})
	if err != nil {
		switch {
		case errors.Is(err, service.ErrInvalidInviteEmail), errors.Is(err, service.ErrInvalidRole):
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		case errors.Is(err, service.ErrPermissionDenied):
			c.JSON(http.StatusForbidden, gin.H{"error": "missing invite permission"})
		case errors.Is(err, repository.ErrNotMember):
			c.JSON(http.StatusForbidden, gin.H{"error": "server access denied"})
		case errors.Is(err, repository.ErrUserNotFound):
			c.JSON(http.StatusNotFound, gin.H{"error": "user not found"})
		default:
			c.JSON(http.StatusInternalServerError, gin.H{"error": "invite member failed"})
		}
		return
	}
	c.JSON(http.StatusCreated, gin.H{"members": members})
}

func (h *ServerHandler) CreateInviteLink(c *gin.Context) {
	userID, ok := authUserID(c)
	if !ok {
		return
	}

	serverID, err := parseInt64Param(c, "serverId")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid server id"})
		return
	}

	var req createInviteLinkRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	invite, err := h.app.ServerService.CreateInviteLink(c.Request.Context(), service.CreateInviteLinkInput{
		ActorUserID: userID,
		ServerID:    serverID,
		Role:        req.Role,
		MaxUses:     req.MaxUses,
	})
	if err != nil {
		switch {
		case errors.Is(err, service.ErrInvalidRole):
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		case errors.Is(err, service.ErrPermissionDenied):
			c.JSON(http.StatusForbidden, gin.H{"error": "missing create invite link permission"})
		case errors.Is(err, repository.ErrNotMember):
			c.JSON(http.StatusForbidden, gin.H{"error": "server access denied"})
		default:
			c.JSON(http.StatusInternalServerError, gin.H{"error": "create invite link failed"})
		}
		return
	}
	c.JSON(http.StatusCreated, gin.H{"invite": invite})
}

func (h *ServerHandler) PreviewInvite(c *gin.Context) {
	code := c.Param("code")
	preview, err := h.app.ServerService.PreviewInvite(c.Request.Context(), service.InvitePreviewInput{
		Code: code,
	})
	if err != nil {
		switch {
		case errors.Is(err, service.ErrInvalidInviteCode):
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		case errors.Is(err, repository.ErrInviteNotFound):
			c.JSON(http.StatusNotFound, gin.H{"error": "invite not found"})
		default:
			c.JSON(http.StatusInternalServerError, gin.H{"error": "preview invite failed"})
		}
		return
	}
	c.JSON(http.StatusOK, gin.H{"invite": preview})
}

func (h *ServerHandler) JoinByInviteCode(c *gin.Context) {
	userID, ok := authUserID(c)
	if !ok {
		return
	}

	var req joinServerByInviteRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	server, channels, err := h.app.ServerService.JoinServerByInvite(c.Request.Context(), service.JoinServerByInviteInput{
		UserID: userID,
		Code:   req.Code,
	})
	if err != nil {
		switch {
		case errors.Is(err, service.ErrInvalidInviteCode):
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		case errors.Is(err, service.ErrInviteExpired):
			c.JSON(http.StatusGone, gin.H{"error": err.Error()})
		case errors.Is(err, repository.ErrInviteNotFound):
			c.JSON(http.StatusNotFound, gin.H{"error": "invite not found"})
		default:
			c.JSON(http.StatusInternalServerError, gin.H{"error": "join by invite failed"})
		}
		return
	}
	c.JSON(http.StatusOK, gin.H{"server": server, "channels": channels})
}

func (h *ServerHandler) UpdateMemberRole(c *gin.Context) {
	userID, ok := authUserID(c)
	if !ok {
		return
	}

	serverID, err := parseInt64Param(c, "serverId")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid server id"})
		return
	}
	memberID, err := parseInt64Param(c, "memberId")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid member id"})
		return
	}

	var req updateMemberRoleRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	members, err := h.app.ServerService.UpdateMemberRole(c.Request.Context(), service.UpdateMemberRoleInput{
		ActorUserID: userID,
		ServerID:    serverID,
		MemberID:    memberID,
		Role:        req.Role,
	})
	if err != nil {
		switch {
		case errors.Is(err, service.ErrInvalidRole):
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		case errors.Is(err, service.ErrPermissionDenied):
			c.JSON(http.StatusForbidden, gin.H{"error": "missing manage member role permission"})
		case errors.Is(err, repository.ErrNotMember):
			c.JSON(http.StatusForbidden, gin.H{"error": "server access denied"})
		default:
			c.JSON(http.StatusInternalServerError, gin.H{"error": "update member role failed"})
		}
		return
	}
	c.JSON(http.StatusOK, gin.H{"members": members})
}

func (h *ServerHandler) JoinVoiceChannel(c *gin.Context) {
	userID, ok := authUserID(c)
	if !ok {
		return
	}

	channelID, err := parseInt64Param(c, "channelId")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid channel id"})
		return
	}

	session, err := h.app.ServerService.JoinVoiceChannel(c.Request.Context(), userID, channelID)
	if err != nil {
		switch {
		case errors.Is(err, service.ErrInvalidVoiceChannel):
			c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		case errors.Is(err, service.ErrLiveKitNotConfigured):
			c.JSON(http.StatusServiceUnavailable, gin.H{"error": err.Error()})
		case errors.Is(err, repository.ErrNotMember):
			c.JSON(http.StatusForbidden, gin.H{"error": "channel access denied"})
		case errors.Is(err, repository.ErrChannelNotFound):
			c.JSON(http.StatusNotFound, gin.H{"error": "channel not found"})
		default:
			c.JSON(http.StatusInternalServerError, gin.H{"error": "join voice channel failed"})
		}
		return
	}
	c.JSON(http.StatusOK, gin.H{"session": session})
}

func (h *ServerHandler) LeaveServer(c *gin.Context) {
	userID, ok := authUserID(c)
	if !ok {
		return
	}

	serverID, err := parseInt64Param(c, "serverId")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid server id"})
		return
	}

	if err := h.app.ServerService.LeaveServer(c.Request.Context(), userID, serverID); err != nil {
		switch {
		case errors.Is(err, service.ErrOwnerMustTransfer):
			c.JSON(http.StatusConflict, gin.H{"error": err.Error()})
		case errors.Is(err, repository.ErrNotMember):
			c.JSON(http.StatusForbidden, gin.H{"error": "server access denied"})
		default:
			c.JSON(http.StatusInternalServerError, gin.H{"error": "leave server failed"})
		}
		return
	}
	c.JSON(http.StatusOK, gin.H{"status": "left"})
}

func (h *ServerHandler) RemoveMember(c *gin.Context) {
	userID, ok := authUserID(c)
	if !ok {
		return
	}

	serverID, err := parseInt64Param(c, "serverId")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid server id"})
		return
	}
	memberID, err := parseInt64Param(c, "memberId")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid member id"})
		return
	}

	members, err := h.app.ServerService.RemoveMember(c.Request.Context(), service.RemoveMemberInput{
		ActorUserID: userID,
		ServerID:    serverID,
		MemberID:    memberID,
	})
	if err != nil {
		switch {
		case errors.Is(err, service.ErrPermissionDenied):
			c.JSON(http.StatusForbidden, gin.H{"error": "missing remove member permission"})
		case errors.Is(err, repository.ErrNotMember):
			c.JSON(http.StatusForbidden, gin.H{"error": "server access denied"})
		default:
			c.JSON(http.StatusInternalServerError, gin.H{"error": "remove member failed"})
		}
		return
	}
	c.JSON(http.StatusOK, gin.H{"members": members})
}

func (h *ServerHandler) TransferOwnership(c *gin.Context) {
	userID, ok := authUserID(c)
	if !ok {
		return
	}

	serverID, err := parseInt64Param(c, "serverId")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "invalid server id"})
		return
	}

	var req transferOwnershipRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	members, err := h.app.ServerService.TransferOwnership(c.Request.Context(), service.TransferOwnershipInput{
		ActorUserID:     userID,
		ServerID:        serverID,
		NextOwnerUserID: req.NextOwnerUserID,
	})
	if err != nil {
		switch {
		case errors.Is(err, service.ErrPermissionDenied):
			c.JSON(http.StatusForbidden, gin.H{"error": "missing transfer owner permission"})
		case errors.Is(err, repository.ErrNotMember):
			c.JSON(http.StatusForbidden, gin.H{"error": "server access denied"})
		default:
			c.JSON(http.StatusInternalServerError, gin.H{"error": "transfer ownership failed"})
		}
		return
	}
	c.JSON(http.StatusOK, gin.H{"members": members})
}

func authUserID(c *gin.Context) (int64, bool) {
	userIDValue, exists := c.Get("auth.user_id")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "missing auth context"})
		return 0, false
	}
	userID, ok := userIDValue.(int64)
	if !ok {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "invalid auth context"})
		return 0, false
	}
	return userID, true
}

func parseInt64Param(c *gin.Context, key string) (int64, error) {
	return strconv.ParseInt(c.Param(key), 10, 64)
}

func messagePayload(message *model.Message) map[string]any {
	return map[string]any{
		"id":                  message.ID,
		"channel_id":          message.ChannelID,
		"sender_id":           message.SenderID,
		"sender_display_name": message.SenderDisplayName,
		"content":             message.Content,
		"created_at":          message.CreatedAt,
		"updated_at":          message.UpdatedAt,
	}
}
