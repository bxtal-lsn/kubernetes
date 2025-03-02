package embedded

import (
	"embed"
	"fmt"
	"io/fs"
	"os"
	"path/filepath"
)

//go:embed ansible/* multipass/* scripts/*
var Resources embed.FS

// TempDir holds the path to the temporary directory where files are extracted
var TempDir string

// Initialize extracts embedded resources to a temporary directory
func Initialize() (string, error) {
	var err error
	TempDir, err = os.MkdirTemp("", "kubernetes-provision-")
	if err != nil {
		return "", fmt.Errorf("failed to create temp directory: %w", err)
	}

	// Extract all embedded files
	err = fs.WalkDir(Resources, ".", func(path string, d fs.DirEntry, err error) error {
		if err != nil {
			return err
		}

		// Skip the root directory
		if path == "." {
			return nil
		}

		destPath := filepath.Join(TempDir, path)

		// Create directory if needed
		if d.IsDir() {
			return os.MkdirAll(destPath, 0o755)
		}

		// Extract file
		data, err := Resources.ReadFile(path)
		if err != nil {
			return fmt.Errorf("failed to read embedded file %s: %w", path, err)
		}

		// Create parent directories if they don't exist
		if err := os.MkdirAll(filepath.Dir(destPath), 0o755); err != nil {
			return fmt.Errorf("failed to create directory for %s: %w", destPath, err)
		}

		// Write file
		if err := os.WriteFile(destPath, data, 0o644); err != nil {
			return fmt.Errorf("failed to write file %s: %w", destPath, err)
		}

		// Make scripts executable
		if filepath.Ext(destPath) == ".sh" {
			if err := os.Chmod(destPath, 0o755); err != nil {
				return fmt.Errorf("failed to make script executable %s: %w", destPath, err)
			}
		}

		return nil
	})
	if err != nil {
		// Clean up on error
		Cleanup()
		return "", fmt.Errorf("failed to extract embedded files: %w", err)
	}

	return TempDir, nil
}

// Cleanup removes the temporary directory
func Cleanup() {
	if TempDir != "" {
		os.RemoveAll(TempDir)
		TempDir = ""
	}
}

// GetAnsiblePath returns the path to an Ansible resource
func GetAnsiblePath(resourcePath string) string {
	return filepath.Join(TempDir, "ansible", resourcePath)
}

// GetScriptPath returns the path to a script
func GetScriptPath(scriptName string) string {
	return filepath.Join(TempDir, "scripts", scriptName)
}

// GetCloudInitPath returns the path to a cloud-init template
func GetCloudInitPath(templateName string) string {
	return filepath.Join(TempDir, "multipass", "cloud-init", templateName)
}
