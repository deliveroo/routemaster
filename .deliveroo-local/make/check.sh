#!/bin/bash

# Ensure that the URL returns a 200.
healthcheck() {
  printf "Waiting for $1 ..."
  n=0
  for i in {1..15}; do
    status=$(curl -s -o /dev/null -w '%{http_code}' $1)
    if test ${status} -eq 200; then
      break
    fi
    printf "." && sleep 1;
  done
  printf " done\n"
}

healthcheck https://routemaster.deliveroo-local.com/health
