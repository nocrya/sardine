package repository

import (
	"context"
	"database/sql"
	"errors"

	"github.com/nocrya/sardine/internal/model"
)

var ErrDirectConversationNotFound = errors.New("direct conversation not found")

type DirectMessageRepository struct {
	db *sql.DB
}

func NewDirectMessageRepository(db *sql.DB) *DirectMessageRepository {
	return &DirectMessageRepository{db: db}
}

func (r *DirectMessageRepository) BeginTx(ctx context.Context) (*sql.Tx, error) {
	if r.db == nil {
		return nil, errors.New("postgres is not configured")
	}
	return r.db.BeginTx(ctx, nil)
}

func (r *DirectMessageRepository) FindOrCreateConversation(ctx context.Context, userID, peerUserID int64) (int64, error) {
	if r.db == nil {
		return 0, errors.New("postgres is not configured")
	}

	const query = `
SELECT dcm1.conversation_id
FROM direct_conversation_members dcm1
INNER JOIN direct_conversation_members dcm2
  ON dcm2.conversation_id = dcm1.conversation_id
WHERE dcm1.user_id = $1 AND dcm2.user_id = $2
LIMIT 1;
`
	var conversationID int64
	err := r.db.QueryRowContext(ctx, query, userID, peerUserID).Scan(&conversationID)
	if err == nil {
		return conversationID, nil
	}
	if !errors.Is(err, sql.ErrNoRows) {
		return 0, err
	}

	tx, err := r.db.BeginTx(ctx, nil)
	if err != nil {
		return 0, err
	}
	defer tx.Rollback()

	if err := tx.QueryRowContext(
		ctx,
		`INSERT INTO direct_conversations DEFAULT VALUES RETURNING id;`,
	).Scan(&conversationID); err != nil {
		return 0, err
	}
	if _, err := tx.ExecContext(
		ctx,
		`INSERT INTO direct_conversation_members (conversation_id, user_id) VALUES ($1, $2), ($1, $3);`,
		conversationID,
		userID,
		peerUserID,
	); err != nil {
		return 0, err
	}
	if err := tx.Commit(); err != nil {
		return 0, err
	}
	return conversationID, nil
}

func (r *DirectMessageRepository) EnsureConversationAccess(ctx context.Context, userID, conversationID int64) error {
	if r.db == nil {
		return errors.New("postgres is not configured")
	}

	const query = `
SELECT 1
FROM direct_conversation_members
WHERE conversation_id = $1 AND user_id = $2
LIMIT 1;
`
	var exists int
	if err := r.db.QueryRowContext(ctx, query, conversationID, userID).Scan(&exists); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return ErrDirectConversationNotFound
		}
		return err
	}
	return nil
}

