episode=${args[--m4a]}
skipFtp=${args[--skip-ftp]}
skipAws=${args[--skip-aws]}
skipAuphonic=${args[--skip-auphonic]}
skipPatreon=${args[--skip-patreon]}
skipBlogpost=${args[--skip-blogpost]}

echo $episode

op signin --account my.1password.com

read -p "Episode Nummer: " postNumber
read -p "Episode Titel: " postTitle
read -p "Release (YYYY-MM-DD): " postDate

title=$(echo "$episode" | cut -d'.' -f 1)
chapters=$(<"$title".chapters.txt)
cover="$title".png

episode_patreon="$title"_patreon.m4a
title_patreon="$title"_patreon

coverYoutube="$title"_youtube.png
baseUrl="https://rssfeed.laufendentdecken-podcast.at/data/"

coverUrl="$baseUrl$cover"
coverUrlYoutube="$baseUrl$coverYoutube"

server_pwd=$(op item get "LEP_FTP" --format json | jq -r '. | .fields | .[] | select(.label=="password") | .value')
sudo=$(op item get "sudo" --format json | jq -r '. | .fields | .[] | select(.label=="password") | .value')
server_username=$(op item get "LEP_FTP" --format json | jq -r '. | .fields | .[] | select(.label=="username") | .value')

if ! [[ -n "$skipFtp" ]]; then
    echo "Upload episode to FTP Server"
    curl --user $server_username:$server_pwd --upload-file $episode ftp://rssfeed.laufendentdecken-podcast.at
    echo "Upload patreon episode to FTP Server"
    curl --user $server_username:$server_pwd --upload-file $episode_patreon ftp://rssfeed.laufendentdecken-podcast.at
    echo "Upload cover to FTP Server"
    curl --user $server_username:$server_pwd --upload-file $cover ftp://rssfeed.laufendentdecken-podcast.at
    echo "Upload youtube cover to FTP Server"
    curl --user $server_username:$server_pwd --upload-file $coverYoutube ftp://rssfeed.laufendentdecken-podcast.at
fi

if ! [[ -n "$skipAws" ]]; then
    echo "Backup to S3"

    aws s3 cp $episode s3://laufendentdecken-podcast/
    aws s3 cp s3://laufendentdecken-podcast/$episode s3://laufendentdecken-podcast-backup/

    aws s3 cp $episode_patreon s3://laufendentdecken-podcast/
    aws s3 cp s3://laufendentdecken-podcast/$episode_patreon s3://laufendentdecken-podcast-backup/
fi

if ! [[ -n "$skipAuphonic" ]]; then
    lep auphonic  \
        --production_name $title \
        --preset "WbQunVJaZFitr3z74XTyxJ" \
        --cover_url $coverUrl \
        --file $episode \
        --slug $title

    lep auphonic  \
        --production_name "$title (Youtube)" \
        --preset "M9ageytQCjaFAYn7EjSYPZ" \
        --cover_url $coverUrlYoutube \
        --file $episode \
        --slug $title

    lep auphonic  \
        --production_name "$title (Patreon/Steady)" \
        --preset "WbQunVJaZFitr3z74XTyxJ" \
        --cover_url $coverUrl \
        --file $episode_patreon \
        --slug $title
    echo "Podcast successfully uploaded"
fi

if ! [[ -n "$skipPatreon" ]]; then
    echo "Download Patreon again to be able to upload it to the server"
    curl https://rssfeed.laufendentdecken-podcast.at/data/$title_patreon.mp3 --output ~/Downloads/$title_patreon.mp3
fi

if ! [[ -n "$skipBlogpost" ]]; then
    echo "Create Episode on Website"

    lep create-blogpost \
        --number $postNumber \
        --title $postTitle \
        --publish_date $postDate \
        --slug $title

fi
