#!/bin/bash

# Check if the correct number of arguments are passed
if [[ "$#" -ne 2 ]]; then
    echo "Usage: $0 KEY NEW_VALUE"
    exit 1
fi

# Assign arguments to variables
key=$1
new_value=$2
env_file=".env"

# Check if the key exists in the file
if grep -q "^${key}=" "${env_file}"; then
    # If the key exists, update its value
    sed -i "s/^${key}=.*/${key}=${new_value}/" "${env_file}"
else
    # If the key does not exist

    # Add a new line before if needed
    if [[ -s "${env_file}" ]]; then
        last_char=$(tail -c 1 "${env_file}")
        if [[ -n "${last_char}" ]]; then
            echo "" >> "${env_file}"
        fi
    fi

    # Add the new key-value pair
    echo "${key}=${new_value}" >> "${env_file}"
fi