skipFtp=${args[--skip-ftp]}
skipAws=${args[--skip-aws]}
skipAuphonic=${args[--skip-auphonic]}
skipDownload=${args[--skip-download]}
skipBlogpost=${args[--skip-blogpost]}
skipYoutube=${args[--skip-youtube]}
noDefaultReleaseDate=${args[--no-default-releasedate]}
noDefaultPostNumber=${args[--no-default-postnumber]}

defaultAirTime="09:00:00"

ag1=${args[--ag1]}
polestar=${args[--polestar]}
debug=${args[--debug]}

episode=${args[--m4a]}
if [[ -z "$episode" ]]; then
    episode=$(basename "$(pwd)")
    episode="$episode.m4a"
fi

if [[ -z "$skipYoutube" ]]; then
    lep check
else 
    lep check --skip-youtube
fi

if [ $? -ne 0 ]; then
  exit 1
fi

echo "󰀂Start automatic workflow for file $episode"

title=$(echo "$episode" | cut -d'.' -f 1)
ad=$([ -n "$ag1" ] && echo "true" || echo "false")

if [[ -e "$title"_adfree.m4a ]] && [[ "$ad" = "false" ]]; then
    echo "Adfree version detected, but no advirtesement provided"
    echo "Supported Advirtesements:"
    echo "(1) ag1"
    echo "(1) polestar"

    while true
    do
        read -p "Please choose: " option

        case $option in
            1)
                ag1="1"
                break
                ;;
            1)
                polestar="1"
                break
                ;;
            *)
                ;;
        esac
    done
    ad="true"
fi


if [[ -n "$debug" ]]; then
    if [[ -n "$noDefaultReleaseDate" ]]; then
        if [[ -n "$noDefaultPostNumber" ]]; then
            lep metadata --title $title --debug --no-default-releasedate --no-default-postnumber  
        else 
            lep metadata --title $title --debug --no-default-releasedate 
        fi
    else 
        if [[ -n "$noDefaultPostNumber" ]]; then
            lep metadata --title $title --debug --no-default-postnumber  
        else 
            lep metadata --title $title --debug 
        fi
    fi
else 
    if [[ -n "$noDefaultReleaseDate" ]]; then
        if [[ -n "$noDefaultPostNumber" ]]; then
            lep metadata --title $title --no-default-releasedate --no-default-postnumber  
        else 
            lep metadata --title $title --no-default-releasedate 
        fi
    else 
        if [[ -n "$noDefaultPostNumber" ]]; then
            lep metadata --title $title --no-default-postnumber  
        else 
            lep metadata --title $title 
        fi
    fi
fi

IFS=',' read -r postNumber postTitle postDate <<< "$(head -n 1 "$title"".txt")"

echo "  Automate episode 'LEP#$postNumber - $postTitle' scheduled for $postDate"

chapters=$(<"$title".chapters.txt)
cover="$title".png

if [[ "$ad" = "true" ]]; then
    episodeAdFree="$title"_adfree.m4a
    titleAdFree="$title"_adfree
else
    episodeAdFree=$episode
    titleAdFree=$title
fi

coverYoutube="$title"_youtube.png
baseUrl="https://rssfeed.laufendentdecken-podcast.at/data/"

coverWithPostNumber="$postNumber"_"$cover"
coverYoutubeWithPostNumber="$postNumber"_"$coverYoutube"

coverUrl="$baseUrl$coverWithPostNumber"
coverUrlYoutube="$baseUrl$coverYoutubeWithPostNumber"

episodeWithPostNumber="$postNumber"_"$episode"
episodeAdFreeWithPostNumber="$postNumber"_"$episodeAdFree"
slug="$postNumber"_"$title"
slugAdFree="$postNumber"_"$titleAdFree"

if [[ -z "$skipFtp" ]]; then
    echo
    echo "  Upload episode to FTP Server"
    lep ftp --file $episode --name $episodeWithPostNumber

    if [[ "$ad" = "true" ]]; then
        echo "  Upload adfree episode to FTP Server"
        lep ftp --file $episodeAdFree --name $episodeAdFreeWithPostNumber
    fi

    echo "  Upload cover to FTP Server"
    lep ftp --file $cover --name $coverWithPostNumber

    if [[ -z "$skipYoutube" ]]; then
        echo "  Upload youtube cover to FTP Server"
        lep ftp --file $coverYoutube --name $coverYoutubeWithPostNumber 
    fi
