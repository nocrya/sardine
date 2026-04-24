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

// RunMigrations 执行当前启动阶段需要的基础表创建。
func RunMigrations(db *sql.DB) error {
	if db == nil {
		return nil
	}

	if _, err := db.Exec(createUsersTableSQL); err != nil {
		return fmt.Errorf("create users table: %w", err)
	}

	return nil
}
