#!/bin/bash

PUBLISH_DATE=$(date -jf "%Y-%m-%d %H:%M:%S" "${args[--publish_date]}" "+%Y-%m-%dT%H:%M:%S%z")
DESCRIPTION=${args[--title]}

API_KEY=$(op item get "YoutubeApiKey" --format json | jq -r '. | .fields | .[] | select(.label=="password") | .value')

local length="${#DESCRIPTION}"
local result=''

for ((i = 0; i < length; i++)); do
    local char="${DESCRIPTION:i:1}"
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

# Set the necessary scopes for the API request
SCOPES="https://www.googleapis.com/auth/youtube.force-ssl"

# Set your API key file path and application name
API_KEY_FILE="/Users/fkimmel/Dropbox/Tresor/key.json"
APPLICATION_NAME="CLI"

credentials="/Users/fkimmel/Library/Application Support/google-oauthlib-tool/credentials.json"

if ! [[ -e $credentials ]]; then
    google-oauthlib-tool --client-secrets $API_KEY_FILE --scope $SCOPES --save 
fi

client_id=$(jq -r '.client_id' "$credentials")
client_secret=$(jq -r '.client_secret' "$credentials")
refresh_token=$(jq -r '.refresh_token' "$credentials")

# Get the access token
ACCESS_TOKEN=$(curl -s -X POST "https://oauth2.googleapis.com/token" \
                    -H "Content-Type: application/x-www-form-urlencoded" \
                    -d "client_id=$client_id&client_secret=$client_secret&refresh_token=$refresh_token&grant_type=refresh_token" \
                    | jq -r '.access_token')

# Send a request to the YouTube Data API to search for the video
JSON=$(curl -s "https://www.googleapis.com/youtube/v3/search?key=$API_KEY&q=$result&part=id&part=snippet&maxResults=1&type=video&forMine=true" \
    --header "Authorization: Bearer $ACCESS_TOKEN" \
    --header 'Accept: application/json' \
)

# Parse the JSON response to extract the video ID
VIDEO_ID=$(echo "$JSON" | jq -r '.items[0].id.videoId')

# Print the video ID
echo "The video ID is: $VIDEO_ID"

REQUEST_BODY=$(jq -n --arg videoId "$VIDEO_ID" --arg date $PUBLISH_DATE '{ id: $videoId, status: { privacyStatus: "private", "publishAt": $date , "license": "youtube", "publicStatsViewable": true } }')

# Make the API request to update the video
curl -X PUT "https://youtube.googleapis.com/youtube/v3/videos?part=status" \
    --header "Authorization: Bearer $ACCESS_TOKEN" \
    --header 'Accept: application/json' \
    --header 'Content-Type: application/json' \
    --data "$REQUEST_BODY"

echo " Youtube Video has been scheduled"
