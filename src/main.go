package main

import (
	"context"
	"embed"
	"fmt"
	"gopan-server/config"
	"gopan-server/internal/api"
	"gopan-server/internal/database"
	"gopan-server/internal/logger"
	"gopan-server/internal/storage"
	"net/http"
	"os"
	"os/signal"
	"syscall"
	"time"

	"github.com/gin-gonic/gin"
)

//go:embed web
var webFS embed.FS

func main() {
	// Initialize logger
	logger.Init()

	// Load configuration
	cfg, err := config.Load()
	if err != nil {
		logger.Error.Fatalf("Failed to load config: %v", err)
	}

	// Initialize database
	if err := database.Init(&cfg.Database); err != nil {
		logger.Error.Fatalf("Failed to initialize database: %v", err)
	}
	defer database.Close()

	// Run migrations
	ctx := context.Background()
	if err := database.Migrate(ctx); err != nil {
		logger.Error.Fatalf("Failed to run migrations: %v", err)
	}

	// Initialize MinIO
	if err := storage.Init(&cfg.MinIO); err != nil {
		logger.Error.Fatalf("Failed to initialize MinIO: %v", err)
	}

	// Setup router
	router := setupRouter(cfg)

	// Create HTTP server
	srv := &http.Server{
		Addr:         fmt.Sprintf("%s:%d", cfg.Server.Host, cfg.Server.Port),
		Handler:      router,
		ReadTimeout:  15 * time.Second,
		WriteTimeout: 15 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	// Start server in goroutine
	go func() {
		logger.Info.Printf("Server starting on %s:%d", cfg.Server.Host, cfg.Server.Port)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			logger.Error.Fatalf("Failed to start server: %v", err)
		}
	}()

	// Wait for interrupt signal for graceful shutdown
	quit := make(chan os.Signal, 1)
	signal.Notify(quit, syscall.SIGINT, syscall.SIGTERM)
	<-quit

	logger.Info.Println("Shutting down server...")

	// Graceful shutdown with timeout
	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	if err := srv.Shutdown(ctx); err != nil {
		logger.Error.Fatalf("Server forced to shutdown: %v", err)
	}

	logger.Info.Println("Server exited")
}

func setupRouter(cfg *config.Config) *gin.Engine {
	// Setup API routes
	router := api.SetupRouter(cfg)

	// Serve static files from embedded FS
	fileServer := http.FileServer(http.FS(webFS))

	// Handle all non-API routes
	router.NoRoute(func(c *gin.Context) {
		path := c.Request.URL.Path

		// Try to serve file from embedded FS
		file, err := webFS.Open("web" + path)
		if err == nil {
			file.Close()
			// Rewrite path to remove leading slash for embed
			c.Request.URL.Path = "web" + path
			fileServer.ServeHTTP(c.Writer, c.Request)
			return
		}

		// If file not found and it's not an API route, serve index.html (SPA)
		if path == "/" || !isAPIRequest(path) {
			indexFile, err := webFS.Open("web/index.html")
			if err == nil {
				defer indexFile.Close()
				c.DataFromReader(http.StatusOK, -1, "text/html", indexFile, nil)
				return
			}
		}

		c.JSON(http.StatusNotFound, gin.H{"error": "Not found"})
	})

	return router
}

func isAPIRequest(path string) bool {
	return len(path) > 4 && path[:4] == "/api"
}
