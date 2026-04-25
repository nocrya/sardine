package database

import (
	"database/sql"
	"fmt"
)

const createUsersTableSQL = `
CREATE TABLE IF NOT EXISTS users (
    id BIGSERIAL PRIMARY KEY,
    email TEXT NOT NULL UNIQUE,
    username TEXT NOT NULL UNIQUE,
    password_hash TEXT NOT NULL,
    display_name TEXT NOT NULL,
    avatar_url TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
`

const createServersTableSQL = `
CREATE TABLE IF NOT EXISTS servers (
    id BIGSERIAL PRIMARY KEY,
    name TEXT NOT NULL,
    description TEXT NOT NULL DEFAULT '',
    owner_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
`

const createServerMembersTableSQL = `
CREATE TABLE IF NOT EXISTS server_members (
    server_id BIGINT NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role TEXT NOT NULL DEFAULT 'member',
    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (server_id, user_id)
);
`

const createServerInvitesTableSQL = `
CREATE TABLE IF NOT EXISTS server_invites (
    code TEXT PRIMARY KEY,
    server_id BIGINT NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
    created_by BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role TEXT NOT NULL DEFAULT 'member',
    use_count BIGINT NOT NULL DEFAULT 0,
    max_uses BIGINT NOT NULL DEFAULT 0,
    expires_at TIMESTAMPTZ NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
`

const createChannelsTableSQL = `
CREATE TABLE IF NOT EXISTS channels (
    id BIGSERIAL PRIMARY KEY,
    server_id BIGINT NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    kind TEXT NOT NULL,
    topic TEXT NOT NULL DEFAULT '',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
`

const createChannelReadsTableSQL = `
CREATE TABLE IF NOT EXISTS channel_reads (
    channel_id BIGINT NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    last_read_message_id BIGINT NOT NULL DEFAULT 0,
    last_read_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (channel_id, user_id)
);
`

const createMessagesTableSQL = `
CREATE TABLE IF NOT EXISTS messages (
    id BIGSERIAL PRIMARY KEY,
    channel_id BIGINT NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
    sender_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
`

const createDirectConversationsTableSQL = `
CREATE TABLE IF NOT EXISTS direct_conversations (
    id BIGSERIAL PRIMARY KEY,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
`

const createDirectConversationMembersTableSQL = `
CREATE TABLE IF NOT EXISTS direct_conversation_members (
    conversation_id BIGINT NOT NULL REFERENCES direct_conversations(id) ON DELETE CASCADE,
    user_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    last_read_message_id BIGINT NOT NULL DEFAULT 0,
    last_read_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (conversation_id, user_id)
);
`

const createDirectMessagesTableSQL = `
CREATE TABLE IF NOT EXISTS direct_messages (
    id BIGSERIAL PRIMARY KEY,
    conversation_id BIGINT NOT NULL REFERENCES direct_conversations(id) ON DELETE CASCADE,
    sender_id BIGINT NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    content TEXT NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
`

// RunMigrations 执行当前启动阶段需要的基础表创建。
func RunMigrations(db *sql.DB) error {
	if db == nil {
		return nil
	}

	if _, err := db.Exec(createUsersTableSQL); err != nil {
		return fmt.Errorf("create users table: %w", err)
	}
	if _, err := db.Exec(createServersTableSQL); err != nil {
		return fmt.Errorf("create servers table: %w", err)
	}
	if _, err := db.Exec(createServerMembersTableSQL); err != nil {
		return fmt.Errorf("create server_members table: %w", err)
	}
	if _, err := db.Exec(createServerInvitesTableSQL); err != nil {
		return fmt.Errorf("create server_invites table: %w", err)
	}
	if _, err := db.Exec(createChannelsTableSQL); err != nil {
		return fmt.Errorf("create channels table: %w", err)
	}
	if _, err := db.Exec(createChannelReadsTableSQL); err != nil {
		return fmt.Errorf("create channel_reads table: %w", err)
	}
	if _, err := db.Exec(createMessagesTableSQL); err != nil {
		return fmt.Errorf("create messages table: %w", err)
	}
	if _, err := db.Exec(createDirectConversationsTableSQL); err != nil {
		return fmt.Errorf("create direct_conversations table: %w", err)
	}
	if _, err := db.Exec(createDirectConversationMembersTableSQL); err != nil {
		return fmt.Errorf("create direct_conversation_members table: %w", err)
	}
	if _, err := db.Exec(`ALTER TABLE direct_conversation_members ADD COLUMN IF NOT EXISTS last_read_message_id BIGINT NOT NULL DEFAULT 0;`); err != nil {
		return fmt.Errorf("alter direct_conversation_members last_read_message_id: %w", err)
	}
	if _, err := db.Exec(`ALTER TABLE direct_conversation_members ADD COLUMN IF NOT EXISTS last_read_at TIMESTAMPTZ NOT NULL DEFAULT NOW();`); err != nil {
		return fmt.Errorf("alter direct_conversation_members last_read_at: %w", err)
	}
	if _, err := db.Exec(createDirectMessagesTableSQL); err != nil {
		return fmt.Errorf("create direct_messages table: %w", err)
	}

	return nil
}
