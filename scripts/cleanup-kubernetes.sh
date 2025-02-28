#!/bin/bash
# cleanup-kubernetes.sh - Removes Kubernetes testing environment

echo "Deleting Kubernetes VMs..."
multipass delete controlplane node01 node02 node03
multipass purge

echo "Cleanup complete."
