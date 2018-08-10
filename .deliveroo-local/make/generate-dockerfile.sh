#!/bin/bash

# This script generates a Dockerfile adds deliveroo-local-certs to the base
# Dockerfile. Ideally, we'd push out a base Routemaster image and fork from
# there.

dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
localdir="$( cd "${dir}/.." && pwd )"
app="$( cd "${dir}/../../" && pwd )"

# Add the certs image.
cat << "EOF" > ${localdir}/Dockerfile
FROM deliveroo/deliveroo-local-certs:latest as dev-certs
EOF

# List images.
echo "$(head -n2 ${app}/Dockerfile)" >> ${localdir}/Dockerfile

# Add certs.
cat << "EOF" >> ${localdir}/Dockerfile

# Copy the certs from the deliveroo-local-ca image.
COPY --from=dev-certs \
     /usr/share/ca-certificates/deliveroo-local-ca.crt \
     /usr/share/ca-certificates/deliveroo-local-ca.crt

# Add the ca-cert to the store.
RUN echo "deliveroo-local-ca.crt" >> /etc/ca-certificates.conf && \
    update-ca-certificates --fresh
EOF

# Include the rest of the Dockerfile.
echo "$(tail -n +3 ${app}/Dockerfile)" >> ${localdir}/Dockerfile
