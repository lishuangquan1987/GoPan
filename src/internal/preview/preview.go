package preview

import (
	"encoding/base64"
	"fmt"
	"gopan-server/config"
	"gopan-server/ent/node"
	"gopan-server/ent/user"
	"gopan-server/internal/database"
	"gopan-server/internal/storage"
	"io"
	"net/http"
	"net/url"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
	"github.com/minio/minio-go/v7"
)

type PreviewHandler struct {
	cfg *config.Config
}

func NewPreviewHandler(cfg *config.Config) *PreviewHandler {
	return &PreviewHandler{cfg: cfg}
}

// GetPreview handles GET /api/preview/:id - Get preview URL or content
func (h *PreviewHandler) GetPreview(c *gin.Context) {
	userID := c.GetString("userID")
	id := c.Param("id")

	ctx := c.Request.Context()

	// Parse IDs
	uid, err := strconv.Atoi(userID)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid user ID"})
		return
	}

	nodeID, err := strconv.Atoi(id)
	if err != nil {
		c.JSON(http.StatusBadRequest, gin.H{"error": "Invalid file ID"})
		return
	}

	// Get file
	n, err := database.Client.Node.Query().
		Where(node.IDEQ(nodeID)).
		Where(node.HasOwnerWith(user.IDEQ(uid))).
		Where(node.TypeEQ(1)). // Only files
		Where(node.IsDeletedEQ(false)).
		Only(ctx)
	if err != nil {
		c.JSON(http.StatusNotFound, gin.H{"error": "File not found"})
		return
	}

	// Get file extension
	ext := strings.ToLower(filepath.Ext(n.Name))
	
	// Determine preview type based on MIME type
	mimeType := n.MimeType
	if mimeType == "" {
		mimeType = getMimeTypeFromExt(ext)
	}

	// Generate presigned URL for MinIO
	presignedURL, err := storage.GetClient().PresignedGetObject(ctx, h.cfg.MinIO.BucketName, n.MinioObject, 1*time.Hour, nil)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to generate preview URL"})
		return
	}

	// For text files (txt, md, etc.), return content directly for editing
	if isTextFile(mimeType) || ext == ".txt" || ext == ".md" {
		object, err := storage.GetClient().GetObject(ctx, h.cfg.MinIO.BucketName, n.MinioObject, minio.GetObjectOptions{})
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to get file"})
			return
		}
		defer object.Close()

		content, err := io.ReadAll(object)
		if err != nil {
			c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to read file"})
			return
		}

		c.JSON(http.StatusOK, gin.H{
			"type":      "text",
			"content":   string(content),
			"mime_type": mimeType,
			"editable":  true,
		})
		return
	}

	// For Office documents (Word, Excel, PPT), use traditional web preview
	if isOfficeDocument(ext) {
		previewURL := h.getOfficePreviewURL(presignedURL.String(), n.Name, ext)
		c.JSON(http.StatusOK, gin.H{
			"type":      "office",
			"url":       previewURL,
			"mime_type": mimeType,
			"file_name": n.Name,
			"editable":  true,
		})
		return
	}

	// For PDF, use PDF.js for preview
	if ext == ".pdf" {
		previewURL := h.getPDFPreviewURL(presignedURL.String(), n.Name)
		c.JSON(http.StatusOK, gin.H{
			"type":      "pdf",
			"url":       previewURL,
			"mime_type": mimeType,
			"file_name": n.Name,
		})
		return
	}

	// For other files, use kkFileView if enabled, otherwise use direct URL
	if h.cfg.Preview.KKFileView.Enabled && h.cfg.Preview.KKFileView.BaseURL != "" {
		kkFileViewURL := h.getKKFileViewURL(presignedURL.String(), n.Name)
		c.JSON(http.StatusOK, gin.H{
			"type":      "kkfileview",
			"url":       kkFileViewURL,
			"mime_type": mimeType,
			"file_name": n.Name,
		})
		return
	}

	// Fallback to direct URL
	c.JSON(http.StatusOK, gin.H{
		"type":      "url",
		"url":       presignedURL.String(),
		"mime_type": mimeType,
		"file_name": n.Name,
	})
}

// isTextFile checks if MIME type is a text file
func isTextFile(mimeType string) bool {
	textTypes := []string{
		"text/",
		"application/json",
		"application/xml",
		"application/javascript",
		"application/x-sh",
		"application/x-bash",
	}

	for _, t := range textTypes {
		if strings.HasPrefix(mimeType, t) {
			return true
		}
	}
	return false
}

// getMimeTypeFromExt gets MIME type from file extension
func getMimeTypeFromExt(ext string) string {
	mimeTypes := map[string]string{
		".txt":  "text/plain",
		".md":   "text/markdown",
		".json": "application/json",
		".xml":  "application/xml",
		".html": "text/html",
		".css":  "text/css",
		".js":   "application/javascript",
		".jpg":  "image/jpeg",
		".jpeg": "image/jpeg",
		".png":  "image/png",
		".gif":  "image/gif",
		".pdf":  "application/pdf",
		".mp4":  "video/mp4",
		".mp3":  "audio/mpeg",
		".doc":  "application/msword",
		".docx": "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
		".xls":  "application/vnd.ms-excel",
		".xlsx": "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
		".ppt":  "application/vnd.ms-powerpoint",
		".pptx": "application/vnd.openxmlformats-officedocument.presentationml.presentation",
	}

	if mimeType, ok := mimeTypes[ext]; ok {
		return mimeType
	}
	return "application/octet-stream"
}

// isOfficeDocument checks if file is an Office document
func isOfficeDocument(ext string) bool {
	officeExts := []string{".doc", ".docx", ".xls", ".xlsx", ".ppt", ".pptx"}
	ext = strings.ToLower(ext)
	for _, e := range officeExts {
		if e == ext {
			return true
		}
	}
	return false
}

// getKKFileViewURL generates kkFileView preview URL
func (h *PreviewHandler) getKKFileViewURL(fileURL, fileName string) string {
	// kkFileView format: http://kkfileview:8012/onlinePreview?url=encoded_file_url
	encodedURL := base64.URLEncoding.EncodeToString([]byte(fileURL))
	return fmt.Sprintf("%s/onlinePreview?url=%s", h.cfg.Preview.KKFileView.BaseURL, encodedURL)
}

// getOfficePreviewURL generates Office document preview URL using Office Online or similar
func (h *PreviewHandler) getOfficePreviewURL(fileURL, fileName, ext string) string {
	// Use Microsoft Office Online Viewer or LibreOffice Online
	// Format: https://view.officeapps.live.com/op/view.aspx?src=file_url
	encodedURL := url.QueryEscape(fileURL)
	return fmt.Sprintf("https://view.officeapps.live.com/op/view.aspx?src=%s", encodedURL)
}

// getPDFPreviewURL generates PDF preview URL using PDF.js
func (h *PreviewHandler) getPDFPreviewURL(fileURL, fileName string) string {
	// Use PDF.js viewer
	// Format: /pdfjs/web/viewer.html?file=file_url
	encodedURL := url.QueryEscape(fileURL)
	return fmt.Sprintf("/pdfjs/web/viewer.html?file=%s", encodedURL)
}

