package cmd

import (
	"testing"
)

func TestRootCmd(t *testing.T) {
	// Check that rootCmd has the expected attributes
	if rootCmd == nil {
		t.Fatalf("rootCmd is nil")
	}

	if rootCmd.Use != "provision" {
		t.Errorf("rootCmd.Use = %q, want \"provision\"", rootCmd.Use)
	}

	if rootCmd.Short == "" {
		t.Errorf("rootCmd.Short is empty")
	}

	if rootCmd.Long == "" {
		t.Errorf("rootCmd.Long is empty")
	}
}

func TestSubCommands(t *testing.T) {
	// Check that the subcommands are properly registered
	commands := rootCmd.Commands()

	// Helper function to find a command by name
	findCmd := func(name string) bool {
		for _, cmd := range commands {
			if cmd.Use == name {
				return true
			}
		}
		return false
	}

	// Check provision command
	if !findCmd("provision") {
		t.Errorf("\"provision\" command not found in rootCmd")
	}

	// Check cleanup command
	if !findCmd("cleanup") {
		t.Errorf("\"cleanup\" command not found in rootCmd")
	}
}

func TestExecuteFunction(t *testing.T) {
	// Testing Execute() directly will run the entire CLI, which isn't suitable for unit testing
	// Instead, we check that the function exists with the correct signature
	var _ func() error = Execute
}

// We can't really test exitWithError because it calls os.Exit, which would terminate the test
func TestExitWithErrorSignature(t *testing.T) {
	// Just check the function signature
	var _ func(string, error) = exitWithError
}

func TestProvisionCmd(t *testing.T) {
	// Check that provisionCmd has the expected attributes
	if provisionCmd == nil {
		t.Fatalf("provisionCmd is nil")
	}

	if provisionCmd.Use != "provision" {
		t.Errorf("provisionCmd.Use = %q, want \"provision\"", provisionCmd.Use)
	}

	if provisionCmd.Short == "" {
		t.Errorf("provisionCmd.Short is empty")
	}

	if provisionCmd.Long == "" {
		t.Errorf("provisionCmd.Long is empty")
	}

	// Check that the Run function is defined
	if provisionCmd.Run == nil {
		t.Errorf("provisionCmd.Run is nil")
	}
}

func TestCleanupCmd(t *testing.T) {
	// Check that cleanupCmd has the expected attributes
	if cleanupCmd == nil {
		t.Fatalf("cleanupCmd is nil")
	}

	if cleanupCmd.Use != "cleanup" {
		t.Errorf("cleanupCmd.Use = %q, want \"cleanup\"", cleanupCmd.Use)
	}

	if cleanupCmd.Short == "" {
		t.Errorf("cleanupCmd.Short is empty")
	}

	if cleanupCmd.Long == "" {
		t.Errorf("cleanupCmd.Long is empty")
	}

	// Check that the Run function is defined
	if cleanupCmd.Run == nil {
		t.Errorf("cleanupCmd.Run is nil")
	}
}
