package repository

import (
	"context"
	"crypto/rand"
	"database/sql"
	"encoding/base32"
	"errors"
	"strings"
	"time"

	"github.com/nocrya/sardine/internal/model"
)

var (
	ErrServerNotFound  = errors.New("server not found")
	ErrChannelNotFound = errors.New("channel not found")
	ErrNotMember       = errors.New("user is not a server member")
	ErrInviteNotFound  = errors.New("server invite not found")
)

type sqlRunner interface {
	ExecContext(ctx context.Context, query string, args ...any) (sql.Result, error)
	QueryContext(ctx context.Context, query string, args ...any) (*sql.Rows, error)
	QueryRowContext(ctx context.Context, query string, args ...any) *sql.Row
}

type ServerRepository struct {
	db *sql.DB
}

type MessagePage struct {
	Messages     []model.Message
	HasMore      bool
	NextBeforeID int64
}

func NewServerRepository(db *sql.DB) *ServerRepository {
	return &ServerRepository{db: db}
}

func (r *ServerRepository) BeginTx(ctx context.Context) (*sql.Tx, error) {
	if r.db == nil {
		return nil, errors.New("postgres is not configured")
	}
	return r.db.BeginTx(ctx, nil)
}

func (r *ServerRepository) CreateServer(ctx context.Context, runner sqlRunner, server *model.Server) error {
	const query = `
INSERT INTO servers (name, description, owner_id)
VALUES ($1, $2, $3)
RETURNING id, created_at, updated_at;
`
	return runner.QueryRowContext(ctx, query, server.Name, server.Description, server.OwnerID).
		Scan(&server.ID, &server.CreatedAt, &server.UpdatedAt)
}

func (r *ServerRepository) AddMember(ctx context.Context, runner sqlRunner, serverID, userID int64, role string) error {
	const query = `
INSERT INTO server_members (server_id, user_id, role)
VALUES ($1, $2, $3)
ON CONFLICT (server_id, user_id) DO NOTHING;
`
	_, err := runner.ExecContext(ctx, query, serverID, userID, role)
	return err
}

func (r *ServerRepository) CreateInvite(ctx context.Context, tx *sql.Tx, invite *model.ServerInvite) error {
	const query = `
INSERT INTO server_invites (code, server_id, created_by, role, max_uses, expires_at)
VALUES ($1, $2, $3, $4, $5, $6)
RETURNING use_count, created_at;
`
	return tx.QueryRowContext(
		ctx,
		query,
		invite.Code,
		invite.ServerID,
		invite.CreatedBy,
		invite.Role,
		invite.MaxUses,
		invite.ExpiresAt,
	).Scan(&invite.UseCount, &invite.CreatedAt)
}

func (r *ServerRepository) UpdateMemberRole(ctx context.Context, serverID, userID int64, role string) error {
	if r.db == nil {
		return errors.New("postgres is not configured")
	}

	const query = `
UPDATE server_members
SET role = $3
WHERE server_id = $1 AND user_id = $2;
`
	result, err := r.db.ExecContext(ctx, query, serverID, userID, role)
	if err != nil {
		return err
	}
	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if rowsAffected == 0 {
		return ErrNotMember
	}
	return nil
}

func (r *ServerRepository) RemoveMember(ctx context.Context, serverID, userID int64) error {
	if r.db == nil {
		return errors.New("postgres is not configured")
	}

	const query = `
DELETE FROM server_members
WHERE server_id = $1 AND user_id = $2;
`
	result, err := r.db.ExecContext(ctx, query, serverID, userID)
	if err != nil {
		return err
	}
	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if rowsAffected == 0 {
		return ErrNotMember
	}
	return nil
}

func (r *ServerRepository) TransferOwnership(ctx context.Context, tx *sql.Tx, serverID, nextOwnerID int64) error {
	const updateServerQuery = `
UPDATE servers
SET owner_id = $2, updated_at = NOW()
WHERE id = $1;
`
	if _, err := tx.ExecContext(ctx, updateServerQuery, serverID, nextOwnerID); err != nil {
		return err
	}

	const demoteOldOwnerQuery = `
UPDATE server_members
SET role = 'admin'
WHERE server_id = $1 AND role = 'owner';
`
	if _, err := tx.ExecContext(ctx, demoteOldOwnerQuery, serverID); err != nil {
		return err
	}

	const promoteNextOwnerQuery = `
UPDATE server_members
SET role = 'owner'
WHERE server_id = $1 AND user_id = $2;
`
	result, err := tx.ExecContext(ctx, promoteNextOwnerQuery, serverID, nextOwnerID)
	if err != nil {
		return err
	}
	rowsAffected, err := result.RowsAffected()
	if err != nil {
		return err
	}
	if rowsAffected == 0 {
		return ErrNotMember
	}
	return nil
}

