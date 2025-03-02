package main

import (
	"fmt"
	"os"

	"github.com/bxtal-lsn/kubernetes/cli/cmd/provision/cmd"
	"github.com/bxtal-lsn/kubernetes/cli/cmd/provision/embedded"
)

func main() {
	// Extract embedded resources
	_, err := embedded.Initialize()
	if err != nil {
		fmt.Fprintf(os.Stderr, "Failed to initialize resources: %s\n", err)
		os.Exit(1)
	}
	// Clean up temporary files when done
	defer embedded.Cleanup()

	// Execute CLI
	if err := cmd.Execute(); err != nil {
		fmt.Fprintf(os.Stderr, "Error: %s\n", err)
		os.Exit(1)
	}
}

