package database

import (
	"database/sql"
	"errors"
	"fmt"

	_ "github.com/jackc/pgx/v5/stdlib"
	"github.com/nocrya/sardine/internal/config"
)

// OpenPostgres 初始化 PostgreSQL 连接。若未配置 DSN，则跳过数据库连接。
func OpenPostgres(cfg config.DatabaseConfig) (*sql.DB, error) {
	if cfg.DSN == "" {
		return nil, nil
	}

	db, err := sql.Open("pgx", cfg.DSN)
	if err != nil {
		return nil, fmt.Errorf("open postgres: %w", err)
	}
	db.SetMaxOpenConns(cfg.MaxOpenConns)
	db.SetMaxIdleConns(cfg.MaxIdleConns)
	db.SetConnMaxLifetime(cfg.ConnMaxLifetime)

	if err := db.Ping(); err != nil {
		_ = db.Close()
		return nil, fmt.Errorf("ping postgres: %w", err)
	}

	return db, nil
}

// MustHavePostgres 校验当前环境已经配置数据库连接。
func MustHavePostgres(db *sql.DB) error {
	if db == nil {
		return errors.New("postgres is not configured")
	}
	return nil
}
