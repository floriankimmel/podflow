# Laufend Entdecken CLI

A CLI tool to automate everything related to uploading and managing the "Laufend Entdecken" podcast. A typical automation workflow would include these steps:

* Check if all preconditions are met (Command: `Check`)
* Try to detect if an ad-free version is available, and if not, let the user choose which type of ad they want to use.
* Generate metadata such as title, number, and schedule date.
  * title: Choose a template and use the title of the file to determine the guest automatically.
  * number: Store the last episode number in 1Password and use it to calculate the next episode number  
  * schedule date: Calculate the date of the next Friday  
* Upload ad-free, non-ad-free, cover thumbnail and YouTube cover thumbnail to our own FTP server using the command `ftp`.
* Back up all those files to two S3 buckets in two different regions.s 
* Start Auphonic Productions (Command: `auphonic`)
  * The non-adfree version of the episode
  * the YouTube version of the episode
  * an ad-free version of the episode
* Download the result of the ad-free production to recording folder so that I can create Patreon/Steady HQ posts manually (command: download))
* Create a blog post on our WordPress site. (Command: `blogpost`))
* Schedule YouTube video (command: `youtube`)

Every step can be skipped using an appropriate skip flag. 

Certain ad partners are currently supported
* ag1
* polestar

By providing a specified flag, the content of the blog post will be adapted accordingly.

## Dependencies
A Bash script is written with the support of Bashly. For more details on how to set up Bashly, please refer to the Installation guide.

## How To

Run `lep --help` for any help.


