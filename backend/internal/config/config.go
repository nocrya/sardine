// Package config 负责通过 Viper 从环境变量或配置文件加载应用配置。
package config

import (
	"os"
	"path/filepath"
	"strings"
	"time"

	"github.com/joho/godotenv"
	"github.com/spf13/viper"
)

// DatabaseConfig 聚合 PostgreSQL 连接相关配置。
type DatabaseConfig struct {
	DSN             string
	MaxOpenConns    int
	MaxIdleConns    int
	ConnMaxLifetime time.Duration
}

// CORSConfig 聚合跨域相关配置。
type CORSConfig struct {
	AllowedOrigins []string
}

// AuthConfig 聚合鉴权相关配置。
type AuthConfig struct {
	JWTSecret            string
	AccessTokenTTL       time.Duration
	BcryptCost           int
	BootstrapAutoMigrate bool
}

// AppConfig 聚合运行时配置。
type AppConfig struct {
	Env      string
	HTTPAddr string
	Database DatabaseConfig
	CORS     CORSConfig
	Auth     AuthConfig
}

// Load 从环境读取配置。支持的环境变量形如 SARDINE_HTTP_ADDR、SARDINE_DB_DSN。
// 若存在 .env 文件则先载入到进程环境（不覆盖已在 shell/系统中设置的变量），再由 Viper 读取。
func Load() (*AppConfig, error) {
	loadDotEnv()

	v := viper.New()
	v.SetEnvPrefix("SARDINE")
	v.AutomaticEnv()

	v.SetDefault("ENV", "development")
	v.SetDefault("HTTP_ADDR", ":8080")
	v.SetDefault("DB_DSN", "")
	v.SetDefault("DB_MAX_OPEN_CONNS", 10)
	v.SetDefault("DB_MAX_IDLE_CONNS", 5)
	v.SetDefault("DB_CONN_MAX_LIFETIME", "30m")
	v.SetDefault("CORS_ALLOWED_ORIGINS", "http://localhost:3000,http://127.0.0.1:3000,http://localhost:8080,http://127.0.0.1:8080")
	v.SetDefault("AUTH_JWT_SECRET", "dev-secret-change-me")
	v.SetDefault("AUTH_ACCESS_TOKEN_TTL", "24h")
	v.SetDefault("AUTH_BCRYPT_COST", 12)
	v.SetDefault("AUTH_BOOTSTRAP_AUTO_MIGRATE", true)

	return &AppConfig{
		Env:      v.GetString("env"),
		HTTPAddr: v.GetString("http_addr"),
		Database: DatabaseConfig{
			DSN:             v.GetString("db_dsn"),
			MaxOpenConns:    v.GetInt("db_max_open_conns"),
			MaxIdleConns:    v.GetInt("db_max_idle_conns"),
			ConnMaxLifetime: v.GetDuration("db_conn_max_lifetime"),
		},
		CORS: CORSConfig{
			AllowedOrigins: splitCSV(v.GetString("cors_allowed_origins")),
		},
		Auth: AuthConfig{
			JWTSecret:            v.GetString("auth_jwt_secret"),
			AccessTokenTTL:       v.GetDuration("auth_access_token_ttl"),
			BcryptCost:           v.GetInt("auth_bcrypt_cost"),
			BootstrapAutoMigrate: v.GetBool("auth_bootstrap_auto_migrate"),
		},
	}, nil
}

// loadDotEnv 尝试加载第一个存在的文件：当前目录 .env，或仓库根下 backend/.env。
func loadDotEnv() {
	for _, p := range []string{".env", filepath.Join("backend", ".env")} {
		if _, err := os.Stat(p); err != nil {
			continue
		}
		_ = godotenv.Load(p)
		return
	}
}

func splitCSV(value string) []string {
	if value == "" {
		return nil
	}

	parts := strings.Split(value, ",")
	result := make([]string, 0, len(parts))
	for _, part := range parts {
		trimmed := strings.TrimSpace(part)
		if trimmed != "" {
			result = append(result, trimmed)
		}
	}
	return result
}
