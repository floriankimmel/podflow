file=${args[--file]}
folder=$(echo $file | awk -F '_' '{print $2}' | cut -d '.' -f 1)

curl https://rssfeed.laufendentdecken-podcast.at/data/$file --output ~/Dropbox/Resources/Podcast/Aufnahmen/$folder/$file
