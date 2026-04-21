#!/bin/bash

# Configuration
NUM_NODES=${1:-3}
NODE_NAMES=($(for i in $(seq 1 $NUM_NODES); do echo "node$i"; done))
COOKIE="my_secret_cookie"
IMAGE="localhost/ha_app:latest"
VERSION="v1"

# --- macOS Compatibility: Get Local IP ---
# This finds the active local IP address on macOS
LOCAL_IP=$(ifconfig | grep "inet " | grep -v 127.0.0.1 | awk '{print $2}' | head -n1)

if [ -z "$LOCAL_IP" ]; then
    echo "Error: Could not determine LOCAL_IP"
    exit 1
fi
echo "Using LOCAL_IP: $LOCAL_IP"
echo "Deploying $NUM_NODES nodes: ${NODE_NAMES[*]}"


# 1. Setup Generator
if [ ! -d "tls-gen" ]; then
    git clone https://github.com/rabbitmq/tls-gen.git
fi

# 2. Build the Common CA
cd tls-gen/basic
make clean
make PASSWORD= 
cd ../..

# 3. Create Shared Secrets
podman secret rm "erl_ca_$VERSION" || true
podman secret create "erl_ca_$VERSION" ./tls-gen/basic/result/ca_certificate.pem || true

cat <<EOF > ./ssl_dist.conf
[{server,
  [{cacertfile, "/etc/erlang/certs/ca_certificate.pem"},
   {certfile,   "/etc/erlang/certs/node.pem"},
   {keyfile,    "/etc/erlang/certs/node.key"},
   {secure_renegotiate, true},
   {verify, verify_peer},
   {fail_if_no_peer_cert, true}]},
 {client,
  [{cacertfile, "/etc/erlang/certs/ca_certificate.pem"},
   {certfile,   "/etc/erlang/certs/node.pem"},
   {keyfile,    "/etc/erlang/certs/node.key"},
   {secure_renegotiate, true},
   {verify, verify_peer}]}].
EOF
podman secret rm "erl_conf_$VERSION" || true
podman secret create "erl_conf_$VERSION" ./ssl_dist.conf || true

# 4. Calculate HA_NODES list
HA_NODES_LIST=""
for NAME in "${NODE_NAMES[@]}"; do
    HA_NODES_LIST="${HA_NODES_LIST}${NAME}@${NAME},"
done
HA_NODES_LIST=${HA_NODES_LIST%,} # Remove trailing comma
echo "HA_NODES: $HA_NODES_LIST"

# 5. Generate Unique Certs and Start Containers
START_PORT=8081
for INDEX in "${!NODE_NAMES[@]}"; do
    NAME="${NODE_NAMES[$INDEX]}"
    echo "--- Provisioning $NAME ---"

    cd tls-gen/basic
    # Generate node-specific certs using the same CA
    make gen-server CN=$NAME PASSWORD=
    make gen-client CN=$NAME PASSWORD=

    # Path: ./result/server_${NAME}_certificate.pem
    CERT_PATH="./result/server_${NAME}_certificate.pem"
    KEY_PATH="./result/server_${NAME}_key.pem"

    if [ ! -f "$CERT_PATH" ]; then
        echo "Error: Certificate generation failed for $NAME"
        echo "Looked for: $CERT_PATH"
        exit 1
    fi
    cd ../..


    # Remove and recreate secrets to ensure fresh state
    podman secret rm "${NAME}_cert" || true
    podman secret rm "${NAME}_key" || true
    podman secret create "${NAME}_cert" "./tls-gen/basic/$CERT_PATH" || true
    podman secret create "${NAME}_key" "./tls-gen/basic/$KEY_PATH" || true

    # Calculate mapped port for host access (node1->8081, node2->8082, node3->8083, ...)
    MAPPED_PORT=$((START_PORT + INDEX))

    podman run -d \
      --name "$NAME" \
      --hostname "$NAME" \
      --network ha_net \
      -p "$MAPPED_PORT:8080" \
      --secret "erl_ca_$VERSION,target=/etc/erlang/certs/ca_certificate.pem" \
      --secret "${NAME}_cert,target=/etc/erlang/certs/node.pem" \
      --secret "${NAME}_key,target=/etc/erlang/certs/node.key" \
      --secret "erl_conf_$VERSION,target=/etc/erlang/certs/ssl_dist.conf" \
      -e ERL_FLAGS="-proto_dist inet_tls -ssl_dist_optfile /etc/erlang/certs/ssl_dist.conf" \
      -e HA_NODES="$HA_NODES_LIST" \
      "$IMAGE" \
      sh -c "erl -sname ${NAME} \
          -setcookie $COOKIE \
          -pa lib/*/ebin \
          -ra data_dir '\"data/${NAME}\"' \
          -noshell \
          -eval 'application:ensure_all_started(ha_app), timer:sleep(infinity).'"
done
