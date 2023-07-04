file=${args[--file]}
name=${args[--name]}

server_pwd=$(op item get --vault Podcast "FTP" --fields label=credential)
server_username=$(op item get --vault Podcast "FTP" --fields label=username)

curl --user $server_username:$server_pwd --upload-file $file ftp://rssfeed.laufendentdecken-podcast.at/$name