func (r *ServerRepository) CreateChannel(ctx context.Context, runner sqlRunner, channel *model.Channel) error {
	const query = `
INSERT INTO channels (server_id, name, kind, topic)
VALUES ($1, $2, $3, $4)
RETURNING id, created_at, updated_at;
`
	return runner.QueryRowContext(ctx, query, channel.ServerID, channel.Name, channel.Kind, channel.Topic).
		Scan(&channel.ID, &channel.CreatedAt, &channel.UpdatedAt)
}

func (r *ServerRepository) ListServersByUserID(ctx context.Context, userID int64) ([]model.Server, error) {
	if r.db == nil {
		return nil, errors.New("postgres is not configured")
	}

	const query = `
SELECT s.id, s.name, s.description, s.owner_id, s.created_at, s.updated_at
     , sm.role
     , COALESCE((
         SELECT COUNT(*)
         FROM messages m
         INNER JOIN channels c ON c.id = m.channel_id
         LEFT JOIN channel_reads cr ON cr.channel_id = m.channel_id AND cr.user_id = sm.user_id
         WHERE c.server_id = s.id
           AND m.sender_id <> sm.user_id
           AND m.id > COALESCE(cr.last_read_message_id, 0)
       ), 0) AS unread_count
FROM servers s
INNER JOIN server_members sm ON sm.server_id = s.id
WHERE sm.user_id = $1
ORDER BY s.created_at ASC;
`
	rows, err := r.db.QueryContext(ctx, query, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var servers []model.Server
	for rows.Next() {
		var server model.Server
		if err := rows.Scan(
			&server.ID,
			&server.Name,
			&server.Description,
			&server.OwnerID,
			&server.CreatedAt,
			&server.UpdatedAt,
			&server.MemberRole,
			&server.UnreadCount,
		); err != nil {
			return nil, err
		}
		servers = append(servers, server)
	}
	return servers, rows.Err()
}

func (r *ServerRepository) ListChannelsByServerID(ctx context.Context, userID, serverID int64) ([]model.Channel, error) {
	if err := r.ensureMembership(ctx, userID, serverID); err != nil {
		return nil, err
	}

	const query = `
SELECT id, server_id, name, kind, topic, created_at, updated_at
     , COALESCE((
         SELECT COUNT(*)
         FROM messages m
         LEFT JOIN channel_reads cr ON cr.channel_id = m.channel_id AND cr.user_id = $2
         WHERE m.channel_id = channels.id
           AND m.sender_id <> $2
           AND m.id > COALESCE(cr.last_read_message_id, 0)
       ), 0) AS unread_count
FROM channels
WHERE server_id = $1
ORDER BY created_at ASC;
`
	rows, err := r.db.QueryContext(ctx, query, serverID, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var channels []model.Channel
	for rows.Next() {
		var channel model.Channel
		if err := rows.Scan(
			&channel.ID,
			&channel.ServerID,
			&channel.Name,
			&channel.Kind,
			&channel.Topic,
			&channel.CreatedAt,
			&channel.UpdatedAt,
			&channel.UnreadCount,
		); err != nil {
			return nil, err
		}
		channels = append(channels, channel)
	}
	return channels, rows.Err()
}

func (r *ServerRepository) CreateMessage(ctx context.Context, userID int64, message *model.Message) error {
	if err := r.EnsureChannelAccess(ctx, userID, message.ChannelID); err != nil {
		return err
	}

	const query = `
INSERT INTO messages (channel_id, sender_id, content)
VALUES ($1, $2, $3)
RETURNING id, created_at, updated_at;
`
	if err := r.db.QueryRowContext(ctx, query, message.ChannelID, message.SenderID, message.Content).
		Scan(&message.ID, &message.CreatedAt, &message.UpdatedAt); err != nil {
		return err
	}

	const senderQuery = `SELECT display_name FROM users WHERE id = $1;`
	return r.db.QueryRowContext(ctx, senderQuery, message.SenderID).Scan(&message.SenderDisplayName)
}

func (r *ServerRepository) EnsureChannelAccess(ctx context.Context, userID, channelID int64) error {
	serverID, err := r.lookupServerIDByChannel(ctx, channelID)
	if err != nil {
		return err
	}
	return r.ensureMembership(ctx, userID, serverID)
}

func (r *ServerRepository) EnsureServerAccess(ctx context.Context, userID, serverID int64) error {
	return r.ensureMembership(ctx, userID, serverID)
}

func (r *ServerRepository) LookupServerIDByChannel(ctx context.Context, channelID int64) (int64, error) {
	return r.lookupServerIDByChannel(ctx, channelID)
}

func (r *ServerRepository) FindChannelByID(ctx context.Context, channelID int64) (*model.Channel, error) {
	if r.db == nil {
		return nil, errors.New("postgres is not configured")
	}

	const query = `
SELECT id, server_id, name, kind, topic, created_at, updated_at
FROM channels
WHERE id = $1
LIMIT 1;
`
	var channel model.Channel
	if err := r.db.QueryRowContext(ctx, query, channelID).Scan(
		&channel.ID,
		&channel.ServerID,
		&channel.Name,
		&channel.Kind,
		&channel.Topic,
		&channel.CreatedAt,
		&channel.UpdatedAt,
	); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, ErrChannelNotFound
		}
		return nil, err
	}
	return &channel, nil
}

