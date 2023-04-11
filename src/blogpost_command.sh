postNumber=${args[--number]}
postTitle=${args[--title]}
postDate=${args[--publish_date]}
slug=${args[--slug]}

ag1=${args[--ag1]}

fullPostTitle="LEP#$postNumber - $postTitle"

case $postTitle in
    "Ein Gespräch mit "*)
        guest=${postTitle#"Ein Gespräch mit "}
        guest="Mehr Informationen zu $guest: Instagram | Facebook <br><br>"
        ;;

    "Ein Wiedersehen mit "*)
        guest=${postTitle#"Ein Wiedersehen mit "}
        guest="Mehr Informationen zu $guest: Instagram | Facebook <br><br>"
        ;;
    *)
        guest=""
        ;;
esac

content="<b>Werbefrei</b><br><br>Zusätzlich habt ihr ab sofort die Möglichkeit euch das exklusive <a href='https://www.patreon.com/laufendentdecken'>Patreonfeed</a> zu sichern – werbefrei und liebevoll exportiert.<br><br>Am besten direkt mitmachen und unterstützen: <a href='https://www.patreon.com/laufendentdecken'>Patreon</a><br><br><b>Links zum weiterlesen</b><br><br>$guest Wenn ihr den Podcast direkt ohne Installation hören möchtet, könnt ihr das hier tun: Laufend Entdecken auf Podbay<br><br>Florian: <a href='http://twitter.com/laufenentdecken'>Twitter</a>, <a href='https://www.strava.com/athletes/1651823'>Strava</a><br>Peter: <a href='https://twitter.com/redendentdecken'>Twitter</a>, <a href='https://www.instagram.com/redendentdecken'>Instagram</a>, <a href='https://www.strava.com/athletes/24464941'>Strava</a><br><br><a href='http://facebook.com/laufendentdeckenblog/'>Facebook</a>, <a href='https://instagram.com/laufendentdeckenpodcast/'>Instagram</a>, <a href='https://www.strava.com/clubs/473847'>Strava Club</a>"

if [[ -n "$ag1" ]]; then
    content="<b>Werbung</b><br><br>Informiere dich jetzt auf <a href='http://athleticgreens.com/laufendentdecken'>athleticgreens.com/laufendentdecken</a> , teste AG1 völlig risikofrei mit 90 Tagen Geld-zurück-Garantie und sichere dir bei deiner AG1 Erstbestellung einen kostenlosen Jahresvorrat an Vitamin D3+K2 zur Unterstützung des Immunsystems & 5 praktische Travel Packs! Gesundheitsbezogene Angaben zu AG1 und unser Angebot findest du auf: <a href='http://athleticgreens.com/laufendentdecken'>athleticgreens.com/laufendentdecken</a><br><br>Auf die Bedeutung einer abwechslungsreichen und ausgewogenen Ernährung und einer gesunden Lebensweise wird hingewiesen. Außer Reichweite von Kindern aufbewahren. Nicht geeignet für Kinder und Jugendliche unter 18 Jahren, schwangere oder stillende Frauen. Die angegebene empfohlene tägliche Verzehrmenge darf nicht überschritten werden.<br><br>$content"
fi

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
    --data-raw "{ \"title\":\"$fullPostTitle\", \"status\": \"future\", \"date\": \"$postDate 09:00:00\", \"slug\": \"$postNumber\", \"content\": \"<!-- wp:paragraph --> <!-- /wp:paragraph --> <!-- wp:paragraph -->$content<!-- /wp:paragraph -->\" }")

