// Package middleware 提供鉴权、请求日志、限流、CORS 等 Gin 中间件。
package middleware

import (
	"net/http"
	"net/url"
	"strings"

	"github.com/gin-gonic/gin"
	"github.com/nocrya/sardine/internal/service"
)

// isLoopbackBrowserOrigin 判断是否为本地浏览器常见 Origin（含 Flutter Web 随机端口）。
func isLoopbackBrowserOrigin(origin string) bool {
	u, err := url.Parse(origin)
	if err != nil || u.Host == "" {
		return false
	}
	if u.Scheme != "http" && u.Scheme != "https" {
		return false
	}
	h := strings.ToLower(u.Hostname())
	return h == "localhost" || h == "127.0.0.1" || h == "::1"
}

// CORS 返回一个简单的跨域中间件，满足本地前后端分离开发。
// allowDevLoopbackOrigins 为 true 时（通常即 Env=development），除白名单外还允许任意
// http(s)://localhost:* / 127.0.0.1:* / [::1]:* 来源，便于 Flutter Web（随机端口）联调。
func CORS(allowedOrigins []string, allowDevLoopbackOrigins bool) gin.HandlerFunc {
	allowed := make(map[string]struct{}, len(allowedOrigins))
	for _, origin := range allowedOrigins {
		allowed[origin] = struct{}{}
	}

	return func(c *gin.Context) {
		origin := c.GetHeader("Origin")
		if origin != "" {
			var reflect string
			switch {
			case len(allowed) == 0:
				reflect = origin
			case allowDevLoopbackOrigins && isLoopbackBrowserOrigin(origin):
				reflect = origin
			default:
				if _, ok := allowed[origin]; ok {
					reflect = origin
				}
			}
			if reflect != "" {
				c.Writer.Header().Set("Access-Control-Allow-Origin", reflect)
			}
			c.Writer.Header().Set("Vary", "Origin")
			c.Writer.Header().Set("Access-Control-Allow-Credentials", "true")
			c.Writer.Header().Set("Access-Control-Allow-Headers", "Authorization, Content-Type, X-Requested-With")
			c.Writer.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, PATCH, DELETE, OPTIONS")
		}

		if c.Request.Method == http.MethodOptions {
			c.AbortWithStatus(http.StatusNoContent)
			return
		}

		c.Next()
	}
}

// RequireAuth 校验 Bearer token，并将 user id 写入上下文。
func RequireAuth(authService *service.AuthService) gin.HandlerFunc {
	return func(c *gin.Context) {
		header := c.GetHeader("Authorization")
		if !strings.HasPrefix(header, "Bearer ") {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "missing bearer token"})
			return
		}

		token := strings.TrimSpace(strings.TrimPrefix(header, "Bearer "))
		claims, err := authService.ParseToken(token)
		if err != nil {
			c.AbortWithStatusJSON(http.StatusUnauthorized, gin.H{"error": "invalid token"})
			return
		}

		c.Set("auth.user_id", claims.UserID)
		c.Next()
	}
}
