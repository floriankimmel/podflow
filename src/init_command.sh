folder=$(basename "$(pwd)")
touch "$folder.md"
window=$(tmux display-message -p '#I')
tmux rename-window -t Aufnahmen:$window $folder
fish -c "vim $folder.md"
