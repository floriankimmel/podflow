skipFtp=${args[--skip-ftp]}
skipAws=${args[--skip-aws]}
skipAuphonic=${args[--skip-auphonic]}
skipDownload=${args[--skip-download]}
skipBlogpost=${args[--skip-blogpost]}


ag1=${args[--ag1]}
add=$([ -n "$ag1" ] && echo "true" || echo "false")

episode=${args[--m4a]}
if [[ -z "$episode" ]]; then
    shopt -s nullglob # um die Schleife zu vermeiden, wenn keine m4a-Dateien vorhanden sind
    for file in ./*.m4a; do
        episode=$(basename "$file")
        break
    done
fi

echo "Start automatic workflow for file $episode"

title=$(echo "$episode" | cut -d'.' -f 1)
dataFile="$title".txt

if [[ -e "$title"_addfree.m4a ]] && [[ "$add" = "false" ]]; then
    echo "Addfree version detected, but no advirtesement provided"
    echo "Supported Advirtesements:"
    echo "(1) ag1"

    while true
    do
        read -p "Please choose: " option

        case $option in
            1)
                ag1="1"
                break
                ;;
            *)
                ;;
        esac
    done
fi

if [[ -e $dataFile ]]; then
    IFS=',' read -r postNumber postTitle postDate <<< "$(head -n 1 "$dataFile")"
else
    while true; do
        read -p "Episode Nummer: " postNumber

        if [[ "$postNumber" =~ ^[0-9]*$ ]]; then
            break 
        fi
    done
    read -p "Episode Titel: " postTitle

    while true; do
        read -p "Release (YYYY-MM-DD): " postDate

        if [[ "$postDate" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}$ ]]; then
            break 
        fi
    done

    echo "$postNumber,$postTitle,$postDate" >> $dataFile
fi

echo "Automate episode 'LEP#$postNumber - $postTitle' scheduled for $postDate"

chapters=$(<"$title".chapters.txt)
cover="$title".png

if [[ "$add" = "true" ]]; then
    episodeAdFree="$title"_addfree.m4a
    titleAdFree="$title"_addfree
else
    episodeAdFree=$episode
    titleAdFree=$title
fi

coverYoutube="$title"_youtube.png
baseUrl="https://rssfeed.laufendentdecken-podcast.at/data/"

coverUrl="$baseUrl$cover"
coverUrlYoutube="$baseUrl$coverYoutube"

if [[ -z "$skipFtp" ]]; then
    echo
    echo "Upload episode to FTP Server"
    lep ftp --file $episode

    if [[ "$add" = "true" ]]; then
        echo "Upload addfree episode to FTP Server"
        lep ftp --file $episodeAdFree
    fi

    echo "Upload cover to FTP Server"
    lep ftp --file $cover
    echo "Upload youtube cover to FTP Server"
    lep ftp --file $coverYoutube 
fi

if [ $? -ne 0 ]; then
  exit 1
fi

if [[ -z "$skipAws" ]]; then
    echo
    echo "Backup to S3"

    aws s3 cp $episode s3://laufendentdecken-podcast/
    aws s3 cp s3://laufendentdecken-podcast/$episode s3://laufendentdecken-podcast-backup/

    if [[ "$add" = "true" ]]; then
        aws s3 cp $episodeAdFree s3://laufendentdecken-podcast/
        aws s3 cp s3://laufendentdecken-podcast/$episodeAdFree s3://laufendentdecken-podcast-backup/
    fi
fi

if [ $? -ne 0 ]; then
  exit 1
fi

if [[ -z "$skipAuphonic" ]]; then
    episodePreset="WbQunVJaZFitr3z74XTyxJ"
    youtubePreset="M9ageytQCjaFAYn7EjSYPZ"

    youtubeDescription=$(echo -e "Hört rein auf:\n🔗Https://laufendentdecken.at/$postNumber/\n\nUnd natürlich auf\n🎧Spotify, iTunes, Google Podcast, zencastr und in allen podcatchern über das RSS Feed.\n\n✅ Folge uns auf Instagram @laufendentdeckenpodcast , @floderandere und @redendentdecken\n\nUnd auf Facebook https://www.facebook.com/laufendentdeckenpodcast/\n\nWer uns unterstützen mag: https://www.patreon.com/laufendentdecken\noder Steady: https://steadyhq.com/de/laufendentdecken")

    lep auphonic  \
        --production_name $title \
        --preset $episodePreset\
        --cover_url $coverUrl \
        --file $episode \
        --slug $title

    lep auphonic  \
        --production_name "LEP#$postNumber - $postTitle" \
        --preset $youtubePreset \
        --cover_url $coverUrlYoutube \
        --file $episode \
        --slug $title \
        --description "$youtubeDescription"

    if [[ "$add" = "true" ]]; then
        lep auphonic  \
            --production_name "$title (addfree)" \
            --preset $episodePreset \
            --cover_url $coverUrl \
            --file $episodeAdFree \
            --slug $title
    fi

    echo "Podcast successfully uploaded"
fi

if [ $? -ne 0 ]; then
  exit 1
fi

if [[ -z "$skipDownload" ]]; then
    echo
    echo "Download adfree version again to be able to upload it to patroen/steady"
    curl https://rssfeed.laufendentdecken-podcast.at/data/$titleAdFree.mp3 --output ~/Downloads/$titleAdFree.mp3
fi

if [ $? -ne 0 ]; then
  exit 1
fi

if [[ -z "$skipBlogpost" ]]; then
    echo
    echo "Create Episode on Website"

    if [[ "$add" = "false" ]]; then
        lep blogpost \
            --number $postNumber \
            --title "$postTitle" \
            --publish_date $postDate \
            --slug $title
    fi   

    if [[ -n "$ag1" ]]; then
        lep blogpost \
            --number $postNumber \
            --title "$postTitle" \
            --publish_date $postDate \
            --slug $title \
            --ag1
    fi

fi
