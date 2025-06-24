#!/bin/bash
set -e

echo "=== Starting deploy script in: $(pwd)"

cd ../frontend || { echo "Failed to cd ../frontend"; exit 1; }
echo "=== Now in: $(pwd)"

npm install

echo "=== Building the Vite app with VITE_API_URL=$VITE_API_URL ..."
VITE_API_URL=${VITE_API_URL} npm run build

echo "=== Listing dist folder contents..."
ls -l dist

echo "=== Done!"
