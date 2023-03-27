skipFtp=${args[--skip-ftp]}
skipAws=${args[--skip-aws]}
skipAuphonic=${args[--skip-auphonic]}
skipDownload=${args[--skip-download]}
skipBlogpost=${args[--skip-blogpost]}

ag1=${args[--ag1]}

episode=${args[--m4a]}
if [[ -z "$episode" ]]; then
    shopt -s nullglob # um die Schleife zu vermeiden, wenn keine m4a-Dateien vorhanden sind
    for file in ./*.m4a; do
        episode=$(basename "$file")
        break
    done
fi

read -p "Episode Nummer: " postNumber
read -p "Episode Titel: " postTitle
read -p "Release (YYYY-MM-DD): " postDate

title=$(echo "$episode" | cut -d'.' -f 1)
chapters=$(<"$title".chapters.txt)
cover="$title".png

episodeAdFree="$title"_addfree.m4a
titleAdFree="$title"_addfree

coverYoutube="$title"_youtube.png
baseUrl="https://rssfeed.laufendentdecken-podcast.at/data/"

coverUrl="$baseUrl$cover"
coverUrlYoutube="$baseUrl$coverYoutube"

if [[ -z "$skipFtp" ]]; then
    echo
    echo "Upload episode to FTP Server"
    lep ftp --file $episode
    echo "Upload addfree episode to FTP Server"
    lep ftp --file $episodeAdFree
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

    aws s3 cp $episodeAdFree s3://laufendentdecken-podcast/
    aws s3 cp s3://laufendentdecken-podcast/$episodeAdFree s3://laufendentdecken-podcast-backup/
fi

if [ $? -ne 0 ]; then
  exit 1
fi

if [[ -z "$skipAuphonic" ]]; then
    episodePreset = "WbQunVJaZFitr3z74XTyxJ" 
    youtubePreset = "M9ageytQCjaFAYn7EjSYPZ" 

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

    lep auphonic  \
        --production_name "$title (addfree)" \
        --preset $episodePreset \
        --cover_url $coverUrl \
        --file $episodeAdFree \
        --slug $title

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

    if [[ -z "$ag1" ]]; then
        lep blogpost \
            --number $postNumber \
            --title $postTitle \
            --publish_date $postDate \
            --slug $title
    fi   

    if [[ -n "$ag1" ]]; then
        lep blogpost \
            --number $postNumber \
            --title $postTitle \
            --publish_date $postDate \
            --slug $title \
            --ag1
    fi

fi

