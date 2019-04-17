#!/bin/bash
set -e

# Extract args from STDIN
eval "$(jq -r '@sh "CERT=\(.cert) KEY=\(.key) PASS=\(.password)"')"

TMPDIR=$(mktemp -d)
[[ -n "$TMPDIR" ]] || exit 1

echo "$CERT" > $TMPDIR/cert.pem
echo "$KEY" > $TMPDIR/key.pem

pfx=$(openssl pkcs12 -export -inkey $TMPDIR/key.pem -in $TMPDIR/cert.pem -certfile $TMPDIR/cert.pem -passout pass:${PASS} | base64 -w0)

rm -r $TMPDIR

# Output pfx as JSON
jq -n --arg pfx "$pfx" '{"pfx": $pfx}'
