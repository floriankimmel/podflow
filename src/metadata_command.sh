title=${args[--title]}
debug=${args[--debug]}
noDefaultReleaseDate=${args[--no-default-releasedate]}
noDefaultPostNumber=${args[--no-default-postnumber]}

dataFile="$title.txt"
contentFile="$title.html"
sourceFile="$title.md"

if ! [[ -e $contentFile ]]; then
    pandoc -s -o $contentFile $sourceFile
fi

if ! [[ -e $dataFile ]]; then

    if [[ -n "$noDefaultPostNumber" ]] then
        read -p "Release number: " postNumber
    else
        postNumber=$(op read "op://Podcast/Podcast/Episode")
        postNumber=$(expr $postNumber + 1)

        if [[ -z "$debug" ]]; then
            op item edit --vault Podcast 'Podcast' 'Episode='$postNumber > /dev/null
        fi

    fi


    echo
    option=$(gum choose --header "Title Template" "Gespräch" "Wiedersehen" "Custom")

    case $option in
        "Gespräch")
            postTitle="Ein Gespräch mit "
            ;;
        "Wiedersehen")
            postTitle="Ein Wiedersehen mit "
            ;;
        "Custom")
            postTitle=""
            ;;
    esac

    if [[ -n "$postTitle" ]]; then
        name=$(echo $title | sed 's/\([a-z]\)\([A-Z]\)/\1 \2/g')
        postTitle=$postTitle$name
    else
        read -p "Custom title: " postTitle
    fi

    if [[ -n "$noDefaultReleaseDate" ]] then
        while true; do
            read -p "Release Date:  " postDate

            if [[ "$postDate" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
                break 
            fi
        done
    else   
        postDate=$(date -v+friday '+%Y-%m-%d')  
    fi

    echo "$postNumber,$postTitle,$postDate" >> $dataFile
fi

IFS=',' read -r postNumber postTitle postDate <<< "$(head -n 1 "$title"".txt")"

echo " Kopiere Titel in Clipboard"
echo "LEP#$postNumber - $postTitle" | pbcopy -Prefer r 

echo " Kopiere Content in Clipboard"
pandoc -s -f html -t plain $contentFile | sed -e '1,2d' | tr '\n' ' ' | pbcopy -Prefer r
