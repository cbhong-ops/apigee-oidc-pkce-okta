#!/bin/bash

# Exit on error
set -e

# Source environment variables
if [ -f "./env.sh" ]; then
  source ./env.sh
else
  echo "Error: env.sh file not found."
  exit 1
fi

PROXY_NAME="oidc-okta"

if [ -z "$APIGEE_ORG" ] || [ -z "$APIGEE_ENV" ]; then
  echo "Error: Please set APIGEE_ORG, APIGEE_ENV in env.sh."
  exit 1
fi

echo "============================================================"
echo "Deploying API Proxy: $PROXY_NAME"
echo "Org: $APIGEE_ORG"
echo "Env: $APIGEE_ENV"
echo "============================================================"

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed. Please install jq."
    exit 1
fi

# Check if apigeecli is installed
if ! command -v apigeecli &> /dev/null; then
    echo "apigeecli not found. Installing..."
    curl -s https://raw.githubusercontent.com/apigee/apigeecli/main/downloadLatest.sh | bash
    export PATH=$PATH:$HOME/.apigeecli/bin
fi

echo "Creating API Proxy bundle..."
REV=$(apigeecli apis create bundle -f apiproxy -n "$PROXY_NAME" --org "$APIGEE_ORG" --default-token --disable-check | jq -r '.revision')

if [ -z "$REV" ] || [ "$REV" == "null" ]; then
  echo "Error: Failed to create bundle or extract revision."
  exit 1
fi

echo "Deploying revision $REV..."
apigeecli apis deploy --wait --name "$PROXY_NAME" --ovr --rev "$REV" --org "$APIGEE_ORG" --env "$APIGEE_ENV" --default-token

echo "Checking API Product..."
apigeecli products get --name oidc-okta-product --org "$APIGEE_ORG" --default-token &>/dev/null
if [ $? -ne 0 ]; then
  echo "Creating API Product: oidc-okta-product"
  apigeecli products create --name oidc-okta-product --display-name "OIDC Okta Product" --envs "$APIGEE_ENV" --proxies "$PROXY_NAME" --approval auto --org "$APIGEE_ORG" --default-token
else
  echo "API Product oidc-okta-product already exists."
fi

echo "Checking Developer..."
DEV_EMAIL="oidc-dev@example.com"
apigeecli developers get --email "$DEV_EMAIL" --org "$APIGEE_ORG" --default-token &>/dev/null
if [ $? -ne 0 ]; then
  echo "Creating Developer: $DEV_EMAIL"
  apigeecli developers create --user oidc-dev --email "$DEV_EMAIL" --first OIDC --last Developer --org "$APIGEE_ORG" --default-token
else
  echo "Developer $DEV_EMAIL already exists."
fi

echo "Checking Developer App..."
APP_NAME="oidc-okta-app"
apigeecli apps get --name "$APP_NAME" --org "$APIGEE_ORG" --default-token --disable-check &>/dev/null
if [ $? -ne 0 ]; then
  echo "Creating Developer App: $APP_NAME and subscribing to oidc-okta-product..."
  apigeecli apps create --name "$APP_NAME" --email "$DEV_EMAIL" --prods oidc-okta-product --org "$APIGEE_ORG" --default-token --disable-check
else
  echo "Developer App $APP_NAME already exists."
fi

echo "Fetching API Credentials..."
APP_INFO=$(apigeecli apps get --name "$APP_NAME" --org "$APIGEE_ORG" --default-token --disable-check)
CLIENT_ID=$(echo "$APP_INFO" | jq -r 'if type == "array" then .[0] else . end | .credentials[] | select(.apiProducts[].apiproduct=="oidc-okta-product") | .consumerKey')
CLIENT_SECRET=$(echo "$APP_INFO" | jq -r 'if type == "array" then .[0] else . end | .credentials[] | select(.apiProducts[].apiproduct=="oidc-okta-product") | .consumerSecret')

echo "============================================================"
echo "Deployment and Setup Completed!"
echo "API Proxy: $PROXY_NAME"
echo "Developer App: $APP_NAME"
echo "Client ID (Consumer Key): $CLIENT_ID"
echo "Client Secret (Consumer Secret): $CLIENT_SECRET"
echo "============================================================"
