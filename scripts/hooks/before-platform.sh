#!/usr/bin/env bash
# Run by onward-bootstrap/deploy.sh before the platform root stack is synced. The platform
# needs two things the artifacts stack only holds the place for:
#   1. Its nested templates in the template bucket, under the TemplatesVersion that
#      infra/platform/deployment.yaml names. Normally publish-templates.yml uploads them;
#      after a teardown the bucket is new and empty, so upload them from this repository.
#   2. An image in ECR, or the ECS service cannot start. If there is no "latest" image, push
#      a build-* tag to the app repository so its workflow builds one, and wait for it.
# Set APP_REPO if the app repository is not cloned next to this one.
set -euo pipefail
export AWS_PROFILE=${AWS_PROFILE:-onward-logistics} AWS_REGION=${AWS_REGION:-eu-west-1}
HERE=$(cd "$(dirname "$0")/../.." && pwd)
APP_REPO=${APP_REPO:-$HERE/../aws-dev-associate-lab-app}
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
BUCKET=onward-dev-delivery-templates-$ACCOUNT
REPO=onward-dev-delivery-orders

# 1. Nested templates, exactly as committed on main (what Git sync will deploy).
git -C "$HERE" fetch -q origin main
version=$(git -C "$HERE" show origin/main:infra/platform/deployment.yaml | sed -n 's/^  TemplatesVersion: *//p')
tree=$(git -C "$HERE" rev-parse origin/main:infra/platform/stacks)
if [ "$version" != "$tree" ]; then
  echo "  TemplatesVersion ($version) does not match infra/platform/stacks on main ($tree)."
  echo "  Wait for the publish-templates workflow to commit the new version, then run deploy.sh again."
  exit 1
fi
if aws s3api head-object --bucket "$BUCKET" --key "$version/service.yaml" >/dev/null 2>&1; then
  echo "  nested templates $version are in $BUCKET"
else
  tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
  git -C "$HERE" archive origin/main infra/platform/stacks | tar -x -C "$tmp"
  aws s3 cp "$tmp/infra/platform/stacks/" "s3://$BUCKET/$version/" --recursive --quiet
  echo "  uploaded nested templates $version to $BUCKET"
fi

# 2. A first image for the service.
has_image() { aws ecr describe-images --repository-name $REPO --image-ids imageTag=latest >/dev/null 2>&1; }
if has_image; then echo "  image $REPO:latest exists"; exit 0; fi
git -C "$APP_REPO" fetch -q origin main
tag="build-$(date -u +%Y%m%d%H%M%S)"
git -C "$APP_REPO" push -q origin "$(git -C "$APP_REPO" rev-parse FETCH_HEAD):refs/tags/$tag"
echo "  pushed tag $tag to the app repository; waiting for GitHub Actions to push the image"
for _ in $(seq 1 60); do
  if has_image; then echo "  image $REPO:latest pushed"; exit 0; fi
  sleep 10
done
echo "  no image after 10 minutes - check the app repository's Actions tab"; exit 1
