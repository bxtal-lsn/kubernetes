package config

import (
	"fmt"
	"os"
	"path/filepath"
)

// GetRepoRoot simply returns the current working directory
// Since we're assuming the binary runs from the project root
func GetRepoRoot() (string, error) {
	// Get current working directory
	cwd, err := os.Getwd()
	if err != nil {
		return "", fmt.Errorf("failed to get current working directory: %w", err)
	}

	// Basic validation - check if key directories exist
	ansibleDir := filepath.Join(cwd, "ansible")
	if !dirExists(ansibleDir) {
		return "", fmt.Errorf("ansible directory not found in %s - please run from project root", cwd)
	}

	scriptsDir := filepath.Join(cwd, "scripts")
	if !dirExists(scriptsDir) {
		return "", fmt.Errorf("scripts directory not found in %s - please run from project root", cwd)
	}

	return cwd, nil
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
