file=${args[--file]}
name=${args[--name]}

server_pwd=$(op read "op://Podcast/ahvoh5qmumxyrtvih2klge7uqa/credential")
server_username=$(op read "op://Podcast/ahvoh5qmumxyrtvih2klge7uqa/username")

curl --user $server_username:$server_pwd --upload-file $file ftp://rssfeed.laufendentdecken-podcast.at/$name
