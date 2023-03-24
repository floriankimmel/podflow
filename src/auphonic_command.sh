title=${args[--slug]}
episode=${args[--file]}
coverUrl=${args[--cover_url]}
auphonicTitle=${args[--production_name]}
preset=${args[--preset]}

chapters=$(<"$title".chapters.txt)

auphonic_pwd=$(op item get "Auphonic" --format json | jq -r '. | .fields | .[] | select(.label=="password") | .value')
auphonic_username=$( op item get "Auphonic" --format json | jq -r '. | .fields | .[] | select(.purpose=="USERNAME") | .value')

echo \n
echo "Start $auphonicTitle Upload"

json=$(curl -s -X POST https://auphonic.com/api/simple/productions.json \
     -u $auphonic_username:$auphonic_pwd \
     -F "preset=$preset" \
     -F "service=Tz96q8s6vs7JetJeqD6PCC" \
     -F "title=$auphonicTitle" \
     -F "track=$title" \
     -F "chapters=$chapters" \
     -F "input_file=$episode" \
     -F "image =$coverUrl" \
     -F "action=start")


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
