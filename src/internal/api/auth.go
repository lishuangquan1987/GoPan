package api

import (
	"fmt"
	"gopan-server/config"
	"gopan-server/ent/user"
	"gopan-server/internal/auth"
	"gopan-server/internal/database"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
)

type AuthHandler struct {
	cfg *config.Config
}

func NewAuthHandler(cfg *config.Config) *AuthHandler {
	return &AuthHandler{cfg: cfg}
}

// RegisterRequest represents a registration request
type RegisterRequest struct {
	Username string `json:"username" binding:"required,min=3,max=50"`
	Password string `json:"password" binding:"required,min=6"`
	Email    string `json:"email"`
}

// LoginRequest represents a login request
type LoginRequest struct {
	Username string `json:"username" binding:"required"`
	Password string `json:"password" binding:"required"`
}

// Register handles user registration
func (h *AuthHandler) Register(c *gin.Context) {
	var req RegisterRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	ctx := c.Request.Context()

	// Check if username already exists
	exists, err := database.Client.User.Query().
		Where(user.UsernameEQ(req.Username)).
		Exist(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to check username"})
		return
	}
	if exists {
		c.JSON(http.StatusConflict, gin.H{"error": "Username already exists"})
		return
	}

	// Hash password
	hashedPassword, err := auth.HashPassword(req.Password)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to hash password"})
		return
	}

	// Create user with default 10GB capacity
	user, err := database.Client.User.Create().
		SetUsername(req.Username).
		SetPasswordHash(hashedPassword).
		SetNillableEmail(&req.Email).
		SetTotalQuota(10737418240). // 10GB = 10 * 1024 * 1024 * 1024
		Save(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create user"})
		return
	}

	// Generate token
	token, err := auth.GenerateToken(fmt.Sprintf("%d", user.ID), user.Username, &h.cfg.JWT)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to generate token"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"token": token,
		"user": gin.H{
			"id":       user.ID,
			"username": user.Username,
			"email":    user.Email,
		},
	})
}

// Login handles user login
func (h *AuthHandler) Login(c *gin.Context) {
	var req LoginRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	ctx := c.Request.Context()

	// Find user by username
	user, err := database.Client.User.Query().
		Where(user.UsernameEQ(req.Username)).
		Only(ctx)
	if err != nil {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid username or password"})
		return
	}

	// Check password
	if !auth.CheckPassword(req.Password, user.PasswordHash) {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "Invalid username or password"})
		return
	}

	// Update last login time
	_, err = user.Update().SetLastLoginAt(time.Now()).Save(ctx)
	if err != nil {
		// Log error but don't fail the login
		_ = err
	}

	// Generate token
	token, err := auth.GenerateToken(fmt.Sprintf("%d", user.ID), user.Username, &h.cfg.JWT)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to generate token"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"token": token,
		"user": gin.H{
			"id":       user.ID,
			"username": user.Username,
			"email":    user.Email,
		},
	})
}

// Logout handles user logout (client-side token removal)
func (h *AuthHandler) Logout(c *gin.Context) {
	c.JSON(http.StatusOK, gin.H{"message": "Logged out successfully"})
}

// Me returns current user information
func (h *AuthHandler) Me(c *gin.Context) {
	userID, exists := c.Get("userID")
	if !exists {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}

	ctx := c.Request.Context()

	// Parse user ID
	id, err := strconv.Atoi(userID.(string))
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}

	// Get user
	user, err := database.Client.User.Get(ctx, id)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"id":         user.ID,
		"username":   user.Username,
		"email":      user.Email,
		"created_at": user.CreatedAt,
		"last_login": user.LastLoginAt,
	})
}

