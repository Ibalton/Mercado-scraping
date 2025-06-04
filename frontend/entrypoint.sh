#!/bin/sh
set -eu

: "${VITE_API_URL:?VITE_API_URL must be supplied in the task definition}"

echo "🔧 Injecting VITE_API_URL: ${VITE_API_URL}"

# patch every JS chunk in-place
find /srv -name '*.js' -exec \
  sed -i "s|__VITE_API_URL__|${VITE_API_URL}|g" {} +

echo "✅ Token replacement complete"
echo "🚀 Starting static file server..."

exec serve -s . -l 80