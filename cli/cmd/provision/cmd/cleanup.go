package cmd

import (
	"fmt"

	"github.com/bxtal-lsn/kubernetes/cli/cmd/provision/interactive"
	"github.com/bxtal-lsn/kubernetes/cli/cmd/provision/kubernetes"
	"github.com/spf13/cobra"
)

var cleanupCmd = &cobra.Command{
	Use:   "cleanup",
	Short: "Clean up provisioned resources",
	Long:  `Clean up provisioned infrastructure components like Kubernetes clusters, PostgreSQL, etc.`,
	Run: func(cmd *cobra.Command, args []string) {
		cleanupInteractive()
	},
}

func cleanupInteractive() {
	options := []string{"Kubernetes Cluster", "PostgreSQL Cluster"}
	choice, err := interactive.PromptSelect("What would you like to clean up?", options)
	if err != nil {
		exitWithError("Failed to get user input", err)
	}

	confirmed, err := interactive.PromptConfirm(fmt.Sprintf("Are you sure you want to clean up %s?", choice))
	if err != nil {
		exitWithError("Failed to get confirmation", err)
	}

	if !confirmed {
		fmt.Println("Cleanup cancelled")
		return
	}

	switch choice {
	case "Kubernetes Cluster":
		fmt.Println("Starting Kubernetes cluster cleanup...")
		if err := kubernetes.Cleanup(); err != nil {
			exitWithError("Failed to clean up Kubernetes cluster", err)
		}
	default:
		fmt.Println("Invalid choice")
	}

	fmt.Println("Cleanup completed successfully")
}
