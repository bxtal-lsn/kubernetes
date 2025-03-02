package config

import (
	"fmt"
	"os"
	"path/filepath"
	"sync"
)

var (
	repoRootCache string
	repoRootOnce  sync.Once
	repoRootErr   error
)

// GetRepoRoot returns the repository root path, caching the result after the first call
func GetRepoRoot() (string, error) {
	repoRootOnce.Do(func() {
		repoRootCache, repoRootErr = findRepoRoot()
	})
	return repoRootCache, repoRootErr
}

// findRepoRoot attempts to find the repository root by looking for marker files/directories
func findRepoRoot() (string, error) {
	// Start from the current working directory
	cwd, err := os.Getwd()
	if err != nil {
		return "", fmt.Errorf("failed to get current working directory: %w", err)
	}

	// Walk up the directory tree until we find a marker of the repository root
	currentDir := cwd
	for {
		// Check for common repository root markers:

		// 1. Check if ansible directory exists
		ansibleDir := filepath.Join(currentDir, "ansible")
		if dirExists(ansibleDir) {
			return currentDir, nil
		}

		// 2. Check for scripts directory with our kubernetes scripts
		scriptsDir := filepath.Join(currentDir, "scripts", "provision-kubernetes.sh")
		if fileExists(scriptsDir) {
			return currentDir, nil
		}

		// 3. Check for .git directory as a fallback
		gitDir := filepath.Join(currentDir, ".git")
		if dirExists(gitDir) {
			return currentDir, nil
		}

		// Move up one directory
		parentDir := filepath.Dir(currentDir)
		if parentDir == currentDir {
			// We've reached the filesystem root without finding the repo root
			return "", fmt.Errorf("repository root not found: no repository markers found in parent directories")
		}
		currentDir = parentDir
	}
}

// dirExists checks if a directory exists
func dirExists(path string) bool {
	info, err := os.Stat(path)
	if err != nil {
		return false
	}
	return info.IsDir()
}

// fileExists checks if a file exists
func fileExists(path string) bool {
	info, err := os.Stat(path)
	if err != nil {
		return false
	}
	return !info.IsDir()
}

// GetAnsiblePath returns the absolute path to an ansible resource
func GetAnsiblePath(resourcePath string) (string, error) {
	repoRoot, err := GetRepoRoot()
	if err != nil {
		return "", err
	}
	return filepath.Join(repoRoot, "ansible", resourcePath), nil
}

// GetScriptsPath returns the absolute path to a script
func GetScriptsPath(scriptName string) (string, error) {
	repoRoot, err := GetRepoRoot()
	if err != nil {
		return "", err
	}
	return filepath.Join(repoRoot, "scripts", scriptName), nil
}
