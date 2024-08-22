#!/bin/bash

# Copyright DWJ 2024.
# Distributed under the Boost Software License, Version 1.0.
# https://www.boost.org/LICENSE_1_0.txt

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
