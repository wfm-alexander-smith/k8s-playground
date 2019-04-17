#!/bin/bash
set -e

# Extract cluster name from STDIN
eval "$(jq -r '@sh "CLUSTER_NAME=\(.cluster_name) AWS_PROFILE=\(.aws_profile)"')"

# Retrieve token with AWS IAM Authenticator
export AWS_PROFILE
TOKEN=$(aws-iam-authenticator token -i $CLUSTER_NAME | jq -r '.status.token')

# Output token as JSON
jq -n --arg token "$TOKEN" '{"token": $token}'
