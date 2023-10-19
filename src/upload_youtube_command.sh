defaultAirTime="09:00:00"
episode=$(basename "$(pwd)")
episode="$episode.m4a"

baseUrl="https://rssfeed.laufendentdecken-podcast.at/data/"
title=$(echo "$episode" | cut -d'.' -f 1)

IFS=',' read -r postNumber postTitle postDate <<< "$(head -n 1 "$title"".txt")"

coverYoutube="$title"_youtube.png
coverYoutubeWithPostNumber="$postNumber"_"$coverYoutube"
coverUrlYoutube="$baseUrl$coverYoutubeWithPostNumber"

slug="$postNumber"_"$title"
youtubePreset=$(op read "op://Podcast/Auphonic Api/youtubePreset") 
youtubeDescription=$(echo -e "\n\nHört rein auf:\n🔗Https://laufendentdecken.at/$postNumber/\n\nUnd natürlich auf\n🎧Spotify, iTunes, Google Podcast, zencastr und in allen podcatchern über das RSS Feed.\n\n✅ Folge uns auf Instagram @laufendentdeckenpodcast , @floderandere und @redendentdecken\n\nUnd auf Facebook https://www.facebook.com/laufendentdeckenpodcast/\n\nWer uns unterstützen mag: https://www.patreon.com/laufendentdecken\noder Steady: https://steadyhq.com/de/laufendentdecken")
episodeWithPostNumber="$postNumber"_"$episode"

echo "██╗     ███████╗██████╗      ██████╗██╗     ██╗";
echo "██║     ██╔════╝██╔══██╗    ██╔════╝██║     ██║";
echo "██║     █████╗  ██████╔╝    ██║     ██║     ██║";
echo "██║     ██╔══╝  ██╔═══╝     ██║     ██║     ██║";
echo "███████╗███████╗██║         ╚██████╗███████╗██║";
echo "╚══════╝╚══════╝╚═╝          ╚═════╝╚══════╝╚═╝";
echo "                                               ";

lep check

if [ $? -ne 0 ]; then
  exit 1
fi

echo "  Upload youtube cover to FTP Server"
lep ftp --file $coverYoutube --name $coverYoutubeWithPostNumber 

if [ $? -ne 0 ]; then
  exit 1
fi

echo " Automate episode 'LEP#$postNumber - $postTitle' scheduled for $postDate"

lep auphonic  \
    --production_name "LEP#$postNumber - $postTitle" \
    --preset $youtubePreset \
    --cover_url $coverUrlYoutube \
    --file $episodeWithPostNumber \
    --slug $slug \
    --description "$youtubeDescription"

if [ $? -ne 0 ]; then
  exit 1
fi

echo
echo " Schedule youtube video"
lep youtube \
    --title "LEP#$postNumber" \
    --publish_date "$postDate $defaultAirTime"
