package api

import (
	"gopan-server/config"
	"gopan-server/internal/middleware"
	"gopan-server/internal/preview"

	"github.com/gin-gonic/gin"
)

// SetupRouter sets up all API routes
func SetupRouter(cfg *config.Config) *gin.Engine {
	router := gin.Default()

	// CORS middleware
	router.Use(func(c *gin.Context) {
		c.Writer.Header().Set("Access-Control-Allow-Origin", "*")
		c.Writer.Header().Set("Access-Control-Allow-Credentials", "true")
		c.Writer.Header().Set("Access-Control-Allow-Headers", "Content-Type, Content-Length, Accept-Encoding, X-CSRF-Token, Authorization, accept, origin, Cache-Control, X-Requested-With")
		c.Writer.Header().Set("Access-Control-Allow-Methods", "POST, OPTIONS, GET, PUT, DELETE")

		if c.Request.Method == "OPTIONS" {
			c.AbortWithStatus(204)
			return
		}

		c.Next()
	})

	// Initialize handlers
	authHandler := NewAuthHandler(cfg)
	fileHandler := NewFileHandler(cfg)
	shareHandler := NewShareHandler(cfg)
	previewHandler := preview.NewPreviewHandler(cfg)

	// Public routes
	api := router.Group("/api")
	{
		// Auth routes
		auth := api.Group("/auth")
		{
			auth.POST("/register", authHandler.Register)
			auth.POST("/login", authHandler.Login)
			auth.POST("/logout", authHandler.Logout)
			auth.GET("/me", middleware.AuthMiddleware(&cfg.JWT), authHandler.Me)
		}

		// Protected routes
		protected := api.Group("")
		protected.Use(middleware.AuthMiddleware(&cfg.JWT))
		{
			// File routes
			files := protected.Group("/files")
			{
				files.GET("", fileHandler.GetFiles)
				files.POST("/upload", fileHandler.UploadFile)
				files.POST("/folder", fileHandler.CreateFolder)
				files.GET("/tree", fileHandler.GetFileTree)
				files.GET("/:id", fileHandler.GetFile)
				files.GET("/:id/download", fileHandler.DownloadFile)
				files.PUT("/:id", fileHandler.RenameFile)
				files.PUT("/move", fileHandler.MoveFiles)
				files.PUT("/copy", fileHandler.CopyFiles)
				files.DELETE("/:id", fileHandler.DeleteFile)
				files.POST("/quick-upload", fileHandler.QuickUpload)
				files.GET("/search", fileHandler.SearchFiles)
				files.GET("/trash", fileHandler.GetTrash)
				files.POST("/restore", fileHandler.RestoreFile)
				files.DELETE("/trash/:id", fileHandler.PermanentlyDelete)
			}

			// Share routes
			shares := protected.Group("/shares")
			{
				shares.POST("", shareHandler.CreateShare)
				shares.DELETE("/:id", shareHandler.DeleteShare)
				shares.GET("", shareHandler.GetMyShares)
			}

			// Preview routes
			previews := protected.Group("/preview")
			{
				previews.GET("/:id", previewHandler.GetPreview)
			}
		}

		// Public share routes
		api.GET("/shares/:code", shareHandler.GetShare)
		api.GET("/shares/:code/download", shareHandler.DownloadShare)
	}

	return router
}

