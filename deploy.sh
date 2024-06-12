#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/nginx.conf"

if ! command -v yq &> /dev/null; then
    echo "yq not found, installing..."
    sudo wget https://github.com/mikefarah/yq/releases/download/v4.6.3/yq_linux_amd64 -O /usr/bin/yq && sudo chmod +x /usr/bin/yq
fi

BRANCH=${1:-"main"}
SERVER_DIR=$(realpath "$(dirname "$0")")
BASE_DIR="$(dirname "$SERVER_DIR")"
SERVER_SETTINGS_YML="$SERVER_DIR/server_settings.yml"
APP_REPO_URL=$(yq eval '.app_repo_url' "$SERVER_SETTINGS_YML")
PYTHON_INTERPRETER=$(yq eval '.python_interpreter' "$SERVER_SETTINGS_YML")
PYTHON_PACKAGE_MANAGER=$(yq eval '.python_package_manager' "$SERVER_SETTINGS_YML")

REPO_NAME=$(basename "$APP_REPO_URL" .git)
REPO_DIR="$BASE_DIR/$REPO_NAME"
APP_DIR="$BASE_DIR/$REPO_NAME"

source "$(dirname "$PYTHON_INTERPRETER")/activate"

if [ -d "$REPO_DIR" ]; then
    cd "$REPO_DIR"
    git fetch origin
    git checkout "$BRANCH"
    git pull origin "$BRANCH"
else
    git clone -b "$BRANCH" "$APP_REPO_URL" "$REPO_DIR"
    cd "$REPO_DIR"
fi

if [[ "${PYTHON_PACKAGE_MANAGER}" == "poetry" ]]; then
    echo "Installing dependencies using poetry"
    poetry install --directory="$SERVER_DIR"
    cat "$REPO_DIR/requirements.txt" | xargs poetry add --directory="$SERVER_DIR"
else
    echo "Installing dependencies using pip"
    pip install --upgrade pip --quiet
    pip install -r "$SERVER_DIR/requirements.txt" --quiet
    pip install -r "$REPO_DIR/requirements.txt" --quiet
fi

APP_SETTINGS_YML="$REPO_DIR/app_settings.yml"
if [ ! -f "$APP_SETTINGS_YML" ]; then
    echo "app_settings.yml file not found for branch $BRANCH"
    exit 1
fi

eval "$(yq eval '.GITHUB_URL | "GITHUB_URL=\(.)"' "$APP_SETTINGS_YML")"
eval "$(yq eval '.PORT | "PORT=\(.)"' "$APP_SETTINGS_YML")"
eval "$(yq eval '.APPTYPE | "APPTYPE=\(.)"' "$APP_SETTINGS_YML")"
eval "$(yq eval '.APPNAME | "APPNAME=\(.)"' "$APP_SETTINGS_YML")"
eval "$(yq eval '.APP_DIR | "APP_DIR=\(.)"' "$APP_SETTINGS_YML")"

# update $APP_DIR to subdirectory if specified in APPNAME
if [ -n "$APP_DIR" ]; then
    APP_DIR="$REPO_DIR/$APP_DIR"
fi

echo "REPO_DIR: $REPO_DIR"
echo "APP_DIR: $APP_DIR"

if [ -z "$PORT" ] || [ -z "$APPTYPE" ]; then
    echo "PORT or APPTYPE not set in app_settings.yml file for branch $BRANCH"
    exit 1
fi

pm2 stop "$BRANCH" || true

case $APPTYPE in
    "dash")
        if ! pm2 describe "$BRANCH" > /dev/null; then
            pm2 start -f "app.py" --interpreter="$PYTHON_INTERPRETER" --name "$BRANCH" --cwd "$APP_DIR" -- --port "$PORT"
        else
            pm2 restart "$BRANCH"
        fi
        ;;
    "streamlit")
        if ! pm2 describe "$BRANCH" > /dev/null; then
            echo "[server]" > "$APP_DIR/.streamlit/config.toml"
            echo "baseUrlPath = \"/$BRANCH/\"" >> "$APP_DIR/.streamlit/config.toml"
            pm2 start "$(dirname "$PYTHON_INTERPRETER"/streamlit) run app.py" --name "$BRANCH" --cwd "$APP_DIR" -- --server.port "$PORT"
        else
            pm2 restart "$BRANCH"
        fi
        ;;
    *)
        echo "Unknown APPTYPE: $APPTYPE"
        exit 1
        ;;
esac

echo "Deployed $BRANCH on port $PORT"

DEPLOYED_APPS_JSON="$SERVER_DIR/app_deploys.json"

GIT_DIR=$SERVER_DIR/.git GIT_WORK_TREE=$SERVER_DIR git pull origin master

"$PYTHON_INTERPRETER" $SERVER_DIR/update_deploy.py "$BRANCH" "$PORT" "$DEPLOYED_APPS_JSON"

custom_domains=$(yq eval '.custom_domains[]' "$SERVER_SETTINGS_YML")

for DOMAIN in $custom_domains; do
    "$SERVER_DIR/generate_nginx_config.sh" "$DOMAIN" "$DEPLOYED_APPS_JSON"
    CONFIG_FILE="/etc/nginx/sites-available/${DOMAIN//\./\-}"
    sudo ln -sf "$CONFIG_FILE" /etc/nginx/sites-enabled/
done

sudo nginx -t && sudo systemctl reload nginx

GIT_DIR=$SERVER_DIR/.git GIT_WORK_TREE=$SERVER_DIR git add .
GIT_DIR=$SERVER_DIR/.git GIT_WORK_TREE=$SERVER_DIR git commit -m "Deployed $BRANCH on port $PORT"
GIT_DIR=$SERVER_DIR/.git GIT_WORK_TREE=$SERVER_DIR git push origin master

sudo nginx -t && sudo systemctl reload nginx

echo "Main deployment URL: http://localhost:$PORT/$BRANCH/"