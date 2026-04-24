// Package main 是 Sardine 后端 HTTP/WebSocket 服务的程序入口。
package main

import (
	"log"
	"net/http"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/nocrya/sardine/internal/app"
	"github.com/nocrya/sardine/internal/config"
	"github.com/nocrya/sardine/internal/handler"
	"github.com/nocrya/sardine/internal/middleware"
)

func main() {
	cfg, err := config.Load()
	if err != nil {
		log.Fatalf("config: %v", err)
	}

	application, err := app.New(cfg)
	if err != nil {
		log.Fatalf("bootstrap: %v", err)
	}
	defer func() {
		if err := application.Close(); err != nil {
			log.Printf("shutdown: %v", err)
		}
	}()

	router := gin.New()
	router.Use(gin.Logger(), gin.Recovery(), middleware.CORS(cfg.CORS.AllowedOrigins))
	handler.RegisterRoutes(router, application)

	addr := cfg.HTTPAddr
	if addr == "" {
		addr = ":8080"
	}
	s := &http.Server{
		Addr:              addr,
		Handler:           router,
		ReadHeaderTimeout: 5 * time.Second,
	}
	log.Printf("Sardine backend listening on %s", addr)
	if err := s.ListenAndServe(); err != nil && err != http.ErrServerClosed {
		log.Fatal(err)
	}
}
