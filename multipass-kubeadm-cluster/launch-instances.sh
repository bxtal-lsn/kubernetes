#!/bin/bash

if [ "$#" -eq 0 ]; then
    echo "Usage: $0 instance_name [instance_name2 ... instance_nameN]"
    exit 1
fi

# Iterate over all provided instance names
for INSTANCE in "$@"; do
    echo "Launching instance: ${INSTANCE}..."
    multipass launch --name "${INSTANCE}" --cloud-init cloudinit.yaml --disk 20G --memory 8G --cpus 2
done

