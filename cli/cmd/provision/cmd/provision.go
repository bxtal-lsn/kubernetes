package cmd

import (
	"fmt"

	"github.com/bxtal-lsn/kubernetes/cli/cmd/provision/interactive"
	"github.com/bxtal-lsn/kubernetes/cli/cmd/provision/kubernetes"
	"github.com/spf13/cobra"
)

var provisionCmd = &cobra.Command{
	Use:   "provision",
	Short: "Provision infrastructure components",
	Long:  `Provision infrastructure components like Kubernetes clusters, PostgreSQL, etc.`,
	Run: func(cmd *cobra.Command, args []string) {
		provisionInteractive()
	},
}

func provisionInteractive() {
	options := []string{"Kubernetes Cluster", "PostgreSQL Cluster"}
	choice, err := interactive.PromptSelect("What would you like to provision?", options)
	if err != nil {
		exitWithError("Failed to get user input", err)
	}

	switch choice {
	case "Kubernetes Cluster":
		fmt.Println("Starting Kubernetes cluster provisioning...")
		if err := kubernetes.ProvisionInteractive(); err != nil {
			exitWithError("Failed to provision Kubernetes cluster", err)
		}
	default:
		fmt.Println("Invalid choice")
	}
}
