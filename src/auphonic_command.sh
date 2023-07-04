title=${args[--slug]}
episode=${args[--file]}
coverUrl=${args[--cover_url]}
auphonicTitle=${args[--production_name]}
preset=${args[--preset]}
noStart=${args[--no-start]}
description=${args[--description]}

name=$(echo "${title#*_}")
chapters=$(<"$name".chapters.txt)

auphonic_pwd=$(op item get --vault Podcast "Auphonic Api" --fields label=credential) 
auphonic_username=$(op item get --vault Podcast "Auphonic Api" --fields label=username)


action="start"

# If no start is set, we just want to save the production
if [[ -n "$noStart" ]]; then
    action="save"
fi

echo
echo
echo " Create $auphonicTitle Production"
json=$(curl -s -X POST https://auphonic.com/api/simple/productions.json \
     -u $auphonic_username:$auphonic_pwd \
     -F "preset=$preset" \
     -F "service=Tz96q8s6vs7JetJeqD6PCC" \
     -F "title=$auphonicTitle" \
     -F "track=$title" \
     -F "chapters=$chapters" \
     -F "input_file=$episode" \
     -F "image=$coverUrl" \
     -F "summary=$description" \
     -F "action=$action")

# Only query the status if we started the production
if [[ -z "$noStart" ]]; then
    echo " Production started"
    content=$(echo $json | jq -r ' . | "\(.data.status_string):\(.data.uuid)"')
    IFS=':' read -ra response <<< "$content"

    status_string=${response[0]}
    uuid=${response[1]}

    echo "UUID: $uuid"
    echo -ne "Auphonic status: $status_string \r"

    while [[ $status_string != "Done"  ]]
    do
        json=$(curl -s -X GET https://auphonic.com/api/production/$uuid.json \
            -u $auphonic_username:$auphonic_pwd) 

        status_string=$(echo $json | jq -r ' . | .data.status_string')

        echo -ne "Auphonic status: $status_string                         \r"
        sleep 2
    done
else
    echo " Production $auphonicTitle saved"
fi
