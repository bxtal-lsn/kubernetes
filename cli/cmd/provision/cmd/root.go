package cmd

import (
	"fmt"
	"os"

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
}

// Display an error message and exit
func exitWithError(msg string, err error) {
	fmt.Fprintf(os.Stderr, "%s: %v\n", msg, err)
	os.Exit(1)
}
