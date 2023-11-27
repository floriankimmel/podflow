skipYoutube=${args[--skip-youtube]}

folder=$(basename "$(pwd)")
episode=$folder
error=0
counter=1

while [ -e "$folder-$counter.m4a" ]; do
    episode="$folder-$counter"
    ((counter++))
done

echo "Checking for $episode.m4a"

if [[ $episode =~ [öüäÖÜÄ] ]]; then
  echo -e "\e[31m Episode title contains Umlaute \e[0m"
  error=1
else
  echo -e "\e[32m Episode title does not have Umlaute\e[0m"
fi

if [[ -e "$episode.m4a" ]]; then
    echo -e "\e[32m Episode is already exported\e[0m"
else 
    echo -e "\e[31m No Episode is exported to automate\e[0m"
    error=1
fi

if [[ -e "${episode}_adfree.m4a" ]]; then
    echo -e "\e[32m Adfree Episode is already exported\e[0m"
else
    echo -e "\e[33m No Adfree Episode \e[0m"
fi

if [[ -e "$episode.md" ]]; then
    echo -e "\e[32m Episode description exists\e[0m"
else 
    echo -e "\e[31m No Episode description available\e[0m"
    error=1
fi

if [[ -s "$episode.md" ]]; then
    echo -e "\e[32m Episode description is not empty\e[0m"
else 
    echo -e "\e[31m Episode description is empty\e[0m"
    error=1
fi

if [[ -e "$episode.png" ]]; then
    echo -e "\e[32m Episode thumbnail exists\e[0m"
else 
    echo -e "\e[31m No Episode thumbnail available\e[0m"
    error=1
fi


if [[ -z "$skipYoutube" ]]; then
    if [[ -e "${episode}_youtube.png" ]]; then
        echo -e "\e[32m Episode youtube thumbnail exists\e[0m"
    else 
        echo -e "\e[31m No Episode youtube thumbnail available\e[0m"
        error=1
    fi
fi

if [[ -e "$episode.chapters.txt" ]]; then
    echo -e "\e[32m Episode chapters exists\e[0m"
else 
    echo -e "\e[31m No Episode chapters available\e[0m"
    error=1
fi

exit $error
