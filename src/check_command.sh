folder=$(basename "$(pwd)")
error=0

if [[ -e "$folder.m4a" ]]; then
    echo -e "\e[32m Episode is already exported\e[0m"
else 
    echo -e "\e[31m No Episode is exported to automate\e[0m"
    error=1
fi

if [[ -e "$folder.md" ]]; then
    echo -e "\e[32m Episode description exists\e[0m"
else 
    echo -e "\e[31m No Episode description available\e[0m"
    error=1
fi

if [[ -e "$folder.png" ]]; then
    echo -e "\e[32m Episode picture exists\e[0m"
else 
    echo -e "\e[31m No Episode picture available\e[0m"
    error=1
fi

if [[ -e "${folder}_youtube.png" ]]; then
    echo -e "\e[32m Episode youtube picture exists\e[0m"
else 
    echo -e "\e[31m No Episode youtube picture available\e[0m"
    error=1
fi

if [[ -e "$folder.chapters.txt" ]]; then
    echo -e "\e[32m Episode chapters exists\e[0m"
else 
    echo -e "\e[31m No Episode chapters available\e[0m"
    error=1
fi

exit $error
