package service

import (
	"context"
	"errors"
	"strings"

	"github.com/nocrya/sardine/internal/model"
	"github.com/nocrya/sardine/internal/repository"
)

var (
	ErrInvalidDirectPeer    = errors.New("peer user id is required")
	ErrInvalidDirectMessage = errors.New("direct message content is required")
)

type DirectMessageService struct {
	directMessages *repository.DirectMessageRepository
	users          *repository.UserRepository
}

func NewDirectMessageService(directMessages *repository.DirectMessageRepository, users *repository.UserRepository) *DirectMessageService {
	return &DirectMessageService{
		directMessages: directMessages,
		users:          users,
	}
}

func (s *DirectMessageService) ListConversations(ctx context.Context, userID int64) ([]model.DirectConversation, error) {
	return s.directMessages.ListConversations(ctx, userID)
}

func (s *DirectMessageService) CreateOrFindConversation(ctx context.Context, userID, peerUserID int64) (int64, error) {
	if peerUserID <= 0 || peerUserID == userID {
		return 0, ErrInvalidDirectPeer
	}
	if _, err := s.users.FindByID(ctx, peerUserID); err != nil {
		return 0, err
	}
	return s.directMessages.FindOrCreateConversation(ctx, userID, peerUserID)
}

func (s *DirectMessageService) ListMessages(ctx context.Context, userID, conversationID int64, limit int) ([]model.DirectMessage, error) {
	return s.directMessages.ListMessages(ctx, userID, conversationID, limit)
}

func (s *DirectMessageService) CreateMessage(ctx context.Context, userID, conversationID int64, content string) (*model.DirectMessage, error) {
	trimmed := strings.TrimSpace(content)
	if trimmed == "" {
		return nil, ErrInvalidDirectMessage
	}
	return s.directMessages.CreateMessage(ctx, userID, conversationID, trimmed)
}

func (s *DirectMessageService) CanAccessConversation(ctx context.Context, userID, conversationID int64) error {
	return s.directMessages.EnsureConversationAccess(ctx, userID, conversationID)
}

func (s *DirectMessageService) MarkRead(ctx context.Context, userID, conversationID, messageID int64) (*model.DirectReadState, error) {
	if messageID <= 0 {
		return nil, ErrInvalidDirectMessage
	}
	return s.directMessages.MarkRead(ctx, userID, conversationID, messageID)
}

func (s *DirectMessageService) ListReadStates(ctx context.Context, userID, conversationID int64) ([]model.DirectReadState, error) {
	return s.directMessages.ListReadStates(ctx, userID, conversationID)
}
