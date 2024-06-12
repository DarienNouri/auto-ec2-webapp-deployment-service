#!/bin/bash

DOMAIN=$1
DEPLOYED_APPS_JSON=$2
TEMP_FILE="/tmp/${DOMAIN//\./\-}"
CONFIG_FILE="/etc/nginx/sites-available/${DOMAIN//\./\-}"
ENABLED_LINK="/etc/nginx/sites-enabled/${DOMAIN//\./\-}"

{
    echo 'server {'
    echo '    server_name '$DOMAIN';'
    echo '    listen 80;'

    jq -c '.branches[]' $DEPLOYED_APPS_JSON | while read -r branch; do
        branch_name=$(echo $branch | jq -r '.name')
        port=$(echo $branch | jq -r '.port')
        echo '    location /'$branch_name'/ {'
        echo '        proxy_pass http://localhost:'$port'/'$branch_name'/;'
        echo '        proxy_set_header Host $host;'
        echo '        proxy_set_header X-Real-IP $remote_addr;'
        echo '        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;'
        echo '    }'
    done

    echo '}'
} > "$TEMP_FILE"

# Move the temporary file to the sites-available directory
sudo mv "$TEMP_FILE" "$CONFIG_FILE"

# Create symbolic link in the sites-enabled directory
sudo ln -sf "$CONFIG_FILE" "$ENABLED_LINK"

# Set the correct permissions
sudo chown www-data:www-data "$CONFIG_FILE"
sudo chmod 644 "$CONFIG_FILE"