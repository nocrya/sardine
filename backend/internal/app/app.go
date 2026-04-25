package app

import (
	"database/sql"
	"errors"

	"github.com/nocrya/sardine/internal/config"
	"github.com/nocrya/sardine/internal/database"
	"github.com/nocrya/sardine/internal/repository"
	"github.com/nocrya/sardine/internal/service"
	"github.com/nocrya/sardine/internal/websocket"
)

// App 聚合服务启动时需要共享的资源。
type App struct {
	Config               *config.AppConfig
	DB                   *sql.DB
	Hub                  *websocket.Hub
	AuthService          *service.AuthService
	ServerService        *service.ServerService
	DirectMessageService *service.DirectMessageService
}

// New 创建应用容器，并初始化必要资源。
func New(cfg *config.AppConfig) (*App, error) {
	db, err := database.OpenPostgres(cfg.Database)
	if err != nil {
		return nil, err
	}

	if cfg.Auth.BootstrapAutoMigrate && db != nil {
		if err := database.RunMigrations(db); err != nil {
			_ = db.Close()
			return nil, err
		}
	}

	userRepository := repository.NewUserRepository(db)
	serverRepository := repository.NewServerRepository(db)
	directMessageRepository := repository.NewDirectMessageRepository(db)
	authService := service.NewAuthService(userRepository, cfg.Auth)
	serverService := service.NewServerService(serverRepository, userRepository, cfg.LiveKit)
	directMessageService := service.NewDirectMessageService(directMessageRepository, userRepository)
	hub := websocket.NewHub()

	return &App{
		Config:               cfg,
		DB:                   db,
		Hub:                  hub,
		AuthService:          authService,
		ServerService:        serverService,
		DirectMessageService: directMessageService,
	}, nil
}

// Close 释放应用资源。
func (a *App) Close() error {
	if a == nil || a.DB == nil {
		return nil
	}
	if err := a.DB.Close(); err != nil {
		return errors.New("close database: " + err.Error())
	}
	return nil
}
