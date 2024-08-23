#!/bin/bash

# Copyright DWJ 2024.
# Distributed under the Boost Software License, Version 1.0.
# https://www.boost.org/LICENSE_1_0.txt

# Color variables
YELLOW='\033[1;33m'
RESET='\033[0m'

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to check if a port is in use
port_in_use() {
    if command_exists lsof; then
        lsof -i:$1 >/dev/null 2>&1
    elif command_exists netstat; then
        netstat -an | grep ":$1 " >/dev/null 2>&1
    else
        echo "Neither lsof nor netstat is available to check port usage."
        return 1
    fi
}

# Function to find an available port starting from the default
find_open_port() {
    local desired_port=$1
    while port_in_use $desired_port; do
        desired_port=$((desired_port + 1))
    done
    echo $desired_port
}

# Check if Docker is installed
if ! command_exists docker; then
    echo "Docker is not installed. Please install Docker first."
    exit 1
fi

# Check if Docker is running
if ! docker info >/dev/null 2>&1; then
    echo "Docker is not running. Please start Docker."
    exit 1
fi

# Install k3d
if ! command_exists k3d; then
    echo "Installing k3d..."
    curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
fi

# Check if netstat is installed, if not, install it
if ! command_exists netstat; then
    echo "netstat is not installed. Installing net-tools..."
    sudo apt-get install -y net-tools
fi

# Install ArgoCD CLI
if ! command_exists argocd; then
    echo "Installing ArgoCD CLI..."
    curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64
    sudo install -m 555 argocd-linux-amd64 /usr/local/bin/argocd
    rm argocd-linux-amd64
fi

# Install kubeseal if not installed
if ! command_exists kubeseal; then
    echo "Installing kubeseal..."

    # Fetch the latest sealed-secrets version using GitHub API
    KUBESEAL_VERSION=$(curl -s https://api.github.com/repos/bitnami-labs/sealed-secrets/tags | jq -r '.[0].name' | cut -c 2-)

    # Check if the version was fetched successfully
    if [ -z "$KUBESEAL_VERSION" ]; then
        echo "Failed to fetch the latest KUBESEAL_VERSION"
        exit 1
    fi

    curl -OL "https://github.com/bitnami-labs/sealed-secrets/releases/download/v${KUBESEAL_VERSION}/kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz"
    tar -xvzf kubeseal-${KUBESEAL_VERSION}-linux-amd64.tar.gz kubeseal
    sudo install -m 755 kubeseal /usr/local/bin/kubeseal
fi

# Find an open port starting from the default
OPEN_PORT=$(find_open_port 8080)

# Ask for port to forward
while true; do
    read -p "Enter the port you want to forward ArgoCD to (default $OPEN_PORT): " PORT
    PORT=${PORT:-$OPEN_PORT}
    
    if ! port_in_use $PORT; then
        break
    else
        echo "Port $PORT is already in use. Please choose a different port."
    fi
done

# Ask for namespace
read -p "Enter the namespace for ArgoCD (default 'argocd'): " NAMESPACE
NAMESPACE=${NAMESPACE:-argocd}

# Ask for cluster name
read -p "Enter the cluster name (default 'mycluster'): " CLUSTER_NAME
CLUSTER_NAME=${CLUSTER_NAME:-mycluster}

# Ask for Git repository to link
read -p "Enter the Git repository URL to link with ArgoCD (default none): " REPO_URL

if [[ -n $REPO_URL ]]; then
    # Ask for the application's branch
    read -p "Enter the Git repository branch for the application (default 'main'): " BRANCH
    BRANCH=${BRANCH:-main}

    # Ask for the application name
    read -p "Enter the name of the application: " APP_NAME

    # Ask for the path in the repository
    read -p "Enter the path in the repository (default 'deploy'): " REPO_PATH
    REPO_PATH=${REPO_PATH:-deploy}

    # Ask for the target namespace
    read -p "Enter the target namespace (default 'default'): " TARGET_NAMESPACE
    TARGET_NAMESPACE=${TARGET_NAMESPACE:-default}
fi

# Check if the cluster already exists
if k3d cluster list | grep -qw "$CLUSTER_NAME"; then
    echo "Cluster '$CLUSTER_NAME' already exists, skipping cluster creation."
else
    # Create k3d cluster
    k3d cluster create "$CLUSTER_NAME" --servers 1 --agents 2

    # Validate cluster creation
    kubectl get nodes || { echo "Failed to create k3d cluster."; exit 1; }
fi

# Check if the namespace already exists
if kubectl get namespace $NAMESPACE >/dev/null 2>&1; then
    echo "Namespace '$NAMESPACE' already exists, skipping namespace creation."
else
    kubectl create namespace $NAMESPACE
fi

# Install ArgoCD
kubectl apply -n $NAMESPACE -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Get ArgoCD initial admin password
ARGO_PASSWORD=$(kubectl get secret argocd-initial-admin-secret -n $NAMESPACE -o jsonpath="{.data.password}" | base64 --decode)

# Output login information
echo "ArgoCD is now set up."
echo -e "Access ArgoCD at: ${YELLOW}http://localhost:$PORT${RESET}"
echo -e "Login with:"
echo -e "Username: ${YELLOW}admin${RESET}"
echo -e "Password: ${YELLOW}$ARGO_PASSWORD${RESET}"

# Port forward ArgoCD service
kubectl port-forward svc/argocd-server -n $NAMESPACE $PORT:443 &
PF_PID=$!

# Wait for ArgoCD server to be available
sleep 5

# Add the repository to ArgoCD if provided
if [[ -n $REPO_URL ]]; then
    argocd login localhost:$PORT --username admin --password $ARGO_PASSWORD --insecure
    if argocd repo add $REPO_URL; then
        echo -e "Repository $REPO_URL has been linked to ArgoCD."
    else
        echo -e "Failed to add the repository $REPO_URL to ArgoCD."
    fi

    # Create a new application
    argocd app create $APP_NAME \
        --repo $REPO_URL \
        --path $REPO_PATH \
        --dest-server https://kubernetes.default.svc \
        --dest-namespace $TARGET_NAMESPACE \
        --sync-policy automated \
        --revision $BRANCH \
        --directory-recurse

    if [ $? -eq 0 ]; then
        echo -e "${YELLOW}Application $APP_NAME has been created and is set to sync automatically.${RESET}"
    else
        echo -e "${YELLOW}Failed to create the application $APP_NAME.${RESET}"
    fi

fi

# Display the public key for kubeseal
echo -e "Retrieving the public key for kubeseal..."
echo -e "${YELLOW}"
kubeseal --fetch-cert --controller-name sealed-secrets --controller-namespace kube-system
kubeseal --fetch-cert --controller-name sealed-secrets --controller-namespace kube-system > sealed-secrets-public-cert.pem
echo -e "${RESET}"

# Bring the port forward process to the front
wait $PF_PID
