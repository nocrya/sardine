package service

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/nocrya/sardine/internal/config"
	"github.com/nocrya/sardine/internal/model"
	"github.com/nocrya/sardine/internal/repository"
)

var (
	ErrInvalidServerName      = errors.New("server name is required")
	ErrInvalidChannelName     = errors.New("channel name is required")
	ErrInvalidMessage         = errors.New("message content is required")
	ErrInvalidInviteEmail     = errors.New("invite email is required")
	ErrInvalidInviteCode      = errors.New("invite code is required")
	ErrInvalidRole            = errors.New("invalid role")
	ErrInvalidVoiceChannel    = errors.New("channel is not a voice channel")
	ErrOwnerMustTransfer      = errors.New("owner must transfer ownership before leaving")
	ErrInviteExpired          = errors.New("invite link is expired")
	ErrLiveKitNotConfigured   = errors.New("livekit is not configured")
	ErrUnsupportedChannelKind = errors.New("unsupported channel kind")
	ErrPermissionDenied       = errors.New("permission denied")
)

type ServerService struct {
	servers *repository.ServerRepository
	users   *repository.UserRepository
	liveKit config.LiveKitConfig
}

type CreateServerInput struct {
	OwnerID     int64
	Name        string
	Description string
}

type CreateChannelInput struct {
	UserID   int64
	ServerID int64
	Name     string
	Kind     string
	Topic    string
}

type CreateMessageInput struct {
	UserID    int64
	ChannelID int64
	Content   string
}

type MessagePage struct {
	Messages     []model.Message
	HasMore      bool
	NextBeforeID int64
}

type InviteMemberInput struct {
	ActorUserID int64
	ServerID    int64
	Email       string
	Role        string
}

type CreateInviteLinkInput struct {
	ActorUserID int64
	ServerID    int64
	Role        string
	MaxUses     int64
}

type UpdateMemberRoleInput struct {
	ActorUserID int64
	ServerID    int64
	MemberID    int64
	Role        string
}

type RemoveMemberInput struct {
	ActorUserID int64
	ServerID    int64
	MemberID    int64
}

type TransferOwnershipInput struct {
	ActorUserID     int64
	ServerID        int64
	NextOwnerUserID int64
}

type JoinServerByInviteInput struct {
	UserID int64
	Code   string
}

func NewServerService(
	servers *repository.ServerRepository,
	users *repository.UserRepository,
	liveKit config.LiveKitConfig,
) *ServerService {
	return &ServerService{
		servers: servers,
		users:   users,
		liveKit: liveKit,
	}
}

func (s *ServerService) CreateServer(ctx context.Context, input CreateServerInput) (*model.Server, []model.Channel, error) {
	name := strings.TrimSpace(input.Name)
	if name == "" {
		return nil, nil, ErrInvalidServerName
	}

	tx, err := s.servers.BeginTx(ctx)
	if err != nil {
		return nil, nil, err
	}
	defer tx.Rollback()

	server := &model.Server{
		Name:        name,
		Description: strings.TrimSpace(input.Description),
		OwnerID:     input.OwnerID,
	}
	if err := s.servers.CreateServer(ctx, tx, server); err != nil {
		return nil, nil, err
	}
	if err := s.servers.AddMember(ctx, tx, server.ID, input.OwnerID, "owner"); err != nil {
		return nil, nil, err
	}

	defaultChannels := []model.Channel{
		{ServerID: server.ID, Name: "general", Kind: "text", Topic: "General discussion"},
		{ServerID: server.ID, Name: "lobby", Kind: "voice", Topic: "Voice lobby"},
	}
	for i := range defaultChannels {
		if err := s.servers.CreateChannel(ctx, tx, &defaultChannels[i]); err != nil {
			return nil, nil, err
		}
	}

	if err := tx.Commit(); err != nil {
		return nil, nil, err
	}
	return server, defaultChannels, nil
}

func (s *ServerService) ListServers(ctx context.Context, userID int64) ([]model.Server, error) {
	return s.servers.ListServersByUserID(ctx, userID)
}

func (s *ServerService) ListChannels(ctx context.Context, userID, serverID int64) ([]model.Channel, error) {
	return s.servers.ListChannelsByServerID(ctx, userID, serverID)
}

