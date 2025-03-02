package multipass

import (
	"crypto/rand"
	"crypto/rsa"
	"crypto/x509"
	"encoding/pem"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"strings"

	"github.com/bxtal-lsn/kubernetes/cli/cmd/provision/embedded"
	"golang.org/x/crypto/ssh"
)

// CreateSSHKey generates a new SSH key pair
func CreateSSHKey() (string, string, error) {
	// Create temp directory for SSH keys
	sshDir := filepath.Join(embedded.TempDir, "ssh")
	if err := os.MkdirAll(sshDir, 0o700); err != nil {
		return "", "", fmt.Errorf("failed to create SSH directory: %w", err)
	}

	privateKeyPath := filepath.Join(sshDir, "id_rsa_provisioning")
	publicKeyPath := privateKeyPath + ".pub"

	// Generate private key
	privateKey, err := rsa.GenerateKey(rand.Reader, 4096)
	if err != nil {
		return "", "", fmt.Errorf("failed to generate private key: %w", err)
	}

	// Encode private key to PEM
	privateKeyPEM := &pem.Block{
		Type:  "RSA PRIVATE KEY",
		Bytes: x509.MarshalPKCS1PrivateKey(privateKey),
	}
	privateKeyFile, err := os.OpenFile(privateKeyPath, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, 0o600)
	if err != nil {
		return "", "", fmt.Errorf("failed to create private key file: %w", err)
	}
	if err := pem.Encode(privateKeyFile, privateKeyPEM); err != nil {
		privateKeyFile.Close()
		return "", "", fmt.Errorf("failed to write private key: %w", err)
	}
	privateKeyFile.Close()

	// Generate public key
	pub, err := ssh.NewPublicKey(&privateKey.PublicKey)
	if err != nil {
		return "", "", fmt.Errorf("failed to generate public key: %w", err)
	}
	pubKeyBytes := ssh.MarshalAuthorizedKey(pub)
	if err := os.WriteFile(publicKeyPath, pubKeyBytes, 0o644); err != nil {
		return "", "", fmt.Errorf("failed to write public key: %w", err)
	}

	return privateKeyPath, publicKeyPath, nil
}

// PrepareCloudInit prepares the cloud-init configuration
func PrepareCloudInit(sshPublicKeyPath string) (string, error) {
	// Read template
	templatePath := embedded.GetCloudInitPath("common.yaml")

	templateContent, err := os.ReadFile(templatePath)
	if err != nil {
		return "", fmt.Errorf("failed to read cloud-init template: %w", err)
	}

	// Read SSH public key
	sshPublicKey, err := os.ReadFile(sshPublicKeyPath)
	if err != nil {
		return "", fmt.Errorf("failed to read SSH public key: %w", err)
	}

	// Replace SSH key placeholder
	processedContent := strings.Replace(
		string(templateContent),
		"$SSH_PUBLIC_KEY",
		strings.TrimSpace(string(sshPublicKey)),
		-1,
	)

	// Write processed file
	processedPath := filepath.Join(embedded.TempDir, "multipass", "cloud-init", "common_processed.yaml")
	if err := os.WriteFile(processedPath, []byte(processedContent), 0o644); err != nil {
		return "", fmt.Errorf("failed to write processed cloud-init file: %w", err)
	}

	return processedPath, nil
}

// CreateVM creates a new VM using multipass
func CreateVM(name, cpus, memory, disk, cloudInitPath string) error {
	cmd := exec.Command(
		"multipass", "launch",
		"--name", name,
		"--cpus", cpus,
		"--memory", memory,
		"--disk", disk,
		"--cloud-init", cloudInitPath,
	)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

// DeleteVM deletes a VM
func DeleteVM(name string) error {
	cmd := exec.Command("multipass", "delete", name)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

// PurgeVMs purges deleted VMs
func PurgeVMs() error {
	cmd := exec.Command("multipass", "purge")
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	return cmd.Run()
}

// GetVMIP gets the IP address of a VM
func GetVMIP(name string) (string, error) {
	cmd := exec.Command("multipass", "info", name, "--format", "json")
	output, err := cmd.Output()
	if err != nil {
		return "", fmt.Errorf("failed to get VM info: %w", err)
	}

	// Parse the JSON output to extract IP
	// This is simplified and would need proper JSON parsing
	if strings.Contains(string(output), "ipv4") {
		// Extract IP from JSON (simplified approach)
		parts := strings.Split(string(output), "\"ipv4\":[\"")
		if len(parts) > 1 {
			ip := strings.Split(parts[1], "\"")[0]
			return ip, nil
		}
	}

	return "", fmt.Errorf("failed to extract IP from VM info")
}
