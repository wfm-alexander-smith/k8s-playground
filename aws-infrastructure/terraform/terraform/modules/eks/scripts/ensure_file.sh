#!/bin/bash

# This script ensures the specified file exists with the specified content. It
# is useful when a provider expects a file to exist but the contents of that
# file need to have dynamic contents (using the local_file provider prevents
# plan from working before the first apply, so using this script with an
# external data provider fixes that.)

set -e

# Extract args from STDIN
eval "$(jq -r '@sh "FILENAME=\(.filename) CONTENT=\(.content)"')"

mkdir -p $(dirname $FILENAME)
echo "Writing kubeconfig to $FILENAME" >&2
echo "$CONTENT" > $FILENAME

# Output token as JSON
jq -n --arg filename "$FILENAME" '{"filename": $filename}'
