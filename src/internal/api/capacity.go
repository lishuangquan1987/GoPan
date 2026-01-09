package api

import (
	"gopan-server/config"
	"gopan-server/ent/node"
	"gopan-server/ent/user"
	"gopan-server/internal/database"
	"net/http"
	"strconv"

	"github.com/gin-gonic/gin"
)

// CapacityHandler handles storage capacity related operations
type CapacityHandler struct {
	cfg *config.Config
}

func NewCapacityHandler(cfg *config.Config) *CapacityHandler {
	return &CapacityHandler{cfg: cfg}
}

// GetCapacityResponse represents the capacity information response
type GetCapacityResponse struct {
	TotalQuota int64  `json:"total_quota"`  // Total quota in bytes
	TotalUsed  int64  `json:"total_used"`   // Total used in bytes
	Remaining  int64  `json:"remaining"`    // Remaining space in bytes
	Percentage float64 `json:"percentage"`   // Usage percentage (0-100)
}

// GetCapacity returns the current user's storage capacity information
func (h *CapacityHandler) GetCapacity(c *gin.Context) {
	userIDStr := c.GetString("userID")
	if userIDStr == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}

	ctx := c.Request.Context()

	// Parse user ID
	userID, err := strconv.Atoi(userIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}

	// Get user with capacity information
	u, err := database.Client.User.Get(ctx, userID)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "User not found"})
		return
	}

	// Calculate remaining and percentage
	remaining := u.TotalQuota - u.TotalUsed
	percentage := float64(0)
	if u.TotalQuota > 0 {
		percentage = float64(u.TotalUsed) / float64(u.TotalQuota) * 100
	}

	// Return capacity information
	c.JSON(http.StatusOK, GetCapacityResponse{
		TotalQuota: u.TotalQuota,
		TotalUsed:  u.TotalUsed,
		Remaining:  remaining,
		Percentage: percentage,
	})
}

// UpdateCapacityRequest represents the request to update user capacity
type UpdateCapacityRequest struct {
	TotalQuota int64 `json:"total_quota" binding:"required,min=1073741824"` // Minimum 1GB
}

// UpdateCapacity updates user capacity (admin only)
func (h *CapacityHandler) UpdateCapacity(c *gin.Context) {
	userIDStr := c.Param("id")
	if userIDStr == "" {
		c.JSON(http.StatusBadRequest, gin.H{"error": "User ID is required"})
		return
	}

	ctx := c.Request.Context()

	// Parse user ID to update
	userID, err := strconv.Atoi(userIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}

	// Parse request body
	var req UpdateCapacityRequest
	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	// Update user capacity
	_, err = database.Client.User.UpdateOneID(userID).
		SetTotalQuota(req.TotalQuota).
		Save(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update capacity"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "Capacity updated successfully"})
}

// RecalculateUsedCapacity recalculates the user's used storage based on actual files
// This is a utility function to correct any discrepancies
func (h *CapacityHandler) RecalculateUsedCapacity(c *gin.Context) {
	userIDStr := c.GetString("userID")
	if userIDStr == "" {
		c.JSON(http.StatusUnauthorized, gin.H{"error": "User not authenticated"})
		return
	}

	ctx := c.Request.Context()

	// Parse user ID
	userID, err := strconv.Atoi(userIDStr)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}

	// Calculate actual used storage from file hashes
	// Sum up all file sizes referenced by the user's nodes
	var totalUsed int64 = 0

	nodes, err := database.Client.Node.Query().
		Where(node.HasOwnerWith(user.ID(userID))).
		Where(node.TypeEQ(1)). // Only files, not folders
		All(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to query files"})
		return
	}

	for _, n := range nodes {
		totalUsed += n.Size
	}

	// Update user's used storage
	_, err = database.Client.User.UpdateOneID(userID).
		SetTotalUsed(totalUsed).
		Save(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to update used storage"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"message":    "Used storage recalculated successfully",
		"total_used":  totalUsed,
	})
}
