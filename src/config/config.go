package config

import (
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"time"
)

// Config holds all configuration for the application
type Config struct {
	Server   ServerConfig   `json:"server"`
	Database DatabaseConfig `json:"database"`
	MinIO    MinIOConfig    `json:"minio"`
	JWT      JWTConfig      `json:"jwt"`
	Preview  PreviewConfig  `json:"preview"`
}

// ServerConfig holds server configuration
type ServerConfig struct {
	Host string `json:"host"`
	Port int    `json:"port"`
}

// DatabaseConfig holds database configuration
type DatabaseConfig struct {
	Host     string `json:"host"`
	Port     int    `json:"port"`
	User     string `json:"user"`
	Password string `json:"password"`
	DBName   string `json:"dbname"`
	SSLMode  string `json:"sslmode"`
}

// MinIOConfig holds MinIO configuration
type MinIOConfig struct {
	Endpoint        string `json:"endpoint"`
	AccessKeyID     string `json:"access_key_id"`
	SecretAccessKey string `json:"secret_access_key"`
	UseSSL          bool   `json:"use_ssl"`
	BucketName      string `json:"bucket_name"`
}

// JWTConfig holds JWT configuration
type JWTConfig struct {
	Secret     string `json:"secret"`
	Expiration string `json:"expiration"` // Duration as string (e.g., "24h", "1h30m")
}

// PreviewConfig holds preview service configuration
type PreviewConfig struct {
	KKFileView KKFileViewConfig `json:"kkfileview"`
}

// KKFileViewConfig holds kkFileView service configuration
type KKFileViewConfig struct {
	Enabled bool   `json:"enabled"`
	BaseURL string `json:"base_url"` // e.g., "http://localhost:8012"
}

// GetExpiration returns the parsed duration
func (j *JWTConfig) GetExpiration() time.Duration {
	if j.Expiration == "" {
		return 24 * time.Hour
	}
	duration, err := time.ParseDuration(j.Expiration)
	if err != nil {
		return 24 * time.Hour
	}
	return duration
}

// Load loads configuration from Config.json file
func Load() (*Config, error) {
	// Get the directory where the executable is located
	exePath, err := os.Executable()
	if err != nil {
		return nil, fmt.Errorf("failed to get executable path: %w", err)
	}
	exeDir := filepath.Dir(exePath)

	// Try to find Config.json in the same directory as the executable
	configPath := filepath.Join(exeDir, "Config.json")

	// If not found, try in current working directory
	if _, err := os.Stat(configPath); os.IsNotExist(err) {
		configPath = "Config.json"
	}

	// Read config file
	data, err := os.ReadFile(configPath)
	if err != nil {
		return nil, fmt.Errorf("failed to read config file %s: %w", configPath, err)
	}

	// Parse JSON
	var config Config
	if err := json.Unmarshal(data, &config); err != nil {
		return nil, fmt.Errorf("failed to parse config file: %w", err)
	}

	// Validate required fields
	if config.JWT.Secret == "" {
		return nil, fmt.Errorf("JWT secret is required in config file")
	}
	if config.JWT.Expiration == "" {
		config.JWT.Expiration = "24h"
	}
	if config.Server.Host == "" {
		config.Server.Host = "0.0.0.0"
	}
	if config.Server.Port == 0 {
		config.Server.Port = 8080
	}

	// Set default preview config
	if config.Preview.KKFileView.BaseURL == "" {
		config.Preview.KKFileView.BaseURL = "http://localhost:8012"
	}

	return &config, nil
}

// DSN returns the PostgreSQL connection string
func (c *DatabaseConfig) DSN() string {
	return fmt.Sprintf("host=%s port=%d user=%s password=%s dbname=%s sslmode=%s",
		c.Host, c.Port, c.User, c.Password, c.DBName, c.SSLMode)
}
