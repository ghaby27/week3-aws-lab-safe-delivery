#!/usr/bin/env bash
# Sends sales-day style traffic to the public address so the tasks' average CPU rises
# and target tracking adds tasks (2 -> 4). Stop it and the service scales back in.
# No shell access to the containers is needed (or possible): the load arrives the way
# real customers do, through the load balancer.
# Usage: scripts/cpu-load.sh [minutes=8] [clients=20]   (each client keeps 10 requests in flight)
set -uo pipefail
export AWS_PROFILE=${AWS_PROFILE:-onward-logistics} AWS_REGION=${AWS_REGION:-eu-west-1}
MINUTES=${1:-8}; CLIENTS=${2:-20}
URL=$(aws cloudformation describe-stacks --stack-name onward-dev-delivery-service \
  --query "Stacks[0].Outputs[?OutputKey=='AppUrl'].OutputValue" --output text)
end=$(( $(date +%s) + MINUTES * 60 ))
echo "Loading $URL with $CLIENTS clients x 10 parallel requests for $MINUTES minutes"
# Each round sends 500 page requests over reused connections, 10 at a time.
client() { while [ "$(date +%s)" -lt "$end" ]; do curl -s -Z --parallel-max 10 -m 10 "$URL/?r=[1-500]" >/dev/null; done; }
for _ in $(seq "$CLIENTS"); do client & done
trap 'kill $(jobs -p) 2>/dev/null; exit' INT
wait
echo "Load finished. Watch the service scale back in over the next few minutes:"
echo "  aws ecs describe-services --cluster onward-dev-delivery --services onward-dev-delivery-orders --query 'services[0].[desiredCount,runningCount]'"
