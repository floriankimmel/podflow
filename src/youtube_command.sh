#!/bin/bash

API_KEY=$(op item get "YoutubeApiKey" --format json | jq -r '. | .fields | .[] | select(.label=="password") | .value')

# Set the title of the video you want to search for
local string="LEP#125"

local length="${#string}"
local result=''

for ((i = 0; i < length; i++)); do
    local char="${string:i:1}"
    case $char in
        [a-zA-Z0-9.~_-])
            result+="$char"
            ;;
        *)
            printf -v hex '%%%02X' "'$char"
            result+="$hex"
            ;;
    esac
done

# Send a request to the YouTube Data API to search for the video
JSON=$(curl -s "https://www.googleapis.com/youtube/v3/search?key=$API_KEY&q=$result&part=id&part=snippet&maxResults=1&type=video")

# Parse the JSON response to extract the video ID
VIDEO_ID=$(echo "$JSON" | jq -r '.items[0].id.videoId')

# Print the video ID
echo "The video ID for \"$result\" is: $VIDEO_ID"

# Set the necessary scopes for the API request
SCOPES="https://www.googleapis.com/auth/youtube.force-ssl"

# Set your API key file path and application name
API_KEY_FILE="/Users/fkimmel/Dropbox/Tresor/key.json"
APPLICATION_NAME="CLI"

# Get the OAuth 2.0 access token
ACCESS_TOKEN=$(google-oauthlib-tool --client-secrets $API_KEY_FILE \
                  --scope $SCOPES \
                  --save \
                  --headless \
                  | grep access_token \
                  | cut -d' ' -f2)


DESCRIPTION="LEP#125 - Wir zwei allein heut Nacht"
PUBLISH_DATE="2021-11-12T09:00:00.000Z"

echo $ACCESS_TOKEN

# Construct the request body
REQUEST_BODY=$(jq -n --arg desc "$DESCRIPTION" --arg date "$PUBLISH_DATE" '{snippet: {description: $desc, publishedAt: $date}}')

# Make the API request to update the video
curl --request PUT "https://www.googleapis.com/youtube/v3/videos?part=snippet&id=$VIDEO_ID" \
    --header "Authorization: Bearer $ACCESS_TOKEN" \
    --header "Content-Type: application/json" \
    --data "$REQUEST_BODY" 
