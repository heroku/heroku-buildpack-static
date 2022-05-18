#!/usr/bin/env bash

set -euo pipefail

NGX_MRUBY_VERSION='2.2.4'
NGX_MRUBY_URL="https://github.com/matsumotory/ngx_mruby/archive/v${NGX_MRUBY_VERSION}.tar.gz"

echo "Building ngx_mruby v${NGX_MRUBY_VERSION} for ${STACK}"

BUILD_DIR=$(mktemp -d /tmp/ngx_mruby.XXXX)
SCRIPTS_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
OUTPUT_DIR="$(dirname "${SCRIPTS_DIR}")/archives/${STACK}"

mkdir -p "${OUTPUT_DIR}"
cd "${BUILD_DIR}"

echo "Downloading ngx_mruby from ${NGX_MRUBY_URL}"
curl -sSfL "${NGX_MRUBY_URL}" | tar -xz --strip-components 1

# Taken from the defaults:
# https://github.com/matsumotory/ngx_mruby/blob/v2.2.4/build.sh#L23-L40
BUILD_OPTS="--prefix=${PWD}/build/nginx"
BUILD_OPTS+=' --with-http_stub_status_module --with-stream --without-stream_access_module --with-cc-opt=-fno-common'
# Our custom addition, to enable the SSL module.
BUILD_OPTS+=' --with-http_ssl_module'

NGINX_CONFIG_OPT_ENV="${BUILD_OPTS}" ./build.sh
make install

echo 'nginx build complete!'

NGINX_BIN_DIR="${BUILD_DIR}/build/nginx/sbin"
cd "${NGINX_BIN_DIR}"

# Check that nginx can start
./nginx -V

# Check that OpenSSL support was enabled
./nginx -V |& grep 'built with OpenSSL' || { echo 'Missing OpenSSL support!'; exit 1; }

NGINX_VERSION=$(./nginx -v |& cut -d '/' -f 2-)
ARCHIVE_PATH="${OUTPUT_DIR}/nginx-${NGINX_VERSION}-ngx_mruby-${NGX_MRUBY_VERSION}.tgz"

tar -czf "${ARCHIVE_PATH}" nginx

echo "Archive saved to: ${ARCHIVE_PATH}"
