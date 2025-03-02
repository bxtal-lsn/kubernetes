package cmd

import (
	"fmt"
	"os"
	"path/filepath"

	"github.com/bxtal-lsn/kubernetes/cli/cmd/provision/embedded"
	"github.com/spf13/cobra"
)

var rootCmd = &cobra.Command{
	Use:   "provision",
	Short: "Infrastructure provisioning tool",
	Long: `A flexible CLI for provisioning and managing infrastructure components
such as Kubernetes clusters, PostgreSQL clusters, and more.`,
}

// Execute adds all child commands to the root command and sets flags appropriately.
func Execute() error {
	return rootCmd.Execute()
}

func init() {
	// Initialize commands
	rootCmd.AddCommand(provisionCmd)
	rootCmd.AddCommand(cleanupCmd)
	rootCmd.AddCommand(debugInventoryCmd)
}

// Display an error message and exit
func exitWithError(msg string, err error) {
	fmt.Fprintf(os.Stderr, "%s: %v\n", msg, err)
	os.Exit(1)
}

// Add to cmd/root.go

var debugInventoryCmd = &cobra.Command{
	Use:   "debug-inventory",
	Short: "Debug inventory file creation",
	Run: func(cmd *cobra.Command, args []string) {
		fmt.Println("Debugging inventory file creation...")

		// Initialize embedded resources
		tmpDir, err := embedded.Initialize()
		if err != nil {
			fmt.Printf("❌ Failed to initialize resources: %v\n", err)
			os.Exit(1)
		}
		defer embedded.Cleanup()

		fmt.Printf("Embedded resources extracted to: %s\n", tmpDir)

		// Create inventory directory
		inventoryDir := filepath.Join(tmpDir, "ansible", "inventories")
		fmt.Printf("Creating inventory directory: %s\n", inventoryDir)

		if err := os.MkdirAll(inventoryDir, 0o777); err != nil {
			fmt.Printf("❌ Failed to create directory: %v\n", err)
			os.Exit(1)
		}

		// Create a test file
		testFile := filepath.Join(inventoryDir, "test-file.txt")
		fmt.Printf("Creating test file: %s\n", testFile)

		if err := os.WriteFile(testFile, []byte("test content"), 0o666); err != nil {
			fmt.Printf("❌ Failed to write test file: %v\n", err)
			os.Exit(1)
		}

		// Verify file exists
		if _, err := os.Stat(testFile); os.IsNotExist(err) {
			fmt.Printf("❌ Test file doesn't exist after creation\n")
			os.Exit(1)
		}

		fmt.Printf("✅ Test file created successfully\n")
		fmt.Println("✅ Debug test passed!")
	},
}

// In init()
