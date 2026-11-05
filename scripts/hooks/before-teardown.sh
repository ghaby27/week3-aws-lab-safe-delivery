#!/usr/bin/env bash
# Run by onward-bootstrap/teardown.sh: empties the pipeline's artifact bucket so its stack
# can be deleted (ECR deletes its own images: EmptyOnDelete).
set -euo pipefail
export AWS_PROFILE=${AWS_PROFILE:-onward-logistics} AWS_REGION=${AWS_REGION:-eu-west-1}
bucket="onward-dev-delivery-artifacts-$(aws sts get-caller-identity --query Account --output text)"
if aws s3api head-bucket --bucket "$bucket" 2>/dev/null; then
  aws s3 rm "s3://$bucket" --recursive --quiet
  echo "  emptied $bucket"
fi