func (s *ServerService) CreateChannel(ctx context.Context, input CreateChannelInput) (*model.Channel, error) {
	name := strings.TrimSpace(input.Name)
	if name == "" {
		return nil, ErrInvalidChannelName
	}

	kind := strings.TrimSpace(input.Kind)
	if kind == "" {
		kind = "text"
	}
	if kind != "text" && kind != "voice" {
		return nil, ErrUnsupportedChannelKind
	}

	role, err := s.servers.GetMemberRole(ctx, input.UserID, input.ServerID)
	if err != nil {
		return nil, err
	}
	if role != "owner" && role != "admin" {
		return nil, ErrPermissionDenied
	}

	if _, err := s.servers.ListChannelsByServerID(ctx, input.UserID, input.ServerID); err != nil {
		return nil, err
	}

	tx, err := s.servers.BeginTx(ctx)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback()

	channel := &model.Channel{
		ServerID: input.ServerID,
		Name:     name,
		Kind:     kind,
		Topic:    strings.TrimSpace(input.Topic),
	}
	if err := s.servers.CreateChannel(ctx, tx, channel); err != nil {
		return nil, err
	}
	if err := tx.Commit(); err != nil {
		return nil, err
	}
	return channel, nil
}

func (s *ServerService) ListMessages(ctx context.Context, userID, channelID int64, limit int, beforeID int64) (*MessagePage, error) {
	page, err := s.servers.ListMessagesByChannelID(ctx, userID, channelID, limit, beforeID)
	if err != nil {
		return nil, err
	}
	return &MessagePage{
		Messages:     page.Messages,
		HasMore:      page.HasMore,
		NextBeforeID: page.NextBeforeID,
	}, nil
}

func (s *ServerService) CreateMessage(ctx context.Context, input CreateMessageInput) (*model.Message, error) {
	content := strings.TrimSpace(input.Content)
	if content == "" {
		return nil, ErrInvalidMessage
	}

	message := &model.Message{
		ChannelID: input.ChannelID,
		SenderID:  input.UserID,
		Content:   content,
	}
	if err := s.servers.CreateMessage(ctx, input.UserID, message); err != nil {
		return nil, err
	}
	return message, nil
}

func (s *ServerService) MarkChannelRead(ctx context.Context, userID, channelID, messageID int64) error {
	if messageID <= 0 {
		return ErrInvalidMessage
	}
	return s.servers.MarkChannelRead(ctx, userID, channelID, messageID)
}

func (s *ServerService) CanAccessChannel(ctx context.Context, userID, channelID int64) error {
	return s.servers.EnsureChannelAccess(ctx, userID, channelID)
}

func (s *ServerService) CanAccessServer(ctx context.Context, userID, serverID int64) error {
	return s.servers.EnsureServerAccess(ctx, userID, serverID)
}

func (s *ServerService) ResolveServerIDByChannel(ctx context.Context, channelID int64) (int64, error) {
	return s.servers.LookupServerIDByChannel(ctx, channelID)
}

func (s *ServerService) JoinVoiceChannel(ctx context.Context, userID, channelID int64) (*model.VoiceJoinSession, error) {
	if strings.TrimSpace(s.liveKit.URL) == "" ||
		strings.TrimSpace(s.liveKit.APIKey) == "" ||
		strings.TrimSpace(s.liveKit.APISecret) == "" {
		return nil, ErrLiveKitNotConfigured
	}

	channel, err := s.servers.FindChannelByID(ctx, channelID)
	if err != nil {
		return nil, err
	}
	if err := s.servers.EnsureChannelAccess(ctx, userID, channelID); err != nil {
		return nil, err
	}
	if channel.Kind != "voice" {
		return nil, ErrInvalidVoiceChannel
	}

	user, err := s.users.FindByID(ctx, userID)
	if err != nil {
		return nil, err
	}

	roomName := voiceRoomName(channel)
	identity := voiceParticipantIdentity(user.ID)
	now := time.Now().UTC()
	expiresAt := now.Add(s.liveKit.TokenTTL)
	if s.liveKit.TokenTTL <= 0 {
		expiresAt = now.Add(time.Hour)
	}

	claims := jwt.MapClaims{
		"iss":  s.liveKit.APIKey,
		"sub":  identity,
		"nbf":  now.Unix(),
		"exp":  expiresAt.Unix(),
		"name": user.DisplayName,
		"video": map[string]any{
			"room":           roomName,
			"roomJoin":       true,
			"canPublish":     true,
			"canSubscribe":   true,
			"canPublishData": true,
		},
	}

	token := jwt.NewWithClaims(jwt.SigningMethodHS256, claims)
	signed, err := token.SignedString([]byte(s.liveKit.APISecret))
	if err != nil {
		return nil, err
	}

	return &model.VoiceJoinSession{
		ChannelID:           channel.ID,
		RoomName:            roomName,
		ServerURL:           s.liveKit.URL,
		AccessToken:         signed,
		ParticipantIdentity: identity,
		ParticipantName:     user.DisplayName,
	}, nil
}

