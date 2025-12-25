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

	// Use GoPan proxy URL instead of MinIO presigned URL
	// This ensures HTTPS access and avoids mixed content issues
	proxyURL := h.getProxyURL(c, nodeID)

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

	// For Office documents (Word, Excel, PPT), use Office Online Viewer with proxy URL
	if isOfficeDocument(ext) {
		previewURL := h.getOfficePreviewURL(proxyURL, n.Name, ext)
		c.JSON(http.StatusOK, gin.H{
			"type":      "office",
			"url":       previewURL,
			"mime_type": mimeType,
			"file_name": n.Name,
			"editable":  true,
		})
		return
	}

	// For PDF, use PDF.js for preview with proxy URL
	if ext == ".pdf" {
		previewURL := h.getPDFPreviewURL(proxyURL, n.Name)
		c.JSON(http.StatusOK, gin.H{
			"type":      "pdf",
			"url":       previewURL,
			"mime_type": mimeType,
			"file_name": n.Name,
		})
		return
	}

	// For images, return direct proxy URL (browser can display directly)
	if strings.HasPrefix(mimeType, "image/") {
		c.JSON(http.StatusOK, gin.H{
			"type":      "url",
			"url":       proxyURL,
			"mime_type": mimeType,
			"file_name": n.Name,
		})
		return
	}

	// For other files, use kkFileView if enabled (through GoPan proxy)
	if h.cfg.Preview.KKFileView.Enabled && h.cfg.Preview.KKFileView.BaseURL != "" {
		// Use GoPan's kkFileView proxy endpoint
		kkFileViewURL := h.getKKFileViewProxyURL(c, nodeID, n.Name)
		c.JSON(http.StatusOK, gin.H{
			"type":      "kkfileview",
			"url":       kkFileViewURL,
			"mime_type": mimeType,
			"file_name": n.Name,
		})
		return
	}

	// Fallback to proxy URL
	c.JSON(http.StatusOK, gin.H{
		"type":      "url",
		"url":       proxyURL,
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

// getProxyURL generates GoPan proxy URL for file access
func (h *PreviewHandler) getProxyURL(c *gin.Context, fileID int) string {
	scheme := "https"
	if c.GetHeader("X-Forwarded-Proto") != "" {
		scheme = c.GetHeader("X-Forwarded-Proto")
	} else if c.Request.TLS == nil {
		scheme = "http"
	}
	host := c.GetHeader("X-Forwarded-Host")
	if host == "" {
		host = c.Request.Host
	}
	
	// Get token from Authorization header or query parameter
	token := ""
	authHeader := c.GetHeader("Authorization")
	if authHeader != "" {
		parts := strings.Split(authHeader, " ")
		if len(parts) == 2 && parts[0] == "Bearer" {
			token = parts[1]
		}
	}
	if token == "" {
		token = c.Query("token")
	}
	
	// Include token in URL for iframe previews
	if token != "" {
		return fmt.Sprintf("%s://%s/api/files/%d/proxy?token=%s", scheme, host, fileID, url.QueryEscape(token))
	}
	return fmt.Sprintf("%s://%s/api/files/%d/proxy", scheme, host, fileID)
}

// getKKFileViewProxyURL generates kkFileView preview URL through GoPan proxy
func (h *PreviewHandler) getKKFileViewProxyURL(c *gin.Context, fileID int, fileName string) string {
	scheme := "https"
	if c.GetHeader("X-Forwarded-Proto") != "" {
		scheme = c.GetHeader("X-Forwarded-Proto")
	} else if c.Request.TLS == nil {
		scheme = "http"
	}
	host := c.GetHeader("X-Forwarded-Host")
	if host == "" {
		host = c.Request.Host
	}
	
	// Get token from Authorization header or query parameter
	token := ""
	authHeader := c.GetHeader("Authorization")
	if authHeader != "" {
		parts := strings.Split(authHeader, " ")
		if len(parts) == 2 && parts[0] == "Bearer" {
			token = parts[1]
		}
	}
	if token == "" {
		token = c.Query("token")
	}
	
	// Use GoPan's kkFileView proxy endpoint with token
	if token != "" {
		return fmt.Sprintf("%s://%s/api/preview/kkfileview/%d?token=%s", scheme, host, fileID, url.QueryEscape(token))
	}
	return fmt.Sprintf("%s://%s/api/preview/kkfileview/%d", scheme, host, fileID)
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

// ProxyKKFileView handles GET /api/preview/kkfileview/:id - Proxy kkFileView requests
func (h *PreviewHandler) ProxyKKFileView(c *gin.Context) {
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

	// Generate proxy URL for the file (with token for authentication)
	scheme := "https"
	if c.GetHeader("X-Forwarded-Proto") != "" {
		scheme = c.GetHeader("X-Forwarded-Proto")
	} else if c.Request.TLS == nil {
		scheme = "http"
	}
	host := c.GetHeader("X-Forwarded-Host")
	if host == "" {
		host = c.Request.Host
	}
	
	// Get token from query parameter or header
	token := c.Query("token")
	if token == "" {
		authHeader := c.GetHeader("Authorization")
		if authHeader != "" {
			parts := strings.Split(authHeader, " ")
			if len(parts) == 2 && parts[0] == "Bearer" {
				token = parts[1]
			}
		}
	}
	
	// Include token in file proxy URL
	var fileProxyURL string
	if token != "" {
		fileProxyURL = fmt.Sprintf("%s://%s/api/files/%d/proxy?token=%s", scheme, host, nodeID, url.QueryEscape(token))
	} else {
		fileProxyURL = fmt.Sprintf("%s://%s/api/files/%d/proxy", scheme, host, nodeID)
	}

	// Build kkFileView URL with the proxy URL
	encodedURL := base64.URLEncoding.EncodeToString([]byte(fileProxyURL))
	
	// Get the path from URL (e.g., /api/preview/kkfileview/123/onlinePreview -> /onlinePreview)
	// Gin's wildcard param includes the leading slash
	kkFileViewPath := c.Param("path")
	if kkFileViewPath == "" {
		kkFileViewPath = "/onlinePreview"
	} else if !strings.HasPrefix(kkFileViewPath, "/") {
		kkFileViewPath = "/" + kkFileViewPath
	}
	// Remove leading slash if it's just "/" (use default)
	if kkFileViewPath == "/" {
		kkFileViewPath = "/onlinePreview"
	}
	
	// Build query string (only include kkFileView-specific parameters)
	query := url.Values{}
	query.Set("url", encodedURL)
	query.Set("fullfilename", n.Name)
	
	// Proxy request to kkFileView
	kkFileViewURL := fmt.Sprintf("%s%s?%s", 
		h.cfg.Preview.KKFileView.BaseURL, 
		kkFileViewPath,
		query.Encode())

	// Forward the request to kkFileView
	req, err := http.NewRequestWithContext(ctx, c.Request.Method, kkFileViewURL, c.Request.Body)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{"error": "Failed to create request"})
		return
	}

	// Copy headers (exclude some headers that shouldn't be forwarded)
	skipHeaders := map[string]bool{
		"Host":              true,
		"Connection":        true,
		"Upgrade":           true,
		"Content-Length":    true,
		"Transfer-Encoding": true,
	}
	for key, values := range c.Request.Header {
		if skipHeaders[key] {
			continue
		}
		for _, value := range values {
			req.Header.Add(key, value)
		}
	}

	// Make request to kkFileView
	client := &http.Client{
		Timeout: 60 * time.Second,
	}
	resp, err := client.Do(req)
	if err != nil {
		c.JSON(http.StatusInternalServerError, gin.H{
			"error": fmt.Sprintf("Failed to proxy request to kkFileView: %v. kkFileView URL: %s", err, kkFileViewURL),
		})
		return
	}
	defer resp.Body.Close()

	// Copy response headers (but skip some that shouldn't be copied)
	skipResponseHeaders := map[string]bool{
		"Content-Length":    true,
		"Transfer-Encoding": true,
		"Connection":        true,
	}
	for key, values := range resp.Header {
		if skipResponseHeaders[key] {
			continue
		}
		for _, value := range values {
			c.Header(key, value)
		}
	}

	// Set status code
	c.Status(resp.StatusCode)

	// Stream response body
	_, err = io.Copy(c.Writer, resp.Body)
	if err != nil {
		// Log error but don't send another response (headers already sent)
		// This is a common issue when client disconnects
		return
	}
}

