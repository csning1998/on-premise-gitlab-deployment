#!/usr/bin/env bash
set -euo pipefail

eval "$(jq -r '@sh "SECRET=\(.secret) SIGNING_INPUT=\(.signing_input)"')"

SIGNATURE=$(printf '%s' "$SIGNING_INPUT" | openssl dgst -sha512 -hmac "$SECRET" -binary | openssl base64 -A | tr '+/' '-_' | tr -d '=')

jq -n --arg signature "$SIGNATURE" '{"signature": $signature}'
