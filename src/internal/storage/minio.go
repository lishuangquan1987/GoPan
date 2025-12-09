package storage

import (
	"context"
	"fmt"
	"gopan-server/config"
	"log"

	"github.com/minio/minio-go/v7"
	"github.com/minio/minio-go/v7/pkg/credentials"
)

var (
	Client *minio.Client
)

// Init initializes the MinIO client and creates the bucket if it doesn't exist
func Init(cfg *config.MinIOConfig) error {
	var err error

	// Initialize MinIO client
	Client, err = minio.New(cfg.Endpoint, &minio.Options{
		Creds:  credentials.NewStaticV4(cfg.AccessKeyID, cfg.SecretAccessKey, ""),
		Secure: cfg.UseSSL,
	})
	if err != nil {
		return fmt.Errorf("failed to create MinIO client: %w", err)
	}

	// Check if bucket exists
	ctx := context.Background()
	exists, err := Client.BucketExists(ctx, cfg.BucketName)
	if err != nil {
		return fmt.Errorf("failed to check bucket existence: %w", err)
	}

	// Create bucket if it doesn't exist
	if !exists {
		err = Client.MakeBucket(ctx, cfg.BucketName, minio.MakeBucketOptions{})
		if err != nil {
			return fmt.Errorf("failed to create bucket: %w", err)
		}
		log.Printf("Created bucket: %s", cfg.BucketName)
	} else {
		log.Printf("Bucket already exists: %s", cfg.BucketName)
	}

	log.Println("MinIO client initialized successfully")
	return nil
}

// GetClient returns the MinIO client
func GetClient() *minio.Client {
	return Client
}

