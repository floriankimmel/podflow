postNumber=${args[--number]}
postTitle=${args[--title]}
postDate=${args[--publish_date]}
slug=${args[--slug]}

fullPostTitle="LEP#$postNumber - $postTitle"

json=$(curl  -s -X POST https://laufendentdecken-podcast.at/wp-json/podlove/v2/episodes --header "Authorization: Basic ZmxvcmlhbjpkUUNZIG1BOGYgM0p1cyBEcjJ2IDlIZXAgb2p1Yg==")

episodeId=$(echo $json | jq -r ' . | "\(.id)"')
response=$(curl -s -X POST https://laufendentdecken-podcast.at/wp-json/podlove/v2/episodes/$episodeId \
    --header "Authorization: Basic ZmxvcmlhbjpkUUNZIG1BOGYgM0p1cyBEcjJ2IDlIZXAgb2p1Yg==" \
    --header 'Content-Type: application/json; charset=utf-8' \
    -d "{ \"slug\": \"$slug\", \"title\": \"$fullPostTitle\", \"number\": \"$postNumber\" }")

json=$(curl -s -X GET https://laufendentdecken-podcast.at/wp-json/podlove/v2/episodes/$episodeId --header "Authorization: Basic ZmxvcmlhbjpkUUNZIG1BOGYgM0p1cyBEcjJ2IDlIZXAgb2p1Yg==")
postId=$(echo $json | jq -r ' . | "\(.post_id)"')

response=$(curl -s -X POST https://laufendentdecken-podcast.at/wp-json/wp/v2/episodes/$postId \
    --header "Authorization: Basic ZmxvcmlhbjpkUUNZIG1BOGYgM0p1cyBEcjJ2IDlIZXAgb2p1Yg==" \
    --header 'Content-Type: application/json; charset=utf-8' \
    --data-raw "{ \"title\":\"$fullPostTitle\", \"status\": \"future\", \"date\": \"$postDate 09:00:00\", \"slug\": \"$postNumber\" }")

