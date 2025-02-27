#!/bin/bash
# cleanup-postgres.sh - Removes PostgreSQL testing environment

echo "Deleting PostgreSQL VMs..."
multipass delete pg-primary pg-replica1 pg-replica2 pg-lb
multipass purge

echo "Cleanup complete."
