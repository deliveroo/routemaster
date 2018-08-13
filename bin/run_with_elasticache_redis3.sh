#!/usr/bin/env sh
# allows setting the redis url per-service
set -e

export ROUTEMASTER_REDIS_URL=$ELASTICACHE3_ROUTEMASTER_REDIS_URL
$@