func (r *ServerRepository) GetMemberRole(ctx context.Context, userID, serverID int64) (string, error) {
	if r.db == nil {
		return "", errors.New("postgres is not configured")
	}

	const query = `
SELECT role
FROM server_members
WHERE server_id = $1 AND user_id = $2
LIMIT 1;
`
	var role string
	if err := r.db.QueryRowContext(ctx, query, serverID, userID).Scan(&role); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return "", ErrNotMember
		}
		return "", err
	}
	return role, nil
}

func (r *ServerRepository) ListMembersByServerID(ctx context.Context, userID, serverID int64) ([]model.ServerMember, error) {
	if err := r.ensureMembership(ctx, userID, serverID); err != nil {
		return nil, err
	}

	const query = `
SELECT u.id, u.email, u.display_name, sm.role, sm.joined_at
FROM server_members sm
INNER JOIN users u ON u.id = sm.user_id
WHERE sm.server_id = $1
ORDER BY
  CASE sm.role WHEN 'owner' THEN 0 WHEN 'admin' THEN 1 ELSE 2 END,
  sm.joined_at ASC;
`
	rows, err := r.db.QueryContext(ctx, query, serverID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var members []model.ServerMember
	for rows.Next() {
		var member model.ServerMember
		if err := rows.Scan(
			&member.UserID,
			&member.Email,
			&member.DisplayName,
			&member.Role,
			&member.JoinedAt,
		); err != nil {
			return nil, err
		}
		members = append(members, member)
	}
	return members, rows.Err()
}

func (r *ServerRepository) MarkChannelRead(ctx context.Context, userID, channelID, messageID int64) error {
	if err := r.EnsureChannelAccess(ctx, userID, channelID); err != nil {
		return err
	}

	const query = `
INSERT INTO channel_reads (channel_id, user_id, last_read_message_id, last_read_at)
VALUES ($1, $2, $3, NOW())
ON CONFLICT (channel_id, user_id) DO UPDATE
SET last_read_message_id = GREATEST(channel_reads.last_read_message_id, EXCLUDED.last_read_message_id),
    last_read_at = NOW();
`
	_, err := r.db.ExecContext(ctx, query, channelID, userID, messageID)
	return err
}

func (r *ServerRepository) FindInviteByCode(ctx context.Context, code string) (*model.ServerInvite, error) {
	if r.db == nil {
		return nil, errors.New("postgres is not configured")
	}

	const query = `
SELECT code, server_id, created_by, role, use_count, max_uses, expires_at, created_at
FROM server_invites
WHERE code = $1
LIMIT 1;
`
	var invite model.ServerInvite
	if err := r.db.QueryRowContext(ctx, query, strings.ToUpper(strings.TrimSpace(code))).Scan(
		&invite.Code,
		&invite.ServerID,
		&invite.CreatedBy,
		&invite.Role,
		&invite.UseCount,
		&invite.MaxUses,
		&invite.ExpiresAt,
		&invite.CreatedAt,
	); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return nil, ErrInviteNotFound
		}
		return nil, err
	}
	return &invite, nil
}

