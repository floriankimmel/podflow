postNumber=${args[--number]}
postTitle=${args[--title]}
postDate=${args[--publish_date]}
slug=${args[--slug]}

ag1=${args[--ag1]}
polestar=${args[--polestar]}

fullPostTitle="LEP#$postNumber - $postTitle"

title=$(echo "${slug#*_}")
name=$(echo $title | sed 's/\([a-z]\)\([A-Z]\)/\1 \2/g')
contentHtml="$title".html 
image="$title".png

if  [[ -e $contentHtml ]]; then
    description=$(sed -n '/<body/,/<\/body>/p' $contentHtml | sed '1d;$d' |  sed 's/"/''/g' | tr '\n' ' ')
else
    description=""
fi

case $postTitle in
    "Ein Gespräch mit "*)
        guest=${postTitle#"Ein Gespräch mit "}
        guest="<b>Links zum weiterlesen</b><br><br>Mehr Informationen zu $guest: Instagram | Facebook <br><br>"
        ;;

    "Ein Wiedersehen mit "*)
        guest=${postTitle#"Ein Wiedersehen mit "}
        guest="<b>Links zum weiterlesen</b><br><br>Mehr Informationen zu $guest: Instagram | Facebook <br><br>"
        ;;
    *)
        guest=""
        ;;
esac

content="<b>Werbefrei</b><br><br>Zusätzlich habt ihr ab sofort die Möglichkeit euch das exklusive <a href='https://www.patreon.com/laufendentdecken'>Patreonfeed</a> zu sichern – werbefrei und liebevoll exportiert.<br><br>Am besten direkt mitmachen und unterstützen: <a href='https://www.patreon.com/laufendentdecken'>Patreon</a><br><br>${guest}Wenn ihr den Podcast direkt ohne Installation hören möchtet, könnt ihr das hier tun: Laufend Entdecken auf Podbay<br><br>Florian: <a href='http://twitter.com/laufenentdecken'>Twitter</a>, <a href='https://www.strava.com/athletes/1651823'>Strava</a><br>Peter: <a href='https://twitter.com/redendentdecken'>Twitter</a>, <a href='https://www.instagram.com/redendentdecken'>Instagram</a>, <a href='https://www.strava.com/athletes/24464941'>Strava</a><br>Geordi: <a href='https://twitter.com/Geordi2504'>Twitter</a>, <a href='https://www.instagram.com/geordi2504/'>Instagram</a>, <a href='https://www.instagram.com/viennarunning/'>Vienna Running Instagram</a>, <a href='https://vienna-running.eu/'>Vienna Running</a><br><br><a href='http://facebook.com/laufendentdeckenblog/'>Facebook</a>, <a href='https://instagram.com/laufendentdeckenpodcast/'>Instagram</a>, <a href='https://www.strava.com/clubs/473847'>Strava Club</a>"

if [[ -n "$ag1" ]]; then
    content="<b>Werbung</b><br><br>Informiere dich jetzt auf <a href='http://drinkag1.com/laufendentdecken'>drinkag1.com/laufendentdecken</a> , teste AG1 völlig risikofrei mit 90 Tagen Geld-zurück-Garantie und sichere dir bei deiner AG1 Erstbestellung einen kostenlosen Jahresvorrat an Vitamin D3+K2 zur Unterstützung des Immunsystems & 5 praktische Travel Packs! Gesundheitsbezogene Angaben zu AG1 und unser Angebot findest du auf: <a href='http://drinkag1.com/laufendentdecken'>drinkag1.com/laufendentdecken</a><br><br>Auf die Bedeutung einer abwechslungsreichen und ausgewogenen Ernährung und einer gesunden Lebensweise wird hingewiesen. Außer Reichweite von Kindern aufbewahren. Nicht geeignet für Kinder und Jugendliche unter 18 Jahren, schwangere oder stillende Frauen. Die angegebene empfohlene tägliche Verzehrmenge darf nicht überschritten werden.<br><br>$content"
fi

if [[ -n "$polestar" ]]; then
    content="<b>Werbung</b><br><br>Alle Informationen zur Aktion von <a href='https://www.polestar.com/at/'>Polestar</a> findest du unter: <a href='https://www.polestar.com/at/polestar-2-2023/'>https://www.polestar.com/at/polestar-2-2023/</a><br>Das Leasingangebot ist gültig bis 30.06.2023<br><br>$content"
fi

apiKey=$(op read "op://Podcast/Podlove/credential")

echo " Initiating episode" 
json=$(curl -s -X POST https://laufendentdecken-podcast.at/wp-json/podlove/v2/episodes \
    --header "Authorization: Basic $apiKey")

episodeId=$(echo $json | jq -r ' . | "\(.id)"')
response=$(curl -s -X POST https://laufendentdecken-podcast.at/wp-json/podlove/v2/episodes/$episodeId \
    --header "Authorization: Basic $apiKey" \
    --header 'Content-Type: application/json; charset=utf-8' \
    -d "{ \"slug\": \"$slug\", \"title\": \"$fullPostTitle\", \"number\": \"$postNumber\" }")

json=$(curl -s -X GET https://laufendentdecken-podcast.at/wp-json/podlove/v2/episodes/$episodeId --header "Authorization: Basic $apiKey")
postId=$(echo $json | jq -r ' . | "\(.post_id)"')

echo " Uploading feature image" 
featureMedia=$(curl --request POST \
    --url https://laufendentdecken-podcast.at/wp-json/wp/v2/media \
    --http1.1 \
    --header "authorization: Basic ${apiKey}" \
    --header 'content-type: multipart/form-data' \
    --form "file=@${image}" \
    --form "title=$name" \
    | jq -r '.id')

postData="{ \"featured_media\": $featureMedia, \"title\":\"$fullPostTitle\", \"status\": \"future\", \"date\": \"$postDate\", \"slug\": \"$postNumber\", \"content\": \"<!-- wp:paragraph -->$description<!-- /wp:paragraph --> <!-- wp:paragraph -->$content<!-- /wp:paragraph -->\" }"

echo " Updating information" 
response=$(curl --silent -X POST https://laufendentdecken-podcast.at/wp-json/wp/v2/episodes/$postId \
    --header "Authorization: Basic $apiKey" \
    --header 'Content-Type: application/json; charset=utf-8' \
    --data-raw "$postData")
