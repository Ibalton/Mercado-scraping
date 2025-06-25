#!/bin/sh
set -eu

: "${VITE_API_URL:?VITE_API_URL must be supplied in the task definition}"
: "${VITE_COGNITO_POOL_ID:?VITE_COGNITO_POOL_ID must be supplied}"
: "${VITE_COGNITO_CLIENT_ID:?VITE_COGNITO_CLIENT_ID must be supplied}"
: "${VITE_COGNITO_REGION:?VITE_COGNITO_REGION must be supplied}"
: "${VITE_COGNITO_DOMAIN:?VITE_COGNITO_DOMAIN must be supplied}"
: "${VITE_COGNITO_REDIRECT_URI:?VITE_COGNITO_REDIRECT_URI must be supplied}"

echo "🔧 Injecting VITE_API_URL: ${VITE_API_URL}"
echo "🔧 Injecting VITE_COGNITO_POOL_ID: ${VITE_COGNITO_POOL_ID}"
echo "🔧 Injecting VITE_COGNITO_CLIENT_ID: ${VITE_COGNITO_CLIENT_ID}"
echo "🔧 Injecting VITE_COGNITO_REGION: ${VITE_COGNITO_REGION}"
echo "🔧 Injecting VITE_COGNITO_DOMAIN: ${VITE_COGNITO_DOMAIN}"
echo "🔧 Injecting VITE_COGNITO_REDIRECT_URI: ${VITE_COGNITO_REDIRECT_URI}"
echo "🔧 Injecting VITE_COGNITO_LOGOUT_URI: ${VITE_COGNITO_LOGOUT_URI}"

# patch every JS chunk in-place
find /srv -name '*.js' -exec \
  sed -i "s|__VITE_API_URL__|${VITE_API_URL}|g" {} +
find /srv -name '*.js' -exec \
  sed -i "s|__VITE_COGNITO_POOL_ID__|${VITE_COGNITO_POOL_ID}|g" {} +
find /srv -name '*.js' -exec \
  sed -i "s|__VITE_COGNITO_CLIENT_ID__|${VITE_COGNITO_CLIENT_ID}|g" {} +
find /srv -name '*.js' -exec \
  sed -i "s|__VITE_COGNITO_REGION__|${VITE_COGNITO_REGION}|g" {} +
find /srv -name '*.js' -exec \
  sed -i "s|__VITE_COGNITO_DOMAIN__|${VITE_COGNITO_DOMAIN}|g" {} +
find /srv -name '*.js' -exec \
  sed -i "s|__VITE_COGNITO_LOGOUT_URI__|${VITE_COGNITO_LOGOUT_URI}|g" {} +
find /srv -name '*.js' -exec \
  sed -i "s|__VITE_COGNITO_REDIRECT_URI__|${VITE_COGNITO_REDIRECT_URI}|g" {} +

echo "✅ Token replacement complete"
echo "🚀 Starting static file server..."

exec serve -s . -l 80 --no-clipboard