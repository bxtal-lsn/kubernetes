package kubernetes

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"

	"github.com/bxtal-lsn/kubernetes/cli/cmd/provision/ansible"
	"github.com/bxtal-lsn/kubernetes/cli/cmd/provision/config"
	"github.com/bxtal-lsn/kubernetes/cli/cmd/provision/embedded"
	"github.com/bxtal-lsn/kubernetes/cli/cmd/provision/interactive"
	"gopkg.in/yaml.v3"
)

// Config holds Kubernetes cluster configuration
type Config struct {
	KubernetesVersion  string   `yaml:"kubernetes_version"`
	PodCIDR            string   `yaml:"pod_cidr"`
	ServiceCIDR        string   `yaml:"service_cidr"`
	CNIPlugin          string   `yaml:"cni_plugin"`
	CalicoVersion      string   `yaml:"calico_version"`
	ControlPlaneCPUs   int      `yaml:"control_plane_cpus"`
	ControlPlaneMemory string   `yaml:"control_plane_memory"`
	ControlPlaneDisk   string   `yaml:"control_plane_disk"`
	WorkerCPUs         int      `yaml:"worker_cpus"`
	WorkerMemory       string   `yaml:"worker_memory"`
	WorkerDisk         string   `yaml:"worker_disk"`
	DNSServers         []string `yaml:"dns_servers"`
	KubernetesPackages []string `yaml:"kubernetes_packages"`
}

// LoadDefaultConfig loads the default Kubernetes configuration from the defaults file
func LoadDefaultConfig() (*Config, error) {
	defaultsPath, err := config.GetAnsiblePath("defaults/kubernetes.yml")
	if err != nil {
		return nil, fmt.Errorf("failed to locate defaults file: %w\n"+
			"Please make sure you are running the command from within the repository and that the ansible/defaults/kubernetes.yml file exists", err)
	}

	data, err := os.ReadFile(defaultsPath)
	if err != nil {
		return nil, fmt.Errorf("failed to read defaults file at %s: %w\n"+
			"Please check file permissions and that the repository is correctly cloned", defaultsPath, err)
	}

	config := &Config{}
	err = yaml.Unmarshal(data, config)
	if err != nil {
		return nil, fmt.Errorf("failed to parse defaults file: %w", err)
	}

	return config, nil
}

// SaveConfig saves the Kubernetes configuration to a temporary file
func SaveConfig(config *Config) (string, error) {
	data, err := yaml.Marshal(config)
	if err != nil {
		return "", fmt.Errorf("failed to marshal config: %w", err)
	}

	// Create a temporary directory
	tmpDir, err := os.MkdirTemp("", "k8s-provision")
	if err != nil {
		return "", fmt.Errorf("failed to create temp dir: %w", err)
	}

	// Write config to a file
	configPath := filepath.Join(tmpDir, "kubernetes.yml")
	err = os.WriteFile(configPath, data, 0o644)
	if err != nil {
		return "", fmt.Errorf("failed to write config file: %w", err)
	}

	return configPath, nil
}

