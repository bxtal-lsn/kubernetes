package rqlite

import (
	"fmt"
	"os"
	"os/exec"
	"path/filepath"

	"github.com/bxtal-lsn/kubernetes/cli/cmd/provision/config"
	"github.com/bxtal-lsn/kubernetes/cli/cmd/provision/interactive"
	"gopkg.in/yaml.v3"
)

// Config holds rqlite cluster configuration
type Config struct {
	RqliteVersion    string   `yaml:"rqlite_version"`
	RqliteHttpPort   int      `yaml:"rqlite_http_port"`
	RqliteRaftPort   int      `yaml:"rqlite_raft_port"`
	RqliteDataDir    string   `yaml:"rqlite_data_dir"`
	RqliteExtractDir string   `yaml:"rqlite_extract_dir"`
	NodeCPUs         int      `yaml:"node_cpus"`
	NodeMemory       string   `yaml:"node_memory"`
	NodeDisk         string   `yaml:"node_disk"`
	DNSServers       []string `yaml:"dns_servers"`
}

// LoadDefaultConfig loads the default rqlite configuration from the defaults file
func LoadDefaultConfig() (*Config, error) {
	defaultsPath, err := config.GetAnsiblePath("defaults/rqlite.yml")
	if err != nil {
		return nil, fmt.Errorf("failed to locate defaults file: %w\n"+
			"Please make sure you are running the command from within the repository and that the ansible/defaults/rqlite.yml file exists", err)
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

// SaveConfig saves the rqlite configuration to a temporary file
func SaveConfig(config *Config) (string, error) {
	data, err := yaml.Marshal(config)
	if err != nil {
		return "", fmt.Errorf("failed to marshal config: %w", err)
	}

	// Create a temporary directory
	tmpDir, err := os.MkdirTemp("", "rqlite-provision")
	if err != nil {
		return "", fmt.Errorf("failed to create temp dir: %w", err)
	}

	// Write config to a file
	configPath := filepath.Join(tmpDir, "rqlite.yml")
	err = os.WriteFile(configPath, data, 0o644)
	if err != nil {
		return "", fmt.Errorf("failed to write config file: %w", err)
	}

	return configPath, nil
}

// ProvisionInteractive handles interactive rqlite cluster provisioning
func ProvisionInteractive() error {
	// Load default configuration
	defaultConfig, err := LoadDefaultConfig()
	if err != nil {
		// If the file doesn't exist, use hardcoded defaults
		defaultConfig = &Config{
			RqliteVersion:    "8.36.11",
			RqliteHttpPort:   4001,
			RqliteRaftPort:   4002,
			RqliteDataDir:    "/home/ubuntu/data",
			RqliteExtractDir: "/opt/rqlite",
			NodeCPUs:         2,
			NodeMemory:       "2G",
			NodeDisk:         "10G",
			DNSServers:       []string{"8.8.8.8", "8.8.4.4"},
		}
	}

	// Display default settings
	fmt.Println("\nCurrent default settings:")
	fmt.Printf("rqlite Version: %s\n", defaultConfig.RqliteVersion)
	fmt.Printf("HTTP Port: %d\n", defaultConfig.RqliteHttpPort)
	fmt.Printf("Raft Port: %d\n", defaultConfig.RqliteRaftPort)
	fmt.Printf("Node Resources: %d CPUs, %s Memory, %s Disk\n",
		defaultConfig.NodeCPUs,
		defaultConfig.NodeMemory,
		defaultConfig.NodeDisk)

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
		rqliteVersion, err := interactive.PromptText("rqlite Version", config.RqliteVersion)
		if err != nil {
			return err
		}
		config.RqliteVersion = rqliteVersion

		rqliteHttpPort, err := interactive.PromptInt("HTTP Port", config.RqliteHttpPort)
		if err != nil {
			return err
		}
		config.RqliteHttpPort = rqliteHttpPort

		rqliteRaftPort, err := interactive.PromptInt("Raft Port", config.RqliteRaftPort)
		if err != nil {
			return err
		}
		config.RqliteRaftPort = rqliteRaftPort

		// Node resources
		nodeCPUs, err := interactive.PromptIntWithRange("Node CPUs", config.NodeCPUs, 1, 16)
		if err != nil {
			return err
		}
		config.NodeCPUs = nodeCPUs

		nodeMemory, err := interactive.PromptText("Node Memory (e.g., 2G)", config.NodeMemory)
		if err != nil {
			return err
		}
		config.NodeMemory = nodeMemory

		nodeDisk, err := interactive.PromptText("Node Disk (e.g., 10G)", config.NodeDisk)
		if err != nil {
			return err
		}
		config.NodeDisk = nodeDisk
	}

	// Save configuration to a temporary file
	configPath, err := SaveConfig(config)
	if err != nil {
		return err
	}
	defer os.RemoveAll(filepath.Dir(configPath)) // Clean up temp dir when done

	// Confirm before proceeding
	fmt.Println("\nReady to provision rqlite cluster with the selected settings.")
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

// runProvisionScript runs the actual rqlite provisioning
func runProvisionScript(configPath string) error {
	// Get path to provision script
	scriptPath, err := config.GetScriptsPath("provision-rqlite.sh")
	if err != nil {
		return fmt.Errorf("failed to locate provision script: %w", err)
	}

	// Check if script exists
	if _, err := os.Stat(scriptPath); os.IsNotExist(err) {
		return fmt.Errorf("provision script does not exist: %s", scriptPath)
	}

	// Run the provision script with the config file
	cmd := exec.Command(scriptPath)
	cmd.Stdout = os.Stdout
	cmd.Stderr = os.Stderr
	cmd.Stdin = os.Stdin // Pass stdin for any prompts

	return cmd.Run()
}

// Cleanup handles rqlite cluster cleanup
func Cleanup() error {
	// Get path to cleanup script
	scriptPath, err := config.GetScriptsPath("cleanup-rqlite.sh")
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
