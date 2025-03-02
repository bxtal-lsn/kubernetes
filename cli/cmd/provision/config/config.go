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
// Update this function in cli/cmd/provision/config/config.go
func findRepoRoot() (string, error) {
	// Start from the current working directory
	cwd, err := os.Getwd()
	if err != nil {
		return "", fmt.Errorf("failed to get current working directory: %w", err)
	}

	// Walk up the directory tree until we find a marker of the repository root
	currentDir := cwd
	for {
		// Check for multiple repository root markers in a specific order

		// First check for the most reliable markers
		ansibleDir := filepath.Join(currentDir, "ansible")
		ansibleDefaultsDir := filepath.Join(currentDir, "ansible", "defaults")
		scriptsDir := filepath.Join(currentDir, "scripts")

		// Add more specific file checks
		kubernetesYml := filepath.Join(currentDir, "ansible", "defaults", "kubernetes.yml")
		provisionScript := filepath.Join(currentDir, "scripts", "provision-kubernetes.sh")

		// Check all variations
		if dirExists(ansibleDir) && dirExists(ansibleDefaultsDir) {
			return currentDir, nil
		}

		if dirExists(scriptsDir) && fileExists(provisionScript) {
			return currentDir, nil
		}

		if fileExists(kubernetesYml) {
			return currentDir, nil
		}

		// Check for .git directory as a fallback
		gitDir := filepath.Join(currentDir, ".git")
		if dirExists(gitDir) {
			// Additional validation when using .git as marker
			// Make sure this is actually our repository by checking for a known file
			if fileExists(filepath.Join(currentDir, "README.md")) ||
				dirExists(filepath.Join(currentDir, "ansible")) ||
				dirExists(filepath.Join(currentDir, "scripts")) {
				return currentDir, nil
			}
		}

		// Move up one directory
		parentDir := filepath.Dir(currentDir)
		if parentDir == currentDir {
			// We've reached the filesystem root without finding the repo root
			break
		}
		currentDir = parentDir
	}

	// More helpful error message
	return "", fmt.Errorf("repository root not found: the CLI needs to be run within the kubernetes repository that contains ansible/defaults/kubernetes.yml file. Please verify your directory structure or run 'git clone' to ensure you have the complete repository")
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