// ProvisionInteractive handles interactive Kubernetes cluster provisioning
func ProvisionInteractive() error {
	// Load default configuration
	defaultConfig, err := LoadDefaultConfig()
	if err != nil {
		return err
	}

	// Display default settings
	fmt.Println("\nCurrent default settings:")
	fmt.Printf("Kubernetes Version: %s\n", defaultConfig.KubernetesVersion)
	fmt.Printf("Pod CIDR: %s\n", defaultConfig.PodCIDR)
	fmt.Printf("Service CIDR: %s\n", defaultConfig.ServiceCIDR)
	fmt.Printf("CNI Plugin: %s\n", defaultConfig.CNIPlugin)
	fmt.Printf("Control Plane: %d CPUs, %s Memory, %s Disk\n",
		defaultConfig.ControlPlaneCPUs,
		defaultConfig.ControlPlaneMemory,
		defaultConfig.ControlPlaneDisk)
	fmt.Printf("Worker Nodes: %d CPUs, %s Memory, %s Disk\n",
		defaultConfig.WorkerCPUs,
		defaultConfig.WorkerMemory,
		defaultConfig.WorkerDisk)

	// Ask if user wants to use default settings
	useDefaults, err := interactive.PromptConfirm("Do you want to use these default settings?")
	if err != nil {
		return err
	}

	var config *Config
	if useDefaults {
		config = defaultConfig
	} else {
		config = defaultConfig // Start with defaults

		// Ask for each configurable value
		k8sVersion, err := interactive.PromptText("Kubernetes Version", config.KubernetesVersion)
		if err != nil {
			return err
		}
		config.KubernetesVersion = k8sVersion

		podCIDR, err := interactive.PromptText("Pod CIDR", config.PodCIDR)
		if err != nil {
			return err
		}
		config.PodCIDR = podCIDR

		serviceCIDR, err := interactive.PromptText("Service CIDR", config.ServiceCIDR)
		if err != nil {
			return err
		}
		config.ServiceCIDR = serviceCIDR

		cniPlugin, err := interactive.PromptSelect("CNI Plugin", []string{"calico", "flannel"})
		if err != nil {
			return err
		}
		config.CNIPlugin = cniPlugin

		if cniPlugin == "calico" {
			calicoVersion, err := interactive.PromptText("Calico Version", config.CalicoVersion)
			if err != nil {
				return err
			}
			config.CalicoVersion = calicoVersion
		}

		// Control plane resources
		cpCPUs, err := interactive.PromptIntWithRange("Control Plane CPUs", config.ControlPlaneCPUs, 1, 16)
		if err != nil {
			return err
		}
		config.ControlPlaneCPUs = cpCPUs

		cpMemory, err := interactive.PromptText("Control Plane Memory (e.g., 4G)", config.ControlPlaneMemory)
		if err != nil {
			return err
		}
		config.ControlPlaneMemory = cpMemory

		cpDisk, err := interactive.PromptText("Control Plane Disk (e.g., 20G)", config.ControlPlaneDisk)
		if err != nil {
			return err
		}
		config.ControlPlaneDisk = cpDisk

		// Worker resources
		workerCPUs, err := interactive.PromptIntWithRange("Worker CPUs", config.WorkerCPUs, 1, 16)
		if err != nil {
			return err
		}
		config.WorkerCPUs = workerCPUs

		workerMemory, err := interactive.PromptText("Worker Memory (e.g., 2G)", config.WorkerMemory)
		if err != nil {
			return err
		}
		config.WorkerMemory = workerMemory

		workerDisk, err := interactive.PromptText("Worker Disk (e.g., 20G)", config.WorkerDisk)
		if err != nil {
			return err
		}
		config.WorkerDisk = workerDisk

		// Split by comma and trim whitespace
		config.DNSServers = []string{}
		for _, server := range defaultConfig.DNSServers {
			config.DNSServers = append(config.DNSServers, server)
		}
	}

	// Save configuration to a temporary file
	configPath, err := SaveConfig(config)
	if err != nil {
		return err
	}
	defer os.RemoveAll(filepath.Dir(configPath)) // Clean up temp dir when done

	// Confirm before proceeding
	fmt.Println("\nReady to provision Kubernetes cluster with the selected settings.")
	proceed, err := interactive.PromptConfirm("Do you want to proceed?")
	if err != nil {
		return err
	}

	if !proceed {
		fmt.Println("Provisioning cancelled.")
		return nil
	}

	// Run the provision script
	fmt.Println("Running provisioning script...")
	return runProvisionScript(configPath)
}

// runProvisionScript runs the actual Kubernetes provisioning
func runProvisionScript(configPath string) error {
	fmt.Println("Starting VM provisioning process...")

	// Get playbook path only (don't check inventory yet)
	playbook, err := config.GetAnsiblePath("playbooks/kubernetes.yml")
	if err != nil {
		return fmt.Errorf("failed to locate playbook file: %w", err)
	}

	// Check if playbook exists
	if _, err := os.Stat(playbook); os.IsNotExist(err) {
		return fmt.Errorf("playbook file does not exist: %s", playbook)
	}

	// Create inventory file
	fmt.Println("Creating inventory file...")
	inventoryPath, err := ForceCreateInventory()
	if err != nil {
		return fmt.Errorf("failed to create inventory: %w", err)
	}

	// Check the inventory file path AFTER creating it
	fmt.Printf("Using inventory path: %s\n", inventoryPath)
	if _, err := os.Stat(inventoryPath); os.IsNotExist(err) {
		return fmt.Errorf("inventory file does not exist after creation: %s", inventoryPath)
	}

	// Run ansible-playbook
	return ansible.RunPlaybook(playbook, inventoryPath, []string{"-e", "@" + configPath})
}

