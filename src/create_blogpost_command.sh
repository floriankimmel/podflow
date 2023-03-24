postNumber=${args[--number]}
postTitle=${args[--title]}
postDate=${args[--publish_date]}
slug=${args[--slug]}

fullPostTitle="LEP#$postNumber - $postTitle"

apiKey=$(op item get "PodloveApiKey" --format json | jq -r '. | .fields | .[] | select(.label=="password") | .value')

json=$(curl  -s -X POST https://laufendentdecken-podcast.at/wp-json/podlove/v2/episodes --header "Authorization: Basic $apiKey")

episodeId=$(echo $json | jq -r ' . | "\(.id)"')
response=$(curl -s -X POST https://laufendentdecken-podcast.at/wp-json/podlove/v2/episodes/$episodeId \
    --header "Authorization: Basic $apiKey" \
    --header 'Content-Type: application/json; charset=utf-8' \
    -d "{ \"slug\": \"$slug\", \"title\": \"$fullPostTitle\", \"number\": \"$postNumber\" }")

json=$(curl -s -X GET https://laufendentdecken-podcast.at/wp-json/podlove/v2/episodes/$episodeId --header "Authorization: Basic $apiKey")
postId=$(echo $json | jq -r ' . | "\(.post_id)"')

response=$(curl -s -X POST https://laufendentdecken-podcast.at/wp-json/wp/v2/episodes/$postId \
    --header "Authorization: Basic $apiKey" \
    --header 'Content-Type: application/json; charset=utf-8' \
    --data-raw "{ \"title\":\"$fullPostTitle\", \"status\": \"future\", \"date\": \"$postDate 09:00:00\", \"slug\": \"$postNumber\" }")

