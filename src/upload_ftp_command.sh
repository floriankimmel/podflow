file=${args[--file]}

server_pwd=$(op item get "LEP_FTP" --format json | jq -r '. | .fields | .[] | select(.label=="password") | .value')
server_username=$(op item get "LEP_FTP" --format json | jq -r '. | .fields | .[] | select(.label=="username") | .value')

curl --user $server_username:$server_pwd --upload-file $file ftp://rssfeed.laufendentdecken-podcast.at
