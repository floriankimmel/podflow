title=${args[--title]}
debug=${args[--debug]}

dataFile="$title".txt

if ! [[ -e $dataFile ]]; then
    postNumber=$(op item get "Podcast" --format json | jq -r '. | .fields | .[] | select(.label=="Episode") | .value')
    postNumber=$(expr $postNumber + 1)
    if [[ -z "$debug" ]]; then
        op item edit 'Podcast' 'Episode='$postNumber > /dev/null
    fi

    echo "Title Template"
    echo "(1) Ein Gespräch mit "
    echo "(2) Ein Wiedersehen mit "
    echo "(*) Custom"

    while true
    do
        read -p "Please choose: " option

        case $option in
            1)
                postTitle="Ein Gespräch mit "
                break
                ;;
            2)
                postTitle="Ein Wiedersehen mit "
                break
                ;;
            *)
                postTitle=""
                ;;
        esac
    done

    name=$(echo $title | sed 's/\([a-z]\)\([A-Z]\)/\1 \2/g')
    postTitle=$postTitle$name

    if [[ -n "$noDefaultReleaseDate" ]] then
        while true; do
            read -p "Release Date: $nextFriday): " postDate

            if [[ "$postDate" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
                break 
            fi
        done
    else   
        postDate=$(date -v+friday '+%Y-%m-%d')  
    fi

    echo "$postNumber,$postTitle,$postDate" >> $dataFile
fi
