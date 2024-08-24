#!/bin/bash

# Copyright DWJ 2024.
# Distributed under the Boost Software License, Version 1.0.
# https://www.boost.org/LICENSE_1_0.txt

# Function to read input with a prompt and keep previous value if input is blank
read_input() {
  local prompt="$1"
  local current_value="$2"
  read -p "$prompt ($current_value): " input_value
  echo "${input_value:-$current_value}"
}

# Function to get GitHub secrets from a filename
get_github_secrets() {
  local filename="$1"
  if [ -f "$filename" ]; then
    # Extract the base64 encoded .dockerconfigjson and decode it
    local dockerconfigjson=$(grep '.dockerconfigjson:' "$filename" | awk '{print $2}')
    local decoded_json=$(echo "$dockerconfigjson" | base64 --decode)

    # Extract username and password from the decoded JSON
    GITHUB_USER=$(echo "$decoded_json" | jq -r '.auths."ghcr.io".username')
    GITHUB_TOKEN=$(echo "$decoded_json" | jq -r '.auths."ghcr.io".password')
  else
    GITHUB_USER=""
    GITHUB_TOKEN=""
  fi
}

# Function to write GitHub secrets to a file
write_github_secrets() {
  local filename="$1"
  local user="$2"
  local token="$3"
  cat <<EOF > "$filename"
apiVersion: v1
kind: Secret
metadata:
  name: github-registry-secret
  namespace: default
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: $(echo -n "{\"auths\":{\"ghcr.io\":{\"username\":\"$user\",\"password\":\"$token\"}}}" | base64 | tr -d '\n')
EOF
}

# Load existing values from the secret files if they exist
get_github_secrets "deploy/secrets/github-registry-secret.yaml"

if [ -f deploy/secrets/minio-secret.yaml ]; then
  MINIO_ROOT_USER=$(grep 'MINIO_ROOT_USER:' deploy/secrets/minio-secret.yaml | awk '{print $2}' | base64 --decode)
  MINIO_ROOT_PASSWORD=$(grep 'MINIO_ROOT_PASSWORD:' deploy/secrets/minio-secret.yaml | awk '{print $2}' | base64 --decode)
else
  MINIO_ROOT_USER=""
  MINIO_ROOT_PASSWORD=""
fi

# Prompt for GitHub Username
GITHUB_USER=$(read_input "Enter your GitHub Username" "$GITHUB_USER")

# Prompt for GitHub Access Token
GITHUB_TOKEN=$(read_input "Enter your GitHub Access Token" "$GITHUB_TOKEN")

# Prompt for Minio Root User
MINIO_ROOT_USER=$(read_input "Enter your Minio Root User" "$MINIO_ROOT_USER")

# Prompt for Minio Root Password
MINIO_ROOT_PASSWORD=$(read_input "Enter your Minio Root Password" "$MINIO_ROOT_PASSWORD")

# Check if GitHub information is provided
if [ -n "$GITHUB_USER" ] || [ -n "$GITHUB_TOKEN" ]; then
  # Create or update the Kubernetes secret yaml for GitHub
  write_github_secrets "deploy/secrets/github-registry-secret.yaml" "$GITHUB_USER" "$GITHUB_TOKEN"
fi

# Check if Minio information is provided
if [ -n "$MINIO_ROOT_USER" ] || [ -n "$MINIO_ROOT_PASSWORD" ]; then
  # Create or update the Kubernetes secret yaml for Minio
  cat <<EOF > deploy/secrets/minio-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: minio-secret
  namespace: default
type: Opaque
data:
  MINIO_ROOT_USER: $(echo -n "$MINIO_ROOT_USER" | base64 | tr -d '\n')
  MINIO_ROOT_PASSWORD: $(echo -n "$MINIO_ROOT_PASSWORD" | base64 | tr -d '\n')
EOF
fi

echo "Secrets created or updated successfully."