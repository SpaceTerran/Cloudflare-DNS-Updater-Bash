#!/bin/bash

API_TOKEN=$1 # We get the Cloudflare Global API token from the command line

# Get the current date and time
current_time=$(date "+%m.%d.%Y-%H.%M.%S")

# Get the public IP of the target interface
echo "Getting the public IP of the target interface..."
public_ip=$(curl -s http://checkip.amazonaws.com/)
echo "Public IP: $public_ip"

ZONE_ID="xxxxxxxxxxxxxxxxxxxxxx" # Replace this with your Zone ID
RECORD_NAME="record.domain.com" # Replace this with your doamin name, ex:record.domain.com

# Set the headers for the curl command
H1="X-Auth-Email: youremail@address.com" # Replace this with your Cloudflare email address
H2="X-Auth-Key: $API_TOKEN"
H3="Content-Type: application/json"

# Get all DNS records
echo "Getting DNS records..."
response=$(curl -s -X GET "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records" -H "$H1" -H "$H2" -H "$H3")

# Extract the record id of the record we want to update
RECORD_ID=$(echo $response | jq -r '.result[] | select(.name=="'"$RECORD_NAME"'") | .id')

# check if record id was found
if [ -z "$RECORD_ID" ]; then
    echo "No record found with the name $RECORD_NAME"
    exit 1
fi

# Get the current content of the record
record_content=$(echo $response | jq -r '.result[] | select(.name=="'"$RECORD_NAME"'") | .content')
echo "Current Record Content: $record_content"

# only update the record if the public ip has changed
if [ "$public_ip" != "$record_content" ]; then

    echo "Record ID: $RECORD_ID"

    # Set the data for the curl command
    DATA=$(cat <<EOF
{
  "type": "A",
  "name": "$RECORD_NAME",
  "content": "$public_ip",
  "ttl": 1,
  "proxied": true,
  "comment": "$current_time"
}
EOF
)

    # Execute the curl command to update the record
    echo "Updating the A record in Cloudflare..."
    response=$(curl -s -o /dev/null -w "%{http_code}" -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$RECORD_ID" -H "$H1" -H "$H2" -H "$H3" -d "$DATA")

    if [ $response -eq 200 ]; then
        echo "Successfully updated the A record $RECORD_NAME with public IP $public_ip in Cloudflare Zone $ZONE_ID."
    else
        echo "Failed to update the A record $RECORD_NAME in Cloudflare Zone $ZONE_ID. HTTP code: $response"
    fi
else
    echo "The public IP has not changed. No need to update the record."
fi