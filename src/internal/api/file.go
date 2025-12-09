package api

import (
	"crypto/sha256"
	"encoding/hex"
	"fmt"
	"gopan-server/config"
	"gopan-server/ent"
	"gopan-server/ent/filehash"
	"gopan-server/ent/node"
	"gopan-server/ent/user"
	"gopan-server/internal/database"
	"gopan-server/internal/storage"
	"io"
	"net/http"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/google/uuid"
	"github.com/minio/minio-go/v7"
)

type FileHandler struct {
	cfg *config.Config
}

func NewFileHandler(cfg *config.Config) *FileHandler {
	return &FileHandler{cfg: cfg}
}

// GetFiles handles GET /api/files - Get file list
func (h *FileHandler) GetFiles(c *gin.Context) {
	userID := c.GetString("userID")
	parentID := c.Query("parent_id")
	page, _ := strconv.Atoi(c.DefaultQuery("page", "1"))
	pageSize, _ := strconv.Atoi(c.DefaultQuery("page_size", "50"))
	sortBy := c.DefaultQuery("sort_by", "name")
	order := c.DefaultQuery("order", "asc")

	ctx := c.Request.Context()

	// Parse user ID
	uid, err := parseUserID(userID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}

	// Build query
	query := queryNodesByOwner(database.Client, uid).
		Where(node.IsDeletedEQ(false))

	// Filter by parent
	if parentID == "" || parentID == "root" {
		query = queryNodesWithoutParent(query)
	} else {
		pid, err := parseNodeID(parentID)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid parent ID"})
			return
		}
		query = queryNodesByParent(query, pid)
	}

	// Apply sorting
	// Note: Windows-style folder-first sorting is handled on the client side
	// Server just sorts by the requested field
	switch sortBy {
	case "name":
		if order == "desc" {
			query = query.Order(ent.Desc(node.FieldName))
		} else {
			query = query.Order(ent.Asc(node.FieldName))
		}
	case "size":
		if order == "desc" {
			query = query.Order(ent.Desc(node.FieldSize))
		} else {
			query = query.Order(ent.Asc(node.FieldSize))
		}
	case "updated_at":
		if order == "desc" {
			query = query.Order(ent.Desc(node.FieldUpdatedAt))
		} else {
			query = query.Order(ent.Asc(node.FieldUpdatedAt))
		}
	default:
		query = query.Order(ent.Asc(node.FieldName))
	}

	// Get total count
	total, err := query.Clone().Count(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to count files"})
		return
	}

	// Apply pagination
	offset := (page - 1) * pageSize
	nodes, err := query.Offset(offset).Limit(pageSize).WithParent().All(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to get files"})
		return
	}

	// Format response
	files := make([]gin.H, len(nodes))
	for i, n := range nodes {
		parentID := getParentID(n)
		files[i] = gin.H{
			"id":         n.ID,
			"name":       n.Name,
			"type":       n.Type,
			"size":       n.Size,
			"mime_type":  n.MimeType,
			"parent_id":  parentID,
			"created_at": n.CreatedAt,
			"updated_at": n.UpdatedAt,
		}
	}

	c.JSON(http.StatusOK, gin.H{
		"files": files,
		"total": total,
		"page":  page,
		"page_size": pageSize,
	})
}

