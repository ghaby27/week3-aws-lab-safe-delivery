#!/usr/bin/env bash
# Polls the order system twice a second and prints which task, AZ and version answered,
# or the HTTP error. Keep it running during a release, a task failure or an AZ test:
# a release with no downtime shows the version changing with no error lines.
# Usage: scripts/watch.sh [url]   (defaults to the service stack's AppUrl output)
set -uo pipefail
export AWS_PROFILE=${AWS_PROFILE:-onward-logistics} AWS_REGION=${AWS_REGION:-eu-west-1}
URL=${1:-$(aws cloudformation describe-stacks --stack-name onward-dev-delivery-platform \
  --query "Stacks[0].Outputs[?OutputKey=='AppUrl'].OutputValue" --output text)}
echo "Watching $URL/api/whoami (Ctrl+C to stop)"
ok=0; failed=0
trap 'echo; echo "ok=$ok failed=$failed"; exit' INT
while true; do
  body=$(curl -s -m 3 -w '\n%{http_code}' "$URL/api/whoami")
  code=${body##*$'\n'}; json=${body%$'\n'*}
  if [ "$code" = 200 ]; then
    ok=$((ok + 1))
    echo "$(date +%T) $(echo "$json" | python3 -c 'import json,sys; d=json.load(sys.stdin); print(d["version"], d["availability_zone"], d["instance_id"][:12])')"
  else
    failed=$((failed + 1)); echo "$(date +%T) FAILED http=$code"
  fi
  sleep 0.5
done