fi

if [ $? -ne 0 ]; then
  exit 1
fi

if [[ -z "$skipAws" ]]; then
    echo
    echo " Backup to S3"

    aws s3 cp $episode s3://laufendentdecken-podcast/$episodeWithPostNumber
    aws s3 cp s3://laufendentdecken-podcast/$episodeWithPostNumber s3://laufendentdecken-podcast-backup/

    if [[ "$ad" = "true" ]]; then
        aws s3 cp $episodeAdFree s3://laufendentdecken-podcast/$episodeAdFreeWithPostNumber
        aws s3 cp s3://laufendentdecken-podcast/$episodeAdFreeWithPostNumber s3://laufendentdecken-podcast-backup/
    fi
fi

if [ $? -ne 0 ]; then
  exit 1
fi

if [[ -z "$skipAuphonic" ]]; then
    episodePreset="WbQunVJaZFitr3z74XTyxJ"
    youtubePreset="M9ageytQCjaFAYn7EjSYPZ"

    description=$(pbpaste | tr '\n' ' ')
    youtubeDescription=$(echo -e "${description}\n\nHört rein auf:\n🔗Https://laufendentdecken.at/$postNumber/\n\nUnd natürlich auf\n🎧Spotify, iTunes, Google Podcast, zencastr und in allen podcatchern über das RSS Feed.\n\n✅ Folge uns auf Instagram @laufendentdeckenpodcast , @floderandere und @redendentdecken\n\nUnd auf Facebook https://www.facebook.com/laufendentdeckenpodcast/\n\nWer uns unterstützen mag: https://www.patreon.com/laufendentdecken\noder Steady: https://steadyhq.com/de/laufendentdecken")

    lep auphonic  \
        --production_name $title \
        --preset $episodePreset\
        --cover_url $coverUrl \
        --file $episodeWithPostNumber \
        --slug $slug 

    if [[ -z "$skipYoutube" ]]; then
        lep auphonic  \
            --production_name "LEP#$postNumber - $postTitle" \
            --preset $youtubePreset \
            --cover_url $coverUrlYoutube \
            --file $episodeWithPostNumber \
            --slug $slug \
            --description "$youtubeDescription"
    fi

    if [[ "$ad" = "true" ]]; then
        lep auphonic  \
            --production_name "$title (adfree)" \
            --preset $episodePreset \
            --cover_url $coverUrl \
            --file $episodeAdFreeWithPostNumber \
            --slug $slug
    fi

    echo " Podcast successfully uploaded"
fi

if [ $? -ne 0 ]; then
  exit 1
fi

if [[ -z "$skipDownload" ]]; then
    echo
    echo " Download adfree version again to be able to upload it to patroen/steady"
    lep download --file "$slugAdFree.mp3" 
fi

if [ $? -ne 0 ]; then
  exit 1
fi

if [[ -z "$skipBlogpost" ]]; then
    echo
    echo "󰜏Create Episode on Website"

    if [[ "$ad" = "false" ]]; then
        lep blogpost \
            --number $postNumber \
            --title "$postTitle" \
            --publish_date "$postDate $defaultAirTime" \
            --slug $slug
    fi   

    if [[ -n "$ag1" ]]; then
        lep blogpost \
            --number $postNumber \
            --title "$postTitle" \
            --publish_date "$postDate $defaultAirTime" \
            --slug $slug \
            --ag1
    fi

    if [[ -n "$polestar" ]]; then
        lep blogpost \
            --number $postNumber \
            --title "$postTitle" \
            --publish_date "$postDate $defaultAirTime" \
            --slug $slug \
            --polestar
    fi

fi

if [[ -z "$skipYoutube" ]]; then
    echo
    echo " Schedule youtube video"
    lep youtube \
        --title "LEP#$postNumber" \
        --publish_date "$postDate $defaultAirTime"
fi