// UploadFile handles POST /api/files/upload - Upload file
func (h *FileHandler) UploadFile(c *gin.Context) {
	userID := c.GetString("userID")
	parentID := c.PostForm("parent_id")

	// Get file from form
	file, err := c.FormFile("file")
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "No file provided"})
		return
	}

	ctx := c.Request.Context()

	// Parse user ID
	uid, err := parseUserID(userID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}

	// Open uploaded file
	src, err := file.Open()
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to open file"})
		return
	}
	defer src.Close()

	// Calculate file hash for quick upload (only for files < 100MB to avoid memory issues)
	var fileHash string
	if file.Size < 100*1024*1024 {
		hasher := sha256.New()
		_, err = io.Copy(hasher, src)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to calculate hash"})
			return
		}
		fileHash = hex.EncodeToString(hasher.Sum(nil))
		// Reset file reader
		src.Seek(0, 0)
	}

	// Check if file already exists (quick upload)
	var minioObject string
	if fileHash != "" {
		fileHashRecord, err := database.Client.FileHash.Query().
			Where(filehash.HashEQ(fileHash)).
			Only(ctx)
		if err == nil {
			// File exists, use existing MinIO object
			minioObject = fileHashRecord.MinioObject
			// Update reference count
			fileHashRecord.Update().AddReferenceCount(1).Save(ctx)
		}
	}
	
	if minioObject == "" {
		// Upload to MinIO
		objectName := fmt.Sprintf("%d/%s/%s", uid, uuid.New().String(), file.Filename)
		minioObject = objectName

		// Reset reader
		src.Seek(0, 0)
		_, err = storage.GetClient().PutObject(ctx, h.cfg.MinIO.BucketName, objectName, src, file.Size, minio.PutObjectOptions{
			ContentType: file.Header.Get("Content-Type"),
		})
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to upload to storage"})
			return
		}

		// Save file hash if calculated
		if fileHash != "" {
			mimeType := file.Header.Get("Content-Type")
			if mimeType == "" {
				mimeType = "application/octet-stream"
			}
			database.Client.FileHash.Create().
				SetHash(fileHash).
				SetMinioObject(minioObject).
				SetSize(file.Size).
				SetNillableMimeType(&mimeType).
				Save(ctx)
		}
	}

	// Parse parent ID
	var parentIDInt *int
	if parentID != "" && parentID != "root" {
		pid, err := parseNodeID(parentID)
		if err == nil {
			parentIDInt = &pid
		}
	}

	// Create node record
	mimeType := file.Header.Get("Content-Type")
	if mimeType == "" {
		mimeType = "application/octet-stream"
	}
	node, err := database.Client.Node.Create().
		SetName(file.Filename).
		SetType(1). // File
		SetSize(file.Size).
		SetMimeType(mimeType).
		SetNillableFileHash(func() *string {
			if fileHash != "" {
				return &fileHash
			}
			return nil
		}()).
		SetMinioObject(minioObject).
		SetOwnerID(uid).
		SetNillableParentID(parentIDInt).
		Save(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create file record"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"id":         node.ID,
		"name":       node.Name,
		"size":       node.Size,
		"mime_type":  node.MimeType,
		"created_at": node.CreatedAt,
	})
}

