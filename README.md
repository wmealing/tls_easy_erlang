# tls-easy: Erlang TLS Distribution Template

`tls-easy` is a boilerplate project designed to jumpstart Erlang distribution deployments using modern TLS security without the overhead of complex container orchestration like Kubernetes. It is built for developers who prefer straight containers (Podman/Docker) and direct host management.

This project serves as a starting point for moving from simple local development to secure, multi-node Erlang clusters that can handle production-ready deployments and upgrades.

## Core Philosophy

- **No Kubernetes:** This project avoids the "K8s toolchain." It favors standard containers and predictable host environments.
- **Security by Default:** It automates the generation of a private CA and node-specific certificates using `tls-gen` (from the RabbitMQ team).
- **Consensus-Ready:** It includes a demo "HA" application that implements the Raft consensus protocol.

## The HA Application

The included `ha_app` is a demonstration of a highly available, consistent Erlang cluster.

- **3-Node Cluster:** By default, it deploys 3 nodes (`node1`, `node2`, `node3`).
- **Consensus:** Uses the `ra` library (Raft implementation) to maintain shared state across nodes.
- **Web Interface:** Each node exposes a web interface on a unique host port:
  - `node1`: `http://localhost:8081`
  - `node2`: `http://localhost:8082`
  - `node3`: `http://localhost:8083`
- **TLS Distribution:** The nodes communicate with each other over Erlang Distribution secured by TLS (port 25672 by default, though internal to the container network).

## Getting Started

### Prerequisites

- [Podman](https://podman.io/) (preferred) or Docker.
- Erlang/OTP (for local development, though not strictly required for container deployment).
- Python (required by `tls-gen` to generate certificates).

### Deployment

To build and deploy the 3-node cluster locally:

1. **Build the container image:**
   ```bash
   # Ensure you are in the ha_app directory to build the image
   cd ha_app
   podman build -t localhost/ha_app:latest .
   cd ..
   ```

2. **Run the deployment script:**
   ```bash
   ./deploy.sh
   ```
   The script will:
   - Generate a root CA and node-specific certificates.
   - Create Podman secrets for the CA, certificates, and SSL configuration.
   - Launch three containers connected via a private network (`ha_net`).

### Undeploying

To stop and remove the containers:

```bash
./undeploy.sh
```

## Moving to Production

This project is intended to be your first point of reference for Erlang distribution deployments. To adapt it for your own needs:

1. **Replace `ha_app`:** Swap the demo application with your own Erlang/Elixir project.
2. **Configuration:** Modify `ssl_dist.conf` and the `deploy.sh` script to match your environment's networking and security requirements.
3. **Upgrade Path:** Use this as a baseline for implementing rolling upgrades by updating the container image and restarting nodes one by one.

## Project Structure

- `ha_app/`: The Erlang source code for the Raft-based demo application.
- `tls-gen/`: (Generated) Tooling for certificate generation.
- `deploy.sh`: Orchestration script for certificate generation and container deployment.
- `ssl_dist.conf`: Template for Erlang TLS distribution settings.
- `Containerfile`: Defines the runtime environment for the Erlang nodes.
