#!/bin/bash

set -euo pipefail

vers=$(egrep "our.*VERSION" bin/transposome | sed "s/^.* '//;s/'.*$//")
echo "=====> Building Docker image for Transposome v$vers"

#--build-arg LC_ALL=C
# build
docker build \
-t sestaton/transposome:$vers .

echo "=====> Tagging Docker image for Transposome v$vers"
# tag
docker tag sestaton/transposome:$vers sestaton/transposome:latest

echo "=====> Pushing Docker image for Transposome v$vers to Docker Hub"
# push
docker push sestaton/transposome:$vers
docker push sestaton/transposome:latest