// CreateFolder handles POST /api/files/folder - Create folder
func (h *FileHandler) CreateFolder(c *gin.Context) {
	userID := c.GetString("userID")

	var req struct {
		Name     string `json:"name" binding:"required"`
		ParentID string `json:"parent_id"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	ctx := c.Request.Context()

	// Parse user ID
	uid, err := parseUserID(userID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}

	// Parse parent ID
	var parentIDInt *int
	if req.ParentID != "" && req.ParentID != "root" {
		pid, err := parseNodeID(req.ParentID)
		if err == nil {
			parentIDInt = &pid
		}
	}

	// Check if folder with same name already exists
	query := queryNodesByOwner(database.Client, uid).
		Where(node.NameEQ(req.Name)).
		Where(node.TypeEQ(0)).
		Where(node.IsDeletedEQ(false))
	if parentIDInt == nil {
		query = queryNodesWithoutParent(query)
	} else {
		query = queryNodesByParent(query, *parentIDInt)
	}

	exists, err := query.Exist(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to check folder existence"})
		return
	}
	if exists {
		c.JSON(http.StatusConflict, gin.H{"error": "Folder already exists"})
		return
	}

	// Create folder
	folder, err := database.Client.Node.Create().
		SetName(req.Name).
		SetType(0). // Folder
		SetOwnerID(uid).
		SetNillableParentID(parentIDInt).
		Save(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create folder"})
		return
	}

	parentID := getParentID(folder)
	c.JSON(http.StatusOK, gin.H{
		"id":         folder.ID,
		"name":       folder.Name,
		"type":       folder.Type,
		"parent_id":  parentID,
		"created_at": folder.CreatedAt,
	})
}

// GetFileTree handles GET /api/files/tree - Get folder tree
func (h *FileHandler) GetFileTree(c *gin.Context) {
	userID := c.GetString("userID")

	ctx := c.Request.Context()

	// Parse user ID
	uid, err := parseUserID(userID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}

	// Get all folders
	folders, err := queryNodesByOwner(database.Client, uid).
		Where(node.TypeEQ(0)).
		Where(node.IsDeletedEQ(false)).
		WithParent().
		All(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to get folders"})
		return
	}

	// Build tree structure
	tree := buildTree(folders, nil)

	c.JSON(http.StatusOK, gin.H{"tree": tree})
}

// buildTree builds a tree structure from nodes
func buildTree(nodes []*ent.Node, parentID *int) []gin.H {
	var result []gin.H
	for _, n := range nodes {
		nodeParentID := getParentID(n)

		if (parentID == nil && nodeParentID == nil) || (parentID != nil && nodeParentID != nil && *parentID == *nodeParentID) {
			children := buildTree(nodes, &n.ID)
			item := gin.H{
				"id":       n.ID,
				"name":     n.Name,
				"children": children,
			}
			result = append(result, item)
		}
	}
	return result
}

// GetFile handles GET /api/files/:id - Get file info
func (h *FileHandler) GetFile(c *gin.Context) {
	userID := c.GetString("userID")
	id := c.Param("id")

	ctx := c.Request.Context()

	// Parse IDs
	uid, err := parseUserID(userID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}

	nodeID, err := parseNodeID(id)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid file ID"})
		return
	}

	// Get file
	n, err := database.Client.Node.Query().
		Where(node.IDEQ(nodeID)).
		Where(node.HasOwnerWith(user.IDEQ(uid))).
		WithParent().
		Only(ctx)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "File not found"})
		return
	}

	parentID := getParentID(n)
	c.JSON(http.StatusOK, gin.H{
		"id":         n.ID,
		"name":       n.Name,
		"type":       n.Type,
		"size":       n.Size,
		"mime_type":  n.MimeType,
		"parent_id":  parentID,
		"created_at": n.CreatedAt,
		"updated_at": n.UpdatedAt,
	})
}

// DownloadFile handles GET /api/files/:id/download - Download file
func (h *FileHandler) DownloadFile(c *gin.Context) {
	userID := c.GetString("userID")
	id := c.Param("id")

	ctx := c.Request.Context()

	// Parse IDs
	uid, err := parseUserID(userID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}

	nodeID, err := parseNodeID(id)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid file ID"})
		return
	}

	// Get file
	n, err := database.Client.Node.Query().
		Where(node.IDEQ(nodeID)).
		Where(node.HasOwnerWith(user.IDEQ(uid))).
		Where(node.TypeEQ(1)). // Only files
		Only(ctx)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "File not found"})
		return
	}

	// Get object from MinIO
	object, err := storage.GetClient().GetObject(ctx, h.cfg.MinIO.BucketName, n.MinioObject, minio.GetObjectOptions{})
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to get file from storage"})
		return
	}
	defer object.Close()

	// Set headers
	c.Header("Content-Disposition", fmt.Sprintf("attachment; filename=%s", n.Name))
	c.Header("Content-Type", n.MimeType)
	c.Header("Content-Length", strconv.FormatInt(n.Size, 10))

	// Stream file
	c.DataFromReader(http.StatusOK, n.Size, n.MimeType, object, nil)
}

// RenameFile handles PUT /api/files/:id - Rename file
func (h *FileHandler) RenameFile(c *gin.Context) {
	userID := c.GetString("userID")
	id := c.Param("id")

	var req struct {
		Name string `json:"name" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	ctx := c.Request.Context()

	// Parse IDs
	uid, err := parseUserID(userID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}

	nodeID, err := parseNodeID(id)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid file ID"})
		return
	}

	// Get file
	n, err := database.Client.Node.Query().
		Where(node.IDEQ(nodeID)).
		Where(node.HasOwnerWith(user.IDEQ(uid))).
		WithParent().
		Only(ctx)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "File not found"})
		return
	}

	// Check if name already exists in same directory
	parentIDInt := getParentID(n)

	query := queryNodesByOwner(database.Client, uid).
		Where(node.NameEQ(req.Name)).
		Where(node.IDNEQ(nodeID)).
		Where(node.IsDeletedEQ(false))
	if parentIDInt == nil {
		query = queryNodesWithoutParent(query)
	} else {
		query = queryNodesByParent(query, *parentIDInt)
	}

	exists, err := query.Exist(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to check name"})
		return
	}
	if exists {
		c.JSON(http.StatusConflict, gin.H{"error": "Name already exists"})
		return
	}

	// Update name
	updated, err := n.Update().SetName(req.Name).Save(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to rename"})
		return
	}

	c.JSON(http.StatusOK, gin.H{
		"id":         updated.ID,
		"name":       updated.Name,
		"updated_at": updated.UpdatedAt,
	})
}

