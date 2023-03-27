postNumber=${args[--number]}
postTitle=${args[--title]}
postDate=${args[--publish_date]}
slug=${args[--slug]}

fullPostTitle="LEP#$postNumber - $postTitle"
content="Zusätzlich habt ihr ab sofort die Möglichkeit euch das exklusive <a href='https://www.patreon.com/laufendentdecken'>Patreonfeed </a>zu sichern – werbefrei und liebevoll exportiert.\n Am besten direkt mitmachen und unterstützen: <a href='https://www.patreon.com/laufendentdecken'>https://www.patreon.com/laufendentdecken</a>\n\n<b>Links zum weiterlesen</b>\n\nMehr Informationen zu [Guest]: Instagram | Facebook \n\nWenn ihr den Podcast direkt ohne Installation hören möchtet, könnt ihr das hier tun: Laufend Entdecken auf Podbay\n\nFlorian: <a href='http://twitter.com/laufenentdecken'>Twitter</a>, <a href='https://www.strava.com/athletes/1651823'>Strava</a>\nPeter: <a href='https://twitter.com/redendentdecken'>Twitter</a>, <a href='https://www.instagram.com/redendentdecken'>Instagram</a>, <a href='https://www.strava.com/athletes/24464941'>Strava</a>\n\n<a href='http://facebook.com/laufendentdeckenblog/'>Facebook</a>, <a href='https://instagram.com/laufendentdeckenpodcast/'>Instagram</a>, <a href='https://www.strava.com/clubs/473847'>Strava Club</a>"

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
    --data-raw "{ \"title\":\"$fullPostTitle\", \"status\": \"future\", \"date\": \"$postDate 09:00:00\", \"slug\": \"$postNumber\", \"content\": \"$content\", \"format\": \"standard\" }")