func (s *ServerService) ListMembers(ctx context.Context, userID, serverID int64) ([]model.ServerMember, error) {
	return s.servers.ListMembersByServerID(ctx, userID, serverID)
}

func (s *ServerService) InviteMember(ctx context.Context, input InviteMemberInput) ([]model.ServerMember, error) {
	email := strings.TrimSpace(input.Email)
	if email == "" {
		return nil, ErrInvalidInviteEmail
	}

	role, err := normalizeServerRole(input.Role)
	if err != nil {
		return nil, err
	}
	if role == "owner" {
		return nil, ErrPermissionDenied
	}

	actorRole, err := s.servers.GetMemberRole(ctx, input.ActorUserID, input.ServerID)
	if err != nil {
		return nil, err
	}
	if actorRole != "owner" && actorRole != "admin" {
		return nil, ErrPermissionDenied
	}
	if actorRole != "owner" && role != "member" {
		return nil, ErrPermissionDenied
	}

	user, err := s.users.FindByEmail(ctx, email)
	if err != nil {
		return nil, err
	}

	tx, err := s.servers.BeginTx(ctx)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback()

	if err := s.servers.AddMember(ctx, tx, input.ServerID, user.ID, role); err != nil {
		return nil, err
	}
	if err := tx.Commit(); err != nil {
		return nil, err
	}
	return s.servers.ListMembersByServerID(ctx, input.ActorUserID, input.ServerID)
}

func (s *ServerService) CreateInviteLink(ctx context.Context, input CreateInviteLinkInput) (*model.ServerInvite, error) {
	role, err := normalizeServerRole(input.Role)
	if err != nil {
		return nil, err
	}
	if role == "owner" {
		return nil, ErrPermissionDenied
	}

	actorRole, err := s.servers.GetMemberRole(ctx, input.ActorUserID, input.ServerID)
	if err != nil {
		return nil, err
	}
	if actorRole != "owner" && actorRole != "admin" {
		return nil, ErrPermissionDenied
	}
	if actorRole != "owner" && role != "member" {
		return nil, ErrPermissionDenied
	}

	code, err := repository.NewInviteCode()
	if err != nil {
		return nil, err
	}

	invite := &model.ServerInvite{
		Code:      code,
		ServerID:  input.ServerID,
		CreatedBy: input.ActorUserID,
		Role:      role,
		MaxUses:   input.MaxUses,
	}

	tx, err := s.servers.BeginTx(ctx)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback()

	if err := s.servers.CreateInvite(ctx, tx, invite); err != nil {
		return nil, err
	}
	if err := tx.Commit(); err != nil {
		return nil, err
	}

	invite.InviteLink = "/invite/" + invite.Code
	return invite, nil
}

func (s *ServerService) JoinServerByInvite(ctx context.Context, input JoinServerByInviteInput) (*model.Server, []model.Channel, error) {
	code := strings.ToUpper(strings.TrimSpace(input.Code))
	if code == "" {
		return nil, nil, ErrInvalidInviteCode
	}

	invite, err := s.servers.FindInviteByCode(ctx, code)
	if err != nil {
		return nil, nil, err
	}
	if repository.InviteExpired(invite, time.Now().UTC()) {
		return nil, nil, ErrInviteExpired
	}

	tx, err := s.servers.BeginTx(ctx)
	if err != nil {
		return nil, nil, err
	}
	defer tx.Rollback()

	if err := s.servers.AddMember(ctx, tx, invite.ServerID, input.UserID, invite.Role); err != nil {
		return nil, nil, err
	}
	if err := s.servers.ConsumeInvite(ctx, tx, invite.Code); err != nil {
		return nil, nil, err
	}
	if err := tx.Commit(); err != nil {
		return nil, nil, err
	}

	servers, err := s.servers.ListServersByUserID(ctx, input.UserID)
	if err != nil {
		return nil, nil, err
	}
	var joined *model.Server
	for i := range servers {
		if servers[i].ID == invite.ServerID {
			serverCopy := servers[i]
			joined = &serverCopy
			break
		}
	}
	if joined == nil {
		return nil, nil, repository.ErrServerNotFound
	}
	channels, err := s.servers.ListChannelsByServerID(ctx, input.UserID, joined.ID)
	if err != nil {
		return nil, nil, err
	}
	return joined, channels, nil
}

