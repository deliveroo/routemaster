#!/usr/bin/env bash
# due to having two routemasters in one hopper app we need a way to
# set the redis url differently for some of them. this is how we do it.
set -e

export ROUTEMASTER_REDIS_URL=$ELASTICACHE_ROUTEMASTER_REDIS_URL
$@
