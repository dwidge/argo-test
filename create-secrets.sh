#!/bin/bash

# Prompt for GitHub Username
read -p "Enter your GitHub Username: " GITHUB_USER

# Prompt for GitHub Access Token
read -p "Enter your GitHub Access Token: " GITHUB_TOKEN

# Create or update the Kubernetes secret yaml
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

echo "github-registry-secret created or updated successfully."
