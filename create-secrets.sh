#!/bin/bash

# Copyright DWJ 2024.
# Distributed under the Boost Software License, Version 1.0.
# https://www.boost.org/LICENSE_1_0.txt

# Prompt for GitHub Username
read -p "Enter your GitHub Username: " GITHUB_USER

# Prompt for GitHub Access Token
read -p "Enter your GitHub Access Token: " GITHUB_TOKEN

# Prompt for Minio Root User
read -p "Enter your Minio Root User: " MINIO_ROOT_USER

# Prompt for Minio Root Password
read -p "Enter your Minio Root Password: " MINIO_ROOT_PASSWORD

# Create or update the Kubernetes secret yaml for GitHub
cat <<EOF > deploy/secrets/github-registry-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: github-registry-secret
  namespace: default
type: kubernetes.io/dockerconfigjson
data:
  .dockerconfigjson: $(echo -n "{\"auths\":{\"ghcr.io\":{\"username\":\"$GITHUB_USER\",\"password\":\"$GITHUB_TOKEN\"}}}" | base64 | tr -d '\n')
EOF

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

echo "github-registry-secret and minio-secret created or updated successfully."
