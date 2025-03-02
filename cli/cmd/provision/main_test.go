package main

import (
	"os"
	"os/exec"
	"testing"
)

// Testing main() is challenging because it doesn't return and may call os.Exit
// We can only test that the package compiles and builds correctly

func TestMainPackageCompiles(t *testing.T) {
	// Simply having this test compile confirms the main package compiles
	t.Log("main package compiles successfully")
}

func TestMainCanBeBuilt(t *testing.T) {
	// Skip if go is not in PATH
	_, err := exec.LookPath("go")
	if err != nil {
		t.Skip("go command not found in PATH, skipping build test")
	}

	// Save current working directory
	wd, err := os.Getwd()
	if err != nil {
		t.Fatalf("Failed to get working directory: %v", err)
	}

	// Create a temporary directory for the build
	tempDir, err := os.MkdirTemp("", "provision-build")
	if err != nil {
		t.Fatalf("Failed to create temp dir: %v", err)
	}
	defer os.RemoveAll(tempDir)

	// Prepare build command that won't actually run the binary
	cmd := exec.Command("go", "build", "-o", tempDir)
	cmd.Dir = wd

	// Execute the build command
	output, err := cmd.CombinedOutput()
	if err != nil {
		t.Fatalf("Build failed: %v\nOutput: %s", err, output)
	}

	// Check that the binary was created
	files, err := os.ReadDir(tempDir)
	if err != nil {
		t.Fatalf("Failed to read build directory: %v", err)
	}

	if len(files) == 0 {
		t.Errorf("No binary was produced by the build")
	}
}

