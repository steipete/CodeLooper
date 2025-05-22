#!/bin/bash
# Script to set up Swift plugins directory structure

# Create parent directories if they don't exist
mkdir -p .swiftpm/configuration

# Create the registries configuration file
touch .swiftpm/configuration/registries.json
