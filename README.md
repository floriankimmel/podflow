# Laufent Entdecken CLI

A cli tool to automate everthing related to upload and manage the laufend entdecken podcast. A typical automation worklow does the following steps

* Check if all preconditions are met (command: `check`)
* Try to detect if adfree version is available and if not provided let user
  choose which type of add should be used
* Generate metadata like title, number and schedule date
  * title: Choose a template and use title of file to determine guest
    automatically
  * number: store last episode number in 1password and use that to calculate
    next episode number  
  * schedule date: calculate date of next friday  
* Uploads adfree, non-adfree, cover thumbnail and youtube cover thumbnail to our own ftp server (command: `ftp`)
* Backup all those file to 2 s3 buckets in 2 different regions 
* Start auphonic productions for (command: `auphonic`)
  * non-adfree version of the epsiode
  * youtube version of the episode
  * adfree version of the episode
* Downloads the result of the adfree production to `~/Downloads` so I can create the Patreon/Steady HQ posts by hand
* Create Blogpost on our wordpress site (command: `blogpost`)
* Schedule youtube video  (command: `youtube`)

Everystep can be skipped with an approriate skip flag. 

Certain ad partners are currently supported
* ag1

With providing a specified flag the content of the blogpost will be adapted accordingly.

## Dependencies
Bash script is written with the support of [Bashly](https://bashly.dannyb.co/). For more details on how to setup bashly look at the [Installation guide](https://bashly.dannyb.co/installation/)

## How To

Run `lep --help` for any help.


