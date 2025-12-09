package api

import (
	"crypto/rand"
	"encoding/hex"
	"fmt"
	"gopan-server/config"
	"gopan-server/ent"
	"gopan-server/ent/node"
	"gopan-server/ent/share"
	"gopan-server/ent/user"
	"gopan-server/internal/database"
	"gopan-server/internal/storage"
	"net/http"
	"strconv"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/minio/minio-go/v7"
)

type ShareHandler struct {
	cfg *config.Config
}

func NewShareHandler(cfg *config.Config) *ShareHandler {
	return &ShareHandler{cfg: cfg}
}

// generateShareCode generates a unique share code
func generateShareCode() (string, error) {
	bytes := make([]byte, 16)
	if _, err := rand.Read(bytes); err != nil {
		return "", err
	}
	return hex.EncodeToString(bytes), nil
}

// CreateShare handles POST /api/shares - Create share
func (h *ShareHandler) CreateShare(c *gin.Context) {
	userID := c.GetString("userID")

	var req struct {
		NodeID      string    `json:"node_id" binding:"required"`
		ShareType   int       `json:"share_type"` // 0: permanent, 1: temporary
		ExpiresAt   *time.Time `json:"expires_at"`
		Password    string    `json:"password"`
		MaxAccessCount int    `json:"max_access_count"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	ctx := c.Request.Context()

	// Parse user ID
	uid, err := strconv.Atoi(userID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}

	// Parse node ID
	nodeID, err := strconv.Atoi(req.NodeID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid node ID"})
		return
	}

	// Verify node belongs to user
	_, err = database.Client.Node.Query().
		Where(node.IDEQ(nodeID)).
		Where(node.HasOwnerWith(user.IDEQ(uid))).
		Where(node.IsDeletedEQ(false)).
		Only(ctx)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "File not found"})
		return
	}

	// Generate share code
	code, err := generateShareCode()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to generate share code"})
		return
	}

	// Set expiration for temporary shares
	var expiresAt *time.Time
	if req.ShareType == 1 { // Temporary
		if req.ExpiresAt != nil {
			expiresAt = req.ExpiresAt
		} else {
			// Default: 7 days
			defaultExpires := time.Now().Add(7 * 24 * time.Hour)
			expiresAt = &defaultExpires
		}
	}

	// Set password if provided
	var password *string
	if req.Password != "" {
		password = &req.Password
	}

	// Set max access count
	var maxAccessCount *int
	if req.MaxAccessCount > 0 {
		maxAccessCount = &req.MaxAccessCount
	}

	// Create share
	s, err := database.Client.Share.Create().
		SetCode(code).
		SetShareType(req.ShareType).
		SetNillableExpiresAt(expiresAt).
		SetNillablePassword(password).
		SetNillableMaxAccessCount(maxAccessCount).
		SetOwnerID(uid).
		SetNodeID(nodeID).
		Save(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create share"})
		return
	}

	var respExpiresAt *time.Time
	if !s.ExpiresAt.IsZero() {
		respExpiresAt = &s.ExpiresAt
	}
	var respMaxAccessCount *int
	if s.MaxAccessCount > 0 {
		respMaxAccessCount = &s.MaxAccessCount
	}

	c.JSON(http.StatusOK, gin.H{
		"id":             s.ID,
		"code":           s.Code,
		"share_type":     s.ShareType,
		"expires_at":     respExpiresAt,
		"has_password":   s.Password != "",
		"max_access_count": respMaxAccessCount,
		"created_at":     s.CreatedAt,
	})
}

// GetShare handles GET /api/shares/:code - Get share info
func (h *ShareHandler) GetShare(c *gin.Context) {
	code := c.Param("code")
	password := c.Query("password")

	ctx := c.Request.Context()

	// Get share
	s, err := database.Client.Share.Query().
		Where(share.CodeEQ(code)).
		WithNode().
		Only(ctx)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Share not found"})
		return
	}

	// Check if expired
	if !s.ExpiresAt.IsZero() && s.ExpiresAt.Before(time.Now()) {
		c.JSON(http.StatusGone, gin.H{"error": "Share has expired"})
		return
	}

	// Check password if required
	if s.Password != "" {
		if password == "" || password != s.Password {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Password required"})
			return
		}
	}

	// Check max access count
	if s.MaxAccessCount > 0 && s.AccessCount >= s.MaxAccessCount {
		c.JSON(http.StatusForbidden, gin.H{"error": "Share access limit reached"})
		return
	}

	// Increment access count
	s.Update().AddAccessCount(1).Save(ctx)

	// Get node info
	node := s.Edges.Node
	var respExpiresAt *time.Time
	if !s.ExpiresAt.IsZero() {
		respExpiresAt = &s.ExpiresAt
	}
	var respMaxAccessCount *int
	if s.MaxAccessCount > 0 {
		respMaxAccessCount = &s.MaxAccessCount
	}

	c.JSON(http.StatusOK, gin.H{
		"code":           s.Code,
		"share_type":     s.ShareType,
		"expires_at":     respExpiresAt,
		"access_count":   s.AccessCount,
		"max_access_count": respMaxAccessCount,
		"node": gin.H{
			"id":        node.ID,
			"name":      node.Name,
			"type":      node.Type,
			"size":      node.Size,
			"mime_type": node.MimeType,
		},
	})
}

// DownloadShare handles GET /api/shares/:code/download - Download via share code
func (h *ShareHandler) DownloadShare(c *gin.Context) {
	code := c.Param("code")
	password := c.Query("password")

	ctx := c.Request.Context()

	// Get share
	share, err := database.Client.Share.Query().
		Where(share.CodeEQ(code)).
		WithNode().
		Only(ctx)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Share not found"})
		return
	}

	// Check if expired
	if !share.ExpiresAt.IsZero() && share.ExpiresAt.Before(time.Now()) {
		c.JSON(http.StatusGone, gin.H{"error": "Share has expired"})
		return
	}

	// Check password if required
	if share.Password != "" {
		if password == "" || password != share.Password {
			c.JSON(http.StatusUnauthorized, gin.H{"error": "Password required"})
			return
		}
	}

	// Check max access count
	if share.MaxAccessCount > 0 && share.AccessCount >= share.MaxAccessCount {
		c.JSON(http.StatusForbidden, gin.H{"error": "Share access limit reached"})
		return
	}

	node := share.Edges.Node

	// Only files can be downloaded directly
	if node.Type != 1 {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Only files can be downloaded"})
		return
	}

	// Get object from MinIO
	object, err := storage.GetClient().GetObject(ctx, h.cfg.MinIO.BucketName, node.MinioObject, minio.GetObjectOptions{})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to get file from storage"})
		return
	}
	defer object.Close()

	// Increment access count
	share.Update().AddAccessCount(1).Save(ctx)

	// Set headers
	c.Header("Content-Disposition", fmt.Sprintf("attachment; filename=%s", node.Name))
	c.Header("Content-Type", node.MimeType)
	c.Header("Content-Length", fmt.Sprintf("%d", node.Size))

	// Stream file
	c.DataFromReader(http.StatusOK, node.Size, node.MimeType, object, nil)
}

// DeleteShare handles DELETE /api/shares/:id - Delete share
func (h *ShareHandler) DeleteShare(c *gin.Context) {
	userID := c.GetString("userID")
	id := c.Param("id")

	ctx := c.Request.Context()

	// Parse IDs
	uid, err := strconv.Atoi(userID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}

	shareID, err := strconv.Atoi(id)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid share ID"})
		return
	}

	// Verify share belongs to user
	share, err := database.Client.Share.Query().
		Where(share.IDEQ(shareID)).
		Where(share.HasOwnerWith(user.IDEQ(uid))).
		Only(ctx)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "Share not found"})
		return
	}

	// Delete share
	err = database.Client.Share.DeleteOne(share).Exec(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete share"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Share deleted"})
}

// GetMyShares handles GET /api/shares - Get my shares
func (h *ShareHandler) GetMyShares(c *gin.Context) {
	userID := c.GetString("userID")

	ctx := c.Request.Context()

	// Parse user ID
	uid, err := strconv.Atoi(userID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}

	// Get shares
	shares, err := database.Client.Share.Query().
		Where(share.HasOwnerWith(user.IDEQ(uid))).
		WithNode().
		Order(ent.Desc(share.FieldCreatedAt)).
		All(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to get shares"})
		return
	}

	// Format response
	result := make([]gin.H, len(shares))
	for i, s := range shares {
		node := s.Edges.Node
		var expiresAt *time.Time
		if !s.ExpiresAt.IsZero() {
			expiresAt = &s.ExpiresAt
		}
		var maxAccessCount *int
		if s.MaxAccessCount > 0 {
			maxAccessCount = &s.MaxAccessCount
		}
		result[i] = gin.H{
			"id":             s.ID,
			"code":           s.Code,
			"share_type":     s.ShareType,
			"expires_at":     expiresAt,
			"access_count":   s.AccessCount,
			"max_access_count": maxAccessCount,
			"has_password":   s.Password != "",
			"created_at":     s.CreatedAt,
			"node": gin.H{
				"id":   node.ID,
				"name": node.Name,
				"type": node.Type,
			},
		}
	}

	c.JSON(http.StatusOK, gin.H{"shares": result})
}

