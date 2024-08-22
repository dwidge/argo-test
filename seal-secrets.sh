#!/bin/bash

# Copyright DWJ 2024.
# Distributed under the Boost Software License, Version 1.0.
# https://www.boost.org/LICENSE_1_0.txt

if [[ ! -f ./sealed-secrets-public-cert.pem ]]; then
    echo "The key file 'sealed-secrets-public-cert.pem' does not exist."
    echo "You can obtain it by running this command on the server:"
    echo "kubeseal --fetch-cert > ./sealed-secrets-public-cert.pem"
    exit 1
fi

# Create the sealed-secrets directory if it doesn't exist
mkdir -p ./deploy/sealed-secrets

for file in ./deploy/secrets/*.yaml; do
    kubeseal --cert ./sealed-secrets-public-cert.pem < "$file" > "./deploy/sealed-secrets/$(basename "$file")"
done
