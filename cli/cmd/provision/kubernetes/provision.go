package kubernetes

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"

	"github.com/bxtal-lsn/kubernetes/cli/cmd/provision/ansible"
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
	defaultsPath := "../../../ansible/defaults/kubernetes.yml"

	data, err := os.ReadFile(defaultsPath)
	if err != nil {
		return nil, fmt.Errorf("failed to read defaults file: %w", err)
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
	// Path to the shell script for Kubernetes provisioning
	provisionScriptPath := "../../../scripts/provision-kubernetes.sh"

	// Check if script exists
	if _, err := os.Stat(provisionScriptPath); os.IsNotExist(err) {
		return fmt.Errorf("provision script does not exist: %s", provisionScriptPath)
	}

	// Run the provision script
	cmd := exec.Command(provisionScriptPath)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin

	// Execute the provision script which handles Multipass VM creation
	if err := cmd.Run(); err != nil {
		return fmt.Errorf("failed to run provision script: %w", err)
	}

	// Continue with Ansible playbook
	inventory := "../../../ansible/inventories/kubernetes.yml"
	playbook := "../../../ansible/playbooks/kubernetes.yml"

	return ansible.RunPlaybook(playbook, inventory, []string{"-e", "@" + configPath})
}

// Cleanup handles Kubernetes cluster cleanup
func Cleanup() error {
	scriptPath := "../../../scripts/cleanup-kubernetes.sh"

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
