#!/usr/bin/env bash
# Run by onward-bootstrap/teardown.sh: empties the pipeline's artifact bucket and the
# nested-template bucket so their stacks can be deleted (ECR deletes its own images:
# EmptyOnDelete).
set -euo pipefail
export AWS_PROFILE=${AWS_PROFILE:-onward-logistics} AWS_REGION=${AWS_REGION:-eu-west-1}
account=$(aws sts get-caller-identity --query Account --output text)
for bucket in "onward-dev-delivery-artifacts-$account" "onward-dev-delivery-templates-$account"; do
  if aws s3api head-bucket --bucket "$bucket" 2>/dev/null; then
    aws s3 rm "s3://$bucket" --recursive --quiet
    echo "  emptied $bucket"
  fi
done
