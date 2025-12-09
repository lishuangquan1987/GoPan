//go:build ignore
// +build ignore

package main

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
)

func main() {
	// Get the directory where generate.go is located
	// When running with "go run generate.go", __file__ is not available
	// So we use the current working directory
	wd, err := os.Getwd()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Error getting working directory: %v\n", err)
		os.Exit(1)
	}

	// Check if we're in the right directory (should have go.mod and ent/schema)
	goModPath := filepath.Join(wd, "go.mod")
	if _, err := os.Stat(goModPath); os.IsNotExist(err) {
		fmt.Fprintf(os.Stderr, "Error: go.mod not found in current directory: %s\n", wd)
		fmt.Fprintf(os.Stderr, "Please run this command from the src/ directory\n")
		os.Exit(1)
	}

	entSchemaPath := filepath.Join(wd, "ent", "schema")
	if _, err := os.Stat(entSchemaPath); os.IsNotExist(err) {
		fmt.Fprintf(os.Stderr, "Error: ent/schema directory not found in: %s\n", wd)
		os.Exit(1)
	}

	// Run ent generate command
	// Use the full path to ensure we're in the right directory
	cmd := exec.Command("go", "run", "-mod=mod", "entgo.io/ent/cmd/ent", "generate", "./ent/schema")
	cmd.Dir = wd
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr

	fmt.Printf("Generating Ent code in: %s\n", wd)
	fmt.Println("Running: go run -mod=mod entgo.io/ent/cmd/ent generate ./ent/schema")

	if err := cmd.Run(); err != nil {
		fmt.Fprintf(os.Stderr, "\nError generating Ent code: %v\n", err)
		os.Exit(1)
	}

	fmt.Println("\n✓ Ent code generated successfully!")
}
