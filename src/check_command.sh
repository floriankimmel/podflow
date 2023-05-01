folder=$(basename "$(pwd)")
error=0

if [[ -e "$folder.m4a" ]]; then
    echo -e "\e[32m Episode is already exported\e[0m"
else 
    echo -e "\e[31m No Episode is exported to automate\e[0m"
    error=1
fi

if [[ -e "${folder}_adfree.m4a" ]]; then
    echo -e "\e[32m Adfree Episode is already exported\e[0m"
else
    echo -e "\e[33m No Adfree Episode \e[0m"
fi

if [[ -e "$folder.md" ]]; then
    echo -e "\e[32m Episode description exists\e[0m"
else 
    echo -e "\e[31m No Episode description available\e[0m"
    error=1
fi

if [[ -s "$folder.md" ]]; then
    echo -e "\e[32m Episode description is not empty\e[0m"
else 
    echo -e "\e[31m Episode description is empty\e[0m"
    error=1
fi

if [[ -e "$folder.png" ]]; then
    echo -e "\e[32m Episode thumbnail exists\e[0m"
else 
    echo -e "\e[31m No Episode thumbnail available\e[0m"
    error=1
fi

if [[ -e "${folder}_youtube.png" ]]; then
    echo -e "\e[32m Episode youtube thumbnail exists\e[0m"
else 
    echo -e "\e[31m No Episode youtube thumbnail available\e[0m"
    error=1
fi

if [[ -e "$folder.chapters.txt" ]]; then
    echo -e "\e[32m Episode chapters exists\e[0m"
else 
    echo -e "\e[31m No Episode chapters available\e[0m"
    error=1
fi

exit $error
