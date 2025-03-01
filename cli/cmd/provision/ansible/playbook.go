package ansible

import (
	"fmt"
	"os"
	"os/exec"
)

// RunPlaybook executes an Ansible playbook with the given inventory and extra variables
func RunPlaybook(playbook, inventory string, extraArgs []string) error {
	// Check if ansible-playbook is available
	if _, err := exec.LookPath("ansible-playbook"); err != nil {
		return fmt.Errorf("ansible-playbook command not found: %w", err)
	}

	// Build the command
	args := []string{"-i", inventory}

	// Add any extra arguments
	args = append(args, extraArgs...)

	// Add the playbook at the end
	args = append(args, playbook)

	// Create the command
	cmd := exec.Command("ansible-playbook", args...)

	// Connect the command's outputs to our process's outputs
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin // Pass stdin for any prompts

	// Run the command
	fmt.Printf("Running: ansible-playbook %v\n", args)
	return cmd.Run()
}
