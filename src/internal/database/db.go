package database

import (
	"context"
	"database/sql"
	"entgo.io/ent/dialect"
	entsql "entgo.io/ent/dialect/sql"
	"fmt"
	"gopan-server/config"
	"gopan-server/ent"
	"log"

	_ "github.com/lib/pq"
)

var (
	Client *ent.Client
	DB     *sql.DB
)

// Init initializes the database connection and Ent client
func Init(cfg *config.DatabaseConfig) error {
	var err error

	// Open database connection
	DB, err = sql.Open("postgres", cfg.DSN())
	if err != nil {
		return fmt.Errorf("failed to open database: %w", err)
	}

	// Test connection
	if err := DB.Ping(); err != nil {
		return fmt.Errorf("failed to ping database: %w", err)
	}

	// Create Ent driver
	drv := entsql.OpenDB(dialect.Postgres, DB)

	// Create Ent client
	Client = ent.NewClient(ent.Driver(drv))

	log.Println("Database connection established successfully")
	return nil
}

// Close closes the database connection
func Close() error {
	if Client != nil {
		if err := Client.Close(); err != nil {
			return err
		}
	}
	if DB != nil {
		return DB.Close()
	}
	return nil
}

// Migrate runs database migrations
func Migrate(ctx context.Context) error {
	if Client == nil {
		return fmt.Errorf("database client not initialized")
	}

	if err := Client.Schema.Create(ctx); err != nil {
		return fmt.Errorf("failed to create schema: %w", err)
	}

	log.Println("Database schema migrated successfully")
	return nil
}