// MoveFiles handles PUT /api/files/move - Move files/folders
func (h *FileHandler) MoveFiles(c *gin.Context) {
	userID := c.GetString("userID")

	var req struct {
		IDs      []string `json:"ids" binding:"required"`
		ParentID string   `json:"parent_id"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	ctx := c.Request.Context()

	// Parse user ID
	uid, err := parseUserID(userID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}

	// Parse parent ID
	var parentIDInt *int
	if req.ParentID != "" && req.ParentID != "root" {
		pid, err := parseNodeID(req.ParentID)
		if err == nil {
			parentIDInt = &pid
		}
	}

	// Parse file IDs
	var nodeIDs []int
	for _, id := range req.IDs {
		nid, err := parseNodeID(id)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": fmt.Sprintf("Invalid file ID: %s", id)})
			return
		}
		nodeIDs = append(nodeIDs, nid)
	}

	// Move files
	var moved []gin.H
	for _, nodeID := range nodeIDs {
		n, err := database.Client.Node.Query().
			Where(node.IDEQ(nodeID)).
			Where(node.HasOwnerWith(user.IDEQ(uid))).
			Only(ctx)
		if err != nil {
			continue
		}

		updated, err := n.Update().SetNillableParentID(parentIDInt).Save(ctx)
		if err == nil {
			parentID := getParentID(updated)
			moved = append(moved, gin.H{
				"id":        updated.ID,
				"name":      updated.Name,
				"parent_id": parentID,
			})
		}
	}

	c.JSON(http.StatusOK, gin.H{"moved": moved})
}

// CopyFiles handles PUT /api/files/copy - Copy files/folders
func (h *FileHandler) CopyFiles(c *gin.Context) {
	userID := c.GetString("userID")

	var req struct {
		IDs      []string `json:"ids" binding:"required"`
		ParentID string   `json:"parent_id"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	ctx := c.Request.Context()

	// Parse user ID
	uid, err := parseUserID(userID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}

	// Parse parent ID
	var parentIDInt *int
	if req.ParentID != "" && req.ParentID != "root" {
		pid, err := parseNodeID(req.ParentID)
		if err == nil {
			parentIDInt = &pid
		}
	}

	// Parse file IDs
	var nodeIDs []int
	for _, id := range req.IDs {
		nid, err := parseNodeID(id)
		if err != nil {
			c.JSON(http.StatusBadRequest, gin.H{"error": fmt.Sprintf("Invalid file ID: %s", id)})
			return
		}
		nodeIDs = append(nodeIDs, nid)
	}

	// Copy files (simplified - only copy file records, not MinIO objects)
	var copied []gin.H
	for _, nodeID := range nodeIDs {
		n, err := database.Client.Node.Query().
			Where(node.IDEQ(nodeID)).
			Where(node.HasOwnerWith(user.IDEQ(uid))).
			Only(ctx)
		if err != nil {
			continue
		}

		// Generate new name if needed (handle name conflicts)
		newName := n.Name
		baseName := n.Name
		ext := ""
		if n.Type == 1 {
			// Extract extension for files
			lastDot := strings.LastIndex(n.Name, ".")
			if lastDot > 0 {
				baseName = n.Name[:lastDot]
				ext = n.Name[lastDot:]
			}
		}
		
		// Check for name conflicts and append (1), (2), etc.
		counter := 1
		for {
			query := queryNodesByOwner(database.Client, uid).
				Where(node.NameEQ(newName)).
				Where(node.IsDeletedEQ(false))
			
			// Check parent relationship
			if parentIDInt == nil {
				query = query.Where(node.Not(node.HasParent()))
			} else {
				query = query.Where(node.HasParentWith(node.IDEQ(*parentIDInt)))
			}
			
			exists, err := query.Exist(ctx)
			if err != nil || !exists {
				break
			}
			if n.Type == 1 {
				newName = fmt.Sprintf("%s (%d)%s", baseName, counter, ext)
			} else {
				newName = fmt.Sprintf("%s (%d)", baseName, counter)
			}
			counter++
			if counter > 1000 { // Safety limit
				break
			}
		}

		newNode, err := database.Client.Node.Create().
			SetName(newName).
			SetType(n.Type).
			SetSize(n.Size).
			SetMimeType(n.MimeType).
			SetFileHash(n.FileHash).
			SetMinioObject(n.MinioObject).
			SetOwnerID(uid).
			SetNillableParentID(parentIDInt).
			Save(ctx)
		if err == nil {
			// Update reference count if it's a file
			if n.Type == 1 && n.FileHash != "" {
				fileHashRecord, err := database.Client.FileHash.Query().
					Where(filehash.HashEQ(n.FileHash)).
					Only(ctx)
				if err == nil {
					fileHashRecord.Update().AddReferenceCount(1).Save(ctx)
				}
			}
			parentID := getParentID(newNode)
			copied = append(copied, gin.H{
				"id":        newNode.ID,
				"name":      newNode.Name,
				"parent_id": parentID,
			})
		}
	}

	c.JSON(http.StatusOK, gin.H{"copied": copied})
}

// DeleteFile handles DELETE /api/files/:id - Delete file (move to trash)
func (h *FileHandler) DeleteFile(c *gin.Context) {
	userID := c.GetString("userID")
	id := c.Param("id")

	ctx := c.Request.Context()

	// Parse IDs
	uid, err := parseUserID(userID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}

	nodeID, err := parseNodeID(id)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid file ID"})
		return
	}

	// Get file
	n, err := database.Client.Node.Query().
		Where(node.IDEQ(nodeID)).
		Where(node.HasOwnerWith(user.IDEQ(uid))).
		Only(ctx)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "File not found"})
		return
	}

	// Mark as deleted
	now := time.Now()
	_, err = n.Update().
		SetIsDeleted(true).
		SetNillableDeletedAt(&now).
		Save(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "File deleted"})
}

