#!/usr/bin/env bash
# exit on error
set -o errexit

# Install Hex and Rebar
mix local.hex --force
mix local.rebar --force

# Install dependencies
mix deps.get --only prod

# Compile dependencies
MIX_ENV=prod mix deps.compile

# Compile application
MIX_ENV=prod mix compile

# Build assets (if any)
# MIX_ENV=prod mix assets.deploy

# Create release
MIX_ENV=prod mix release --overwrite
