#!/usr/bin/env sh
# override redis url per service, in this case rider locations has its own redis
set -e

export ROUTEMASTER_REDIS_URL=$RIDERLOCATIONS_ROUTEMASTER_REDIS_URL
$@
