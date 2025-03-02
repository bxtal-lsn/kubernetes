// Package ansible provides utilities for working with Ansible
package ansible

import (
	"testing"
)

// TestAnsiblePlaybookExistence tests that the RunPlaybook function exists with the right signature
func TestAnsiblePlaybookExistence(t *testing.T) {
	// Just check that the function exists with the right signature
	var _ func(string, string, []string) error = RunPlaybook
}

