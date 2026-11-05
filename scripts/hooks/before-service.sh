#!/usr/bin/env bash
# Run by onward-bootstrap/deploy.sh before the service layer: the ECS service needs an image
# in ECR to start. If the repository has no "latest" image (first build or after a teardown),
# push a build-* tag to the app repository so its GitHub Actions workflow builds and pushes
# one, then wait for it. Set APP_REPO if the app repository is not cloned next to this one.
set -euo pipefail
export AWS_PROFILE=${AWS_PROFILE:-onward-logistics} AWS_REGION=${AWS_REGION:-eu-west-1}
REPO=onward-dev-delivery-orders
APP_REPO=${APP_REPO:-$(git rev-parse --show-toplevel)/../aws-dev-associate-lab-app}

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
