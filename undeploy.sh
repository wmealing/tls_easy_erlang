#!/bin/bash

# Configuration
NUM_NODES=${1:-3}
NODE_NAMES=($(for i in $(seq 1 $NUM_NODES); do echo "node$i"; done))

echo "Undeploying $NUM_NODES nodes: ${NODE_NAMES[*]}"
podman rm -f "${NODE_NAMES[@]}"

