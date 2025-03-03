package cmd

import (
	"fmt"
	"os"

	"github.com/spf13/cobra"
)

var rootCmd = &cobra.Command{
	Use:   "provision-cli",
	Short: "Kubernetes cluster provisioning tool",
	Long: `A simple CLI for provisioning and managing Kubernetes clusters on local VMs.
This tool must be run from the project root directory.`,
	Run: func(cmd *cobra.Command, args []string) {
		// If no subcommand is provided, show help
		cmd.Help()
	},
}

// Execute adds all child commands to the root command and sets flags appropriately
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
