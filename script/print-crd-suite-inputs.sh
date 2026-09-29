#!/bin/sh
# Inferno does not call POST /auth/token. This script does, then prints the
# two CRD server suite fields. client_id is required by the token form and
# ignored by Capital.
set -eu

if [ -z "${CRD_SERVER_MACHINE_KEY:-}" ]; then
  echo "Set CRD_SERVER_MACHINE_KEY to the machine API key (admin machines list)." >&2
  exit 1
fi

if [ -z "${CAPITAL_ORIGIN:-}" ]; then
  echo "Set CAPITAL_ORIGIN to the web-capbluecross origin, with no path." >&2
  echo "In process-compose that is http://localhost:22041." >&2
  exit 1
fi

origin=$(printf '%s' "$CAPITAL_ORIGIN" | sed 's:/*$::')
body_file=$(mktemp)
trap 'rm -f "$body_file"' EXIT

status=$(
  curl --silent --show-error \
    --output "$body_file" \
    --write-out '%{http_code}' \
    --request POST \
    --header 'Content-Type: application/x-www-form-urlencoded' \
    --data-urlencode 'grant_type=client_credentials' \
    --data-urlencode 'client_id=crd-test-kit' \
    --data-urlencode "client_secret=${CRD_SERVER_MACHINE_KEY}" \
    "${origin}/auth/token"
)

if [ "$status" != "200" ]; then
  echo "POST ${origin}/auth/token returned ${status}" >&2
  cat "$body_file" >&2
  echo >&2
  exit 1
fi

CAPITAL_ORIGIN="$origin" python3 - "$body_file" <<'PY'
import json
import os
import sys
from urllib.parse import urlparse, urlunparse

body = json.load(open(sys.argv[1]))
origin = os.environ["CAPITAL_ORIGIN"]
parsed = urlparse(origin)
if parsed.hostname in ("localhost", "127.0.0.1"):
    host = "host.docker.internal"
    netloc = f"{host}:{parsed.port}" if parsed.port else host
    suite_origin = urlunparse(parsed._replace(netloc=netloc))
else:
    suite_origin = origin

print("Paste these into the CRD server suite. Discovery and order-sign share them.")
print()
print("CRD server base URL")
print(f"{suite_origin}/auth/fhir")
if suite_origin != origin:
    print("Inferno runs in Docker, so this host reaches the machine running capbluecross.")
    print("The suite sends X-Forwarded-* so the OAuth origin stays localhost.")
print()
print("Workspace bearer")
print(body["access_token"])
print()
print(f"expires_in {body['expires_in']}s. Inferno does not refresh this. Run this script again after a 401.")
print()
print("order-sign service id, when that group is run on its own")
print("order-sign-crd")
PY