// Cleanup handles Kubernetes cluster cleanup
func Cleanup() error {
	// Get path to cleanup script
	scriptPath, err := config.GetScriptsPath("cleanup-kubernetes.sh")
	if err != nil {
		return fmt.Errorf("failed to locate cleanup script: %w", err)
	}

	// Check if script exists
	if _, err := os.Stat(scriptPath); os.IsNotExist(err) {
		return fmt.Errorf("cleanup script does not exist: %s", scriptPath)
	}

	// Run the cleanup script
	cmd := exec.Command(scriptPath)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin // Pass stdin for any prompts

	return cmd.Run()
}

// In kubernetes/provision.go, add or modify the createInventory function:
func createInventory(controlPlaneIP, node01IP, node02IP, node03IP, sshKeyPath string) (string, error) {
	// Define the inventory file path
	inventoryDir := filepath.Join(embedded.TempDir, "ansible", "inventories")
	inventoryPath := filepath.Join(inventoryDir, "kubernetes.yml")

	// Create the directory explicitly
	if err := os.MkdirAll(inventoryDir, 0o755); err != nil {
		return "", fmt.Errorf("failed to create inventory directory: %w", err)
	}

	// Create inventory content
	inventoryContent := fmt.Sprintf(`---
all:
  children:
    k8s_cluster:
      children:
        control_plane:
          hosts:
            controlplane:
              ansible_host: %s
        workers:
          hosts:
            node01:
              ansible_host: %s
            node02:
              ansible_host: %s
            node03:
              ansible_host: %s
  vars:
    ansible_user: ubuntu
    ansible_become: yes
    ansible_ssh_private_key_file: %s
    ansible_ssh_common_args: '-o StrictHostKeyChecking=no'
`, controlPlaneIP, node01IP, node02IP, node03IP, sshKeyPath)

	// Write the inventory file
	if err := os.WriteFile(inventoryPath, []byte(inventoryContent), 0o644); err != nil {
		return "", fmt.Errorf("failed to write inventory file: %w", err)
	}

	// Verify the file was created
	if _, err := os.Stat(inventoryPath); os.IsNotExist(err) {
		return "", fmt.Errorf("inventory file was not created at %s", inventoryPath)
	}

	fmt.Printf("Created inventory file at: %s\n", inventoryPath)
	return inventoryPath, nil
}

// ForceCreateInventory creates the inventory file directly at the expected location
func ForceCreateInventory() (string, error) {
	// Define the inventory file path - use embedded.TempDir as the base
	inventoryDir := filepath.Join(embedded.TempDir, "ansible", "inventories")
	inventoryPath := filepath.Join(inventoryDir, "kubernetes.yml")

	fmt.Printf("Creating inventory directory: %s\n", inventoryDir)

	// Create the directory with full permissions
	if err := os.MkdirAll(inventoryDir, 0o777); err != nil {
		return "", fmt.Errorf("failed to create inventory directory: %w", err)
	}

	// Dummy values for testing
	controlPlaneIP := "192.168.64.10"
	node01IP := "192.168.64.11"
	node02IP := "192.168.64.12"
	node03IP := "192.168.64.13"
	sshKeyPath := "/tmp/dummy_ssh_key"

	// Create inventory content
	inventoryContent := fmt.Sprintf(`---
all:
  children:
    k8s_cluster:
      children:
        control_plane:
          hosts:
            controlplane:
              ansible_host: %s
        workers:
          hosts:
            node01:
              ansible_host: %s
            node02:
              ansible_host: %s
            node03:
              ansible_host: %s
  vars:
    ansible_user: ubuntu
    ansible_become: yes
    ansible_ssh_private_key_file: %s
    ansible_ssh_common_args: '-o StrictHostKeyChecking=no'
`, controlPlaneIP, node01IP, node02IP, node03IP, sshKeyPath)

	fmt.Printf("Writing inventory file to: %s\n", inventoryPath)

	// Write the inventory file
	if err := os.WriteFile(inventoryPath, []byte(inventoryContent), 0o666); err != nil {
		return "", fmt.Errorf("failed to write inventory file: %w", err)
	}

	// Double check the file was created
	if _, err := os.Stat(inventoryPath); os.IsNotExist(err) {
		return "", fmt.Errorf("inventory file was not created at %s", inventoryPath)
	}

	fmt.Printf("Inventory file successfully created at: %s\n", inventoryPath)

	// Additional verification - try to read it back
	content, err := os.ReadFile(inventoryPath)
	if err != nil {
		return "", fmt.Errorf("could not read back inventory file: %w", err)
	}

	fmt.Printf("Inventory file content length: %d bytes\n", len(content))

	return inventoryPath, nil
}