// QuickUpload handles POST /api/files/quick-upload - Quick upload using hash
func (h *FileHandler) QuickUpload(c *gin.Context) {
	userID := c.GetString("userID")

	var req struct {
		Hash     string `json:"hash" binding:"required"`
		Name     string `json:"name" binding:"required"`
		Size     int64  `json:"size" binding:"required"`
		MimeType string `json:"mime_type"`
		ParentID string `json:"parent_id"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	ctx := c.Request.Context()

	// Parse user ID
	uid, err := parseUserID(userID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}

	// Check if file hash exists
	fileHashRecord, err := database.Client.FileHash.Query().
		Where(filehash.HashEQ(req.Hash)).
		Only(ctx)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "File hash not found"})
		return
	}

	// Verify size matches
	if fileHashRecord.Size != req.Size {
		c.JSON(http.StatusBadRequest, gin.H{"error": "File size mismatch"})
		return
	}

	// Parse parent ID
	var parentIDInt *int
	if req.ParentID != "" && req.ParentID != "root" {
		pid, err := parseNodeID(req.ParentID)
		if err == nil {
			parentIDInt = &pid
		}
	}

	// Create node record
	mimeType := req.MimeType
	if mimeType == "" {
		mimeType = fileHashRecord.MimeType
	}
	node, err := database.Client.Node.Create().
		SetName(req.Name).
		SetType(1). // File
		SetSize(req.Size).
		SetMimeType(mimeType).
		SetFileHash(req.Hash).
		SetMinioObject(fileHashRecord.MinioObject).
		SetOwnerID(uid).
		SetNillableParentID(parentIDInt).
		Save(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create file record"})
		return
	}

	// Update reference count
	fileHashRecord.Update().AddReferenceCount(1).Save(ctx)

	c.JSON(http.StatusOK, gin.H{
		"id":         node.ID,
		"name":       node.Name,
		"size":       node.Size,
		"mime_type":  node.MimeType,
		"created_at": node.CreatedAt,
		"quick_upload": true,
	})
}

// SearchFiles handles GET /api/files/search - Search files
func (h *FileHandler) SearchFiles(c *gin.Context) {
	userID := c.GetString("userID")
	query := c.Query("q")
	fileType := c.Query("type")

	ctx := c.Request.Context()

	// Parse user ID
	uid, err := parseUserID(userID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}

	// Build query
	dbQuery := queryNodesByOwner(database.Client, uid).
		Where(node.IsDeletedEQ(false))

	// Search by name
	if query != "" {
		dbQuery = dbQuery.Where(node.NameContains(query))
	}

	// Filter by type
	if fileType != "" {
		if fileType == "folder" {
			dbQuery = dbQuery.Where(node.TypeEQ(0))
		} else if fileType == "file" {
			dbQuery = dbQuery.Where(node.TypeEQ(1))
		}
	}

	// Get results
	nodes, err := dbQuery.WithParent().All(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to search files"})
		return
	}

	// Format response
	files := make([]gin.H, len(nodes))
	for i, n := range nodes {
		parentID := getParentID(n)
		files[i] = gin.H{
			"id":         n.ID,
			"name":       n.Name,
			"type":       n.Type,
			"size":       n.Size,
			"mime_type":  n.MimeType,
			"parent_id":  parentID,
			"created_at": n.CreatedAt,
			"updated_at": n.UpdatedAt,
		}
	}

	c.JSON(http.StatusOK, gin.H{"files": files})
}

// GetTrash handles GET /api/files/trash - Get trash files
func (h *FileHandler) GetTrash(c *gin.Context) {
	userID := c.GetString("userID")

	ctx := c.Request.Context()

	// Parse user ID
	uid, err := parseUserID(userID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}

	// Get deleted files
	nodes, err := queryNodesByOwner(database.Client, uid).
		Where(node.IsDeletedEQ(true)).
		Order(ent.Desc(node.FieldDeletedAt)).
		All(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to get trash"})
		return
	}

	// Format response
	files := make([]gin.H, len(nodes))
	for i, n := range nodes {
		files[i] = gin.H{
			"id":         n.ID,
			"name":       n.Name,
			"type":       n.Type,
			"size":       n.Size,
			"deleted_at": n.DeletedAt,
		}
	}

	c.JSON(http.StatusOK, gin.H{"files": files})
}

// RestoreFile handles POST /api/files/restore - Restore file from trash
func (h *FileHandler) RestoreFile(c *gin.Context) {
	userID := c.GetString("userID")

	var req struct {
		ID string `json:"id" binding:"required"`
	}

	if err := c.ShouldBindJSON(&req); err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
		return
	}

	ctx := c.Request.Context()

	// Parse IDs
	uid, err := parseUserID(userID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}

	nodeID, err := parseNodeID(req.ID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid file ID"})
		return
	}

	// Get file
	n, err := database.Client.Node.Query().
		Where(node.IDEQ(nodeID)).
		Where(node.HasOwnerWith(user.IDEQ(uid))).
		Where(node.IsDeletedEQ(true)).
		Only(ctx)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "File not found in trash"})
		return
	}

	// Restore
	_, err = n.Update().
		SetIsDeleted(false).
		SetNillableDeletedAt(nil).
		Save(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to restore"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "File restored"})
}

// PermanentlyDelete handles DELETE /api/files/trash/:id - Permanently delete file
func (h *FileHandler) PermanentlyDelete(c *gin.Context) {
	userID := c.GetString("userID")
	id := c.Param("id")

	ctx := c.Request.Context()

	// Parse IDs
	uid, err := parseUserID(userID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}

	nodeID, err := parseNodeID(id)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid file ID"})
		return
	}

	// Get file
	n, err := database.Client.Node.Query().
		Where(node.IDEQ(nodeID)).
		Where(node.HasOwnerWith(user.IDEQ(uid))).
		Where(node.IsDeletedEQ(true)).
		Only(ctx)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "File not found"})
		return
	}

	// Delete from MinIO if it's a file and no other references exist
	if n.Type == 1 && n.FileHash != "" {
		fileHashRecord, err := database.Client.FileHash.Query().
			Where(filehash.HashEQ(n.FileHash)).
			Only(ctx)
		if err == nil {
			// Decrease reference count
			newCount := fileHashRecord.ReferenceCount - 1
			if newCount <= 0 {
				// Delete from MinIO
				storage.GetClient().RemoveObject(ctx, h.cfg.MinIO.BucketName, fileHashRecord.MinioObject, minio.RemoveObjectOptions{})
				// Delete hash record
				database.Client.FileHash.DeleteOne(fileHashRecord).Exec(ctx)
			} else {
				fileHashRecord.Update().SetReferenceCount(newCount).Save(ctx)
			}
		}
	}

	// Delete node
	err = database.Client.Node.DeleteOne(n).Exec(ctx)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to delete"})
		return
	}

	c.JSON(http.StatusOK, gin.H{"message": "File permanently deleted"})
}