func (r *DirectMessageRepository) ListConversations(ctx context.Context, userID int64) ([]model.DirectConversation, error) {
	if r.db == nil {
		return nil, errors.New("postgres is not configured")
	}

	const query = `
SELECT dc.id,
       peer.user_id,
       u.display_name,
       COALESCE(dm.content, ''),
       COALESCE(dm.created_at, dc.created_at),
       COALESCE(peer.last_read_message_id, 0),
       COALESCE(peer.last_read_at, dc.created_at),
       COALESCE((
           SELECT COUNT(*)
           FROM direct_messages unread
           WHERE unread.conversation_id = dc.id
             AND unread.sender_id <> mine.user_id
             AND unread.id > COALESCE(mine.last_read_message_id, 0)
       ), 0)
FROM direct_conversation_members mine
INNER JOIN direct_conversations dc ON dc.id = mine.conversation_id
INNER JOIN direct_conversation_members peer ON peer.conversation_id = dc.id AND peer.user_id <> mine.user_id
INNER JOIN users u ON u.id = peer.user_id
LEFT JOIN LATERAL (
    SELECT content, created_at
    FROM direct_messages
    WHERE conversation_id = dc.id
    ORDER BY created_at DESC
    LIMIT 1
) dm ON TRUE
WHERE mine.user_id = $1
ORDER BY COALESCE(dm.created_at, dc.created_at) DESC;
`
	rows, err := r.db.QueryContext(ctx, query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var conversations []model.DirectConversation
	for rows.Next() {
		var item model.DirectConversation
		if err := rows.Scan(
			&item.ID,
			&item.PeerUserID,
			&item.PeerName,
			&item.LastMessage,
			&item.LastMessageAt,
			&item.PeerLastReadMessageID,
			&item.PeerLastReadAt,
			&item.UnreadCount,
		); err != nil {
			return nil, err
		}
		conversations = append(conversations, item)
	}
	return conversations, rows.Err()
}

func (r *DirectMessageRepository) ListMessages(ctx context.Context, userID, conversationID int64, limit int) ([]model.DirectMessage, error) {
	if err := r.EnsureConversationAccess(ctx, userID, conversationID); err != nil {
		return nil, err
	}
	if limit <= 0 || limit > 100 {
		limit = 50
	}

	const query = `
SELECT dm.id, dm.conversation_id, dm.sender_id, u.display_name, dm.content, dm.created_at, dm.updated_at
FROM direct_messages dm
INNER JOIN users u ON u.id = dm.sender_id
WHERE dm.conversation_id = $1
ORDER BY dm.created_at DESC
LIMIT $2;
`
	rows, err := r.db.QueryContext(ctx, query, conversationID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var messages []model.DirectMessage
	for rows.Next() {
		var message model.DirectMessage
		if err := rows.Scan(
			&message.ID,
			&message.ConversationID,
			&message.SenderID,
			&message.SenderDisplayName,
			&message.Content,
			&message.CreatedAt,
			&message.UpdatedAt,
		); err != nil {
			return nil, err
		}
		messages = append([]model.DirectMessage{message}, messages...)
	}
	return messages, rows.Err()
}

func (r *DirectMessageRepository) CreateMessage(ctx context.Context, userID, conversationID int64, content string) (*model.DirectMessage, error) {
	if err := r.EnsureConversationAccess(ctx, userID, conversationID); err != nil {
		return nil, err
	}

	message := &model.DirectMessage{}
	if err := r.db.QueryRowContext(
		ctx,
		`INSERT INTO direct_messages (conversation_id, sender_id, content) VALUES ($1, $2, $3) RETURNING id, created_at, updated_at;`,
		conversationID,
		userID,
		content,
	).Scan(&message.ID, &message.CreatedAt, &message.UpdatedAt); err != nil {
		return nil, err
	}
	message.ConversationID = conversationID
	message.SenderID = userID
	message.Content = content
	if err := r.db.QueryRowContext(ctx, `SELECT display_name FROM users WHERE id = $1;`, userID).Scan(&message.SenderDisplayName); err != nil {
		return nil, err
	}
	return message, nil
}

func (r *DirectMessageRepository) MarkRead(ctx context.Context, userID, conversationID, messageID int64) (*model.DirectReadState, error) {
	if err := r.EnsureConversationAccess(ctx, userID, conversationID); err != nil {
		return nil, err
	}

	state := &model.DirectReadState{}
	if err := r.db.QueryRowContext(
		ctx,
		`
UPDATE direct_conversation_members
SET last_read_message_id = GREATEST(last_read_message_id, $3),
    last_read_at = NOW()
WHERE conversation_id = $1 AND user_id = $2
RETURNING user_id, last_read_message_id, last_read_at;
`,
		conversationID,
		userID,
		messageID,
	).Scan(&state.UserID, &state.LastReadMessageID, &state.LastReadAt); err != nil {
		return nil, err
	}
	return state, nil
}

func (r *DirectMessageRepository) ListReadStates(ctx context.Context, userID, conversationID int64) ([]model.DirectReadState, error) {
	if err := r.EnsureConversationAccess(ctx, userID, conversationID); err != nil {
		return nil, err
	}

	rows, err := r.db.QueryContext(
		ctx,
		`
SELECT user_id, last_read_message_id, last_read_at
FROM direct_conversation_members
WHERE conversation_id = $1
ORDER BY user_id ASC;
`,
		conversationID,
	)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var states []model.DirectReadState
	for rows.Next() {
		var state model.DirectReadState
		if err := rows.Scan(&state.UserID, &state.LastReadMessageID, &state.LastReadAt); err != nil {
			return nil, err
		}
		states = append(states, state)
	}
	return states, rows.Err()
}
