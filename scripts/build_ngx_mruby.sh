#!/usr/bin/env bash

set -euo pipefail

NGX_MRUBY_VERSION='2.2.3'
NGX_MRUBY_URL="https://github.com/matsumotory/ngx_mruby/archive/v${NGX_MRUBY_VERSION}.tar.gz"

echo "Building ngx_mruby v${NGX_MRUBY_VERSION} for ${STACK}"

BUILD_DIR=$(mktemp -d /tmp/ngx_mruby.XXXX)
SCRIPTS_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
OUTPUT_DIR="$(dirname "${SCRIPTS_DIR}")/archives/${STACK}"

mkdir -p "${OUTPUT_DIR}"
cd "${BUILD_DIR}"

echo "Downloading ngx_mruby from ${NGX_MRUBY_URL}"
curl -sSfL "${NGX_MRUBY_URL}" | tar -xz --strip-components 1

./build.sh
make install

echo 'nginx build complete!'

NGINX_BIN_DIR="${BUILD_DIR}/build/nginx/sbin"
cd "${NGINX_BIN_DIR}"

# Check that nginx can start
./nginx -v

NGINX_VERSION=$(./nginx -v |& cut -d '/' -f 2-)
ARCHIVE_PATH="${OUTPUT_DIR}/nginx-${NGINX_VERSION}-ngx_mruby-${NGX_MRUBY_VERSION}.tgz"

tar -czf "${ARCHIVE_PATH}" nginx

echo "Archive saved to: ${ARCHIVE_PATH}"