func (r *ServerRepository) ConsumeInvite(ctx context.Context, tx *sql.Tx, code string) error {
	const query = `
UPDATE server_invites
SET use_count = use_count + 1
WHERE code = $1;
`
	_, err := tx.ExecContext(ctx, query, strings.ToUpper(strings.TrimSpace(code)))
	return err
}

func (r *ServerRepository) ListMessagesByChannelID(ctx context.Context, userID, channelID int64, limit int, beforeID int64) (*MessagePage, error) {
	if err := r.EnsureChannelAccess(ctx, userID, channelID); err != nil {
		return nil, err
	}
	if limit <= 0 || limit > 100 {
		limit = 50
	}

	query := `
SELECT m.id, m.channel_id, m.sender_id, u.display_name, m.content, m.created_at, m.updated_at
FROM messages m
INNER JOIN users u ON u.id = m.sender_id
WHERE m.channel_id = $1
`
	args := []any{channelID}
	if beforeID > 0 {
		query += "AND m.id < $2\n"
		args = append(args, beforeID)
	}

	query += `
ORDER BY m.created_at DESC
LIMIT $`
	if beforeID > 0 {
		query += `3`
	} else {
		query += `2`
	}
	query += `;
`
	args = append(args, limit+1)
	rows, err := r.db.QueryContext(ctx, query, args...)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var messages []model.Message
	for rows.Next() {
		var message model.Message
		if err := rows.Scan(
			&message.ID,
			&message.ChannelID,
			&message.SenderID,
			&message.SenderDisplayName,
			&message.Content,
			&message.CreatedAt,
			&message.UpdatedAt,
		); err != nil {
			return nil, err
		}
		messages = append([]model.Message{message}, messages...)
	}
	if err := rows.Err(); err != nil {
		return nil, err
	}

	page := &MessagePage{
		Messages: messages,
	}
	if len(messages) > limit {
		page.HasMore = true
		page.NextBeforeID = messages[0].ID
		page.Messages = messages[1:]
	} else if len(messages) > 0 {
		page.NextBeforeID = messages[0].ID
	}

	return page, nil
}

func (r *ServerRepository) ensureMembership(ctx context.Context, userID, serverID int64) error {
	if r.db == nil {
		return errors.New("postgres is not configured")
	}

	const query = `
SELECT 1
FROM server_members
WHERE server_id = $1 AND user_id = $2
LIMIT 1;
`
	var exists int
	if err := r.db.QueryRowContext(ctx, query, serverID, userID).Scan(&exists); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return ErrNotMember
		}
		return err
	}
	return nil
}

func (r *ServerRepository) lookupServerIDByChannel(ctx context.Context, channelID int64) (int64, error) {
	if r.db == nil {
		return 0, errors.New("postgres is not configured")
	}

	const query = `
SELECT server_id
FROM channels
WHERE id = $1
LIMIT 1;
`
	var serverID int64
	if err := r.db.QueryRowContext(ctx, query, channelID).Scan(&serverID); err != nil {
		if errors.Is(err, sql.ErrNoRows) {
			return 0, ErrChannelNotFound
		}
		return 0, err
	}
	return serverID, nil
}

func NewInviteCode() (string, error) {
	buf := make([]byte, 6)
	if _, err := rand.Read(buf); err != nil {
		return "", err
	}
	code := base32.StdEncoding.WithPadding(base32.NoPadding).EncodeToString(buf)
	return strings.ToUpper(code), nil
}

func InviteExpired(invite *model.ServerInvite, now time.Time) bool {
	if invite == nil {
		return true
	}
	if invite.ExpiresAt != nil && invite.ExpiresAt.Before(now) {
		return true
	}
	return invite.MaxUses > 0 && invite.UseCount >= invite.MaxUses
}
