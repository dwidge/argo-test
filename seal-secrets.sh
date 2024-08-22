#!/bin/bash

if [[ ! -f ./cert.pem ]]; then
    echo "The key file 'cert.pem' does not exist."
    echo "You can obtain it by running this command on the server:"
    echo "kubeseal --fetch-cert > ./cert.pem"
    exit 1
fi

# Create the sealed-secrets directory if it doesn't exist
mkdir -p ./deploy/sealed-secrets

for file in ./deploy/secrets/*.yaml; do
    kubeseal --cert ./cert.pem < "$file" > "./deploy/sealed-secrets/$(basename "$file")"
done
