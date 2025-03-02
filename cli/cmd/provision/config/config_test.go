package config

import (
	"os"
	"path/filepath"
	"sync"
	"testing"
)

func TestGetRepoRoot(t *testing.T) {
	// Test basic functionality
	root, err := GetRepoRoot()
	if err != nil {
		t.Fatalf("GetRepoRoot() error = %v", err)
	}
	if root == "" {
		t.Fatalf("GetRepoRoot() returned empty string")
	}

	// Reset the cache to test multiple calls
	repoRootCache = ""
	repoRootOnce = sync.Once{}

	// First call
	root1, err := GetRepoRoot()
	if err != nil {
		t.Fatalf("GetRepoRoot() first call error = %v", err)
	}

	// Second call should return the same result
	root2, err := GetRepoRoot()
	if err != nil {
		t.Fatalf("GetRepoRoot() second call error = %v", err)
	}

	// Results should be the same (cached)
	if root1 != root2 {
		t.Errorf("GetRepoRoot() cache failed: got %q then %q", root1, root2)
	}
}

func TestDirExists(t *testing.T) {
	// Create a temporary directory
	tempDir, err := os.MkdirTemp("", "dir-test")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tempDir)

	// Test with existing directory
	if !dirExists(tempDir) {
		t.Errorf("dirExists(%q) = false, want true", tempDir)
	}

	// Test with non-existent directory
	nonExistentDir := filepath.Join(tempDir, "non-existent")
	if dirExists(nonExistentDir) {
		t.Errorf("dirExists(%q) = true, want false", nonExistentDir)
	}

	// Create a file and test
	filePath := filepath.Join(tempDir, "testfile")
	if err := os.WriteFile(filePath, []byte("test"), 0o644); err != nil {
		t.Fatalf("Failed to create test file: %v", err)
	}

	// A file should return false
	if dirExists(filePath) {
		t.Errorf("dirExists(%q) for a file = true, want false", filePath)
	}
}

func TestFileExists(t *testing.T) {
	// Create a temporary directory
	tempDir, err := os.MkdirTemp("", "file-test")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tempDir)

	// Test with non-existent file
	nonExistentFile := filepath.Join(tempDir, "non-existent")
	if fileExists(nonExistentFile) {
		t.Errorf("fileExists(%q) = true, want false", nonExistentFile)
	}

	// Create a file and test
	filePath := filepath.Join(tempDir, "testfile")
	if err := os.WriteFile(filePath, []byte("test"), 0o644); err != nil {
		t.Fatalf("Failed to create test file: %v", err)
	}

	// The file should exist
	if !fileExists(filePath) {
		t.Errorf("fileExists(%q) = false, want true", filePath)
	}

	// A directory should return false
	if fileExists(tempDir) {
		t.Errorf("fileExists(%q) for a directory = true, want false", tempDir)
	}
}

func TestGetAnsiblePath(t *testing.T) {
	// Skip this test as it depends on specific directory structure
	t.Skip("Skipping path test that depends on specific directory structure")
}

func TestGetScriptsPath(t *testing.T) {
	// Skip this test as it depends on specific directory structure
	t.Skip("Skipping path test that depends on specific directory structure")
}