func (s *ServerService) UpdateMemberRole(ctx context.Context, input UpdateMemberRoleInput) ([]model.ServerMember, error) {
	role, err := normalizeServerRole(input.Role)
	if err != nil {
		return nil, err
	}
	if role == "owner" {
		return nil, ErrPermissionDenied
	}

	actorRole, err := s.servers.GetMemberRole(ctx, input.ActorUserID, input.ServerID)
	if err != nil {
		return nil, err
	}
	if actorRole != "owner" {
		return nil, ErrPermissionDenied
	}
	if input.MemberID == input.ActorUserID {
		return nil, ErrPermissionDenied
	}

	memberRole, err := s.servers.GetMemberRole(ctx, input.MemberID, input.ServerID)
	if err != nil {
		return nil, err
	}
	if memberRole == "owner" {
		return nil, ErrPermissionDenied
	}

	if err := s.servers.UpdateMemberRole(ctx, input.ServerID, input.MemberID, role); err != nil {
		return nil, err
	}
	return s.servers.ListMembersByServerID(ctx, input.ActorUserID, input.ServerID)
}

func (s *ServerService) LeaveServer(ctx context.Context, userID, serverID int64) error {
	role, err := s.servers.GetMemberRole(ctx, userID, serverID)
	if err != nil {
		return err
	}
	if role == "owner" {
		return ErrOwnerMustTransfer
	}
	return s.servers.RemoveMember(ctx, serverID, userID)
}

func (s *ServerService) RemoveMember(ctx context.Context, input RemoveMemberInput) ([]model.ServerMember, error) {
	actorRole, err := s.servers.GetMemberRole(ctx, input.ActorUserID, input.ServerID)
	if err != nil {
		return nil, err
	}
	if actorRole != "owner" {
		return nil, ErrPermissionDenied
	}
	if input.MemberID == input.ActorUserID {
		return nil, ErrPermissionDenied
	}

	memberRole, err := s.servers.GetMemberRole(ctx, input.MemberID, input.ServerID)
	if err != nil {
		return nil, err
	}
	if memberRole == "owner" {
		return nil, ErrPermissionDenied
	}

	if err := s.servers.RemoveMember(ctx, input.ServerID, input.MemberID); err != nil {
		return nil, err
	}
	return s.servers.ListMembersByServerID(ctx, input.ActorUserID, input.ServerID)
}

func (s *ServerService) TransferOwnership(ctx context.Context, input TransferOwnershipInput) ([]model.ServerMember, error) {
	actorRole, err := s.servers.GetMemberRole(ctx, input.ActorUserID, input.ServerID)
	if err != nil {
		return nil, err
	}
	if actorRole != "owner" {
		return nil, ErrPermissionDenied
	}
	if input.NextOwnerUserID == input.ActorUserID {
		return nil, ErrPermissionDenied
	}

	nextOwnerRole, err := s.servers.GetMemberRole(ctx, input.NextOwnerUserID, input.ServerID)
	if err != nil {
		return nil, err
	}
	if nextOwnerRole == "owner" {
		return nil, ErrPermissionDenied
	}

	tx, err := s.servers.BeginTx(ctx)
	if err != nil {
		return nil, err
	}
	defer tx.Rollback()

	if err := s.servers.TransferOwnership(ctx, tx, input.ServerID, input.NextOwnerUserID); err != nil {
		return nil, err
	}
	if err := tx.Commit(); err != nil {
		return nil, err
	}
	return s.servers.ListMembersByServerID(ctx, input.ActorUserID, input.ServerID)
}

func normalizeServerRole(raw string) (string, error) {
	role := strings.ToLower(strings.TrimSpace(raw))
	if role == "" {
		role = "member"
	}
	switch role {
	case "owner", "admin", "member":
		return role, nil
	default:
		return "", ErrInvalidRole
	}
}

func voiceRoomName(channel *model.Channel) string {
	return fmt.Sprintf("sardine-voice-channel-%d", channel.ID)
}

func voiceParticipantIdentity(userID int64) string {
	return fmt.Sprintf("user-%d", userID)
}
