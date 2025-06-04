# 🎙️ Podflow

A CLI tool to automate everything related to uploading a podcast episode. It is highly configurable to your specific needs.
## 🫶 Features
- 💡 Fully configurable - define your own workflow  
-  🧠 Stateful. Each successful step will not be executed again.  
-  🎖️ Choose from different services like FTP (delete, upload and download), [Amazon S3](https://aws.amazon.com/de/s3/), [Auphonic](https://auphonic.com/), [SteadyHQ](https://steadyhq.com/en/).  
-  🔖 Create chapter marks independent of the audio recording tool.  
## 📦 Installation

Find all the releases [here](https://github.com/floriankimmel/laufenentdecken-cli/releases). Either download it directly from there or install it directly from the source using Go's install command.

```bash
go install github.com/floriankimmel/podflow@latest
```

### 🍯 Homebrew

If you are on macOS, you can also use [Homebrew](https://brew.sh/) to install podflow.

```bash
brew tag floriankimmel/podflow
brew install podflow
```

## 🎙️ Usage

### 🔖 Chapter Marks

During the recording, you can create chapter marks independent of your recording software. Each mark will be stored in the state.yml of the project.

```bash
podflow chapter start | end | add | toggle-pause
```
| Argument      | Description |
| ------------- | -------------------------------
| `start`| Mark the time when the recording has started. |
| `add` | Add a new chapter mark |
| `end` | Mark the time the recording has ended |
| `toggle-pause` | Start/End a pause. This time will be subtracted when exporting the chapter marks |

To export chapter marks to a [Ultraschall](https://ultraschall.fm/), [Podlove](https://docs.podlove.org/), and [Auphonic](https://auphonic.com) compatible format, use

```bash
podflow chapter export
```

To start publishing an episode, move to the folder containing all the necessary files and run:

### 🏁 Publishing

```bash
podflow publish
```

This will first check if all preconditions are met and afterwards execute each configured step.

To just check if all requirements are met before starting the upload run:

```bash
podflow check
```

## 📂 Open
```bash
podflow open
```

The open command opens the current episode in WordPress in your browser.

## 💻 State

```bash
podflow state
```

The state command shows you the current state of the episode in a human-readable way.
### How does it work?

Sometimes services are not available, and errors can happen. Therefore, Podflow is stateful and makes executing the command again and again very easy. Everything that has already happened successfully will be remembered in `{{folderName}}.state.yml`, which makes it possible for Podflow to continue where it left off.

### 🧑‍💻 Wordpress
```yml
- wordpress:
    wordpressID: "1"
    podloveID: "2"
    featuredMediaID: "3"
```

We do store everything related to the WordPress article to make sure there are no unwanted side effects when rerunning the scheduled task.
### 🧑‍💻 Metadata
```yml
- metadata:
    episodeNumber: "239"
    releaseDate: "2025-01-12 09:00:00"
    title: Test
```

| Argument        | Description                                                                              |
| --------------- | ---------------------------------------------------------------------------------------- |
| `episodeNumber` | Episode number taken from the configuration and increased by 1. It can also be a string. |
| `releaseDate`   | The actual specific datetime when this episode should be released to the public.         |
| `title`         | Title provided by the user.                                                              |

### ✅ Successfully executed steps

```yml
ftpUploaded: true
ftpDeleted: true
s3Uploaded: true
auphonicProduction: true
wordpressBlogCreated: true
steadyHqCreated: true
downloaded: true
```

If present, the associated step has been executed successfully and will not be tried again.
### 🔖 Chapter marks

```yml
chapterMarks:
   - name: Start
     time: 2024-02-20T13:26:29.597423+01:00
```

If chapter marks were added during the recording, they are part of the state file ready to be exported.
## 📦 Archive

Part of the lifecycle of a podcast episode is to archive it once it is published. You don't want to delete the entire production because it might be needed in the future. So with 

```bash
podflow archive <Foldername>
```

the production can be moved to a configured archive folder. The necessary configuration can be found in the next section.
## ⚙️ Configuration

### Loading configuration

By default, Podflow looks for a configuration in the `$HOME\.config\config.yml` file. If there is a need for different configuration files, the default name `config.yml` can be overwritten by using the environment variable `PODFLOW_CONFIG_FILE`. So, by running

```bash
PODFLOW_CONFIG_FILE=test.yml podflow check
```

podflow will load `$HOME\.config\test.yml`.

### General meta information

General information about the release of an episode

```yml
currentEpisode: 240
releaseDay: Friday
releaseTime: "09:00:00"
```
| Argument      | Description |
| ------------- | -------------------------------
| `currentEpisode` | Current episode number. It will be updated once a new episode has been published |
| `releaseDay` | Day of the week: Monday, Tuesday, Wednesday, Thursday, Friday, Saturday, or Sunday |
| `releaseTime` | Time of day (hh:mm:ss): 09:00:00 |

So episode #`currentEpisode` will be released next `releaseDay` at `releaseTime`.
### Precondition(s)

To ensure everything is ready to start the upload workflow, certain checks can be configured.

```yml
files:
    - name: File
      fileName: 'file.m4a'
      required: true | false
      notEmpty: true | false
      umlauteNotAllowed: true | false
```

| Argument      | Description |
| ------------- | -------------------------------
| `fileName` | Path of the file. Placeholders can be used here |
| `required` | If set to true, uploading won't start without this file being present |
| `notEmpty` | If set to true, uploading won't start without the file size being greater than 0 |
| `umlauteNotAllowed` | If set to true, uploading won't start if the file name contains umlauts (ä, ü, ö) |

This configuration is used by both commands `check` and `publish`.

### Placeholders

| Placeholder      | Description |
| ------------- | -------------------------------
| `{{folderName}}` | Folder in which this script is executed |
| `{{episodeNumber}}` | Currently configured episode number |
| `{{env.ENV_VARIABLE}}` | Any environment variable. Preferred way to store secrets |

### Steps

Combination of services that make up the automated podcast workflow.

```yml
steps:
    - ftp: ...
    - s3: ...
    - auphonic: ...
    - download: ...
    - wordpress: ...
    - steadyhq:: ...
```

#### FTP

```yml
    -ftp:
        host: ftp.host.at
        port: "21"
        username: "{{env.FTP_USER}}"
        password:  "{{env.FTP_PWD}}"
        files:
          - source: '{{folderName}}.m4a'
            target: '{{episodeNumber}}_{{folderName}}.m4a'
```

| Argument      | Description |
| ------------- | -------------------------------
| `source` | File name on your local machine |
| `target` | File name on the FTP server |

#### Delete FTP Files

```yml
    -ftp:
        host: ftp.host.at
        port: "21"
        username: "{{env.FTP_USER}}"
        password:  "{{env.FTP_PWD}}"
        delete:
          - target: '{{episodeNumber}}_{{folderName}}.m4a'
```

| Argument      | Description |
| ------------- | -------------------------------
| `target` | File name on the FTP server |

#### Amazon S3

```yml
    - s3:
        buckets:
          - region: amazon-region-id
            name: bucket-name
            files:
              - source: '{{folderName}}.m4a'
                target: '{{episodeNumber}}_{{folderName}}.m4a'
```

| Argument      | Description |
| ------------- | -------------------------------
| `region` | Region ID defined by Amazon: eu-central-1 |
| `name` | Name of the S3 bucket |
| `source` | File name on your local machine |
| `target` | File name in the S3 bucket |

#### Auphonic

Enhance your audio quality with [Auphonic](https://auphonic.com/)

```yml
    - auphonic:
        username: auphonic-username
        password: "{{env.AUPHONIC_PWD}}"
        preset: preset
        fileServer: fileserver
        title: "{{episodeTitle}}"
        files:
          - episode: '{{episodeNumber}}_{{folderName}}.m4a'
            image: '{{episodeNumber}}_{{folderName}}.png'
            chapters: '{{episodeNumber}}_{{folderName}}.chapters.txt'
```

| Argument      | Description |
| ------------- | -------------------------------
| `preset` | UUID of the referenced preset; you can find it on the [Preset Page](https://auphonic.com/engine/presets/) |
| `fileServer` | URL of the server Auphonic tries to get the audio/image/chapter data from |
| `title` | Auphonic title. The only field that allows `{{episodeTitle}}` as a placeholder |
| `episode` | File name of the episode. If the file is not present, production will not be started |
| `image` | File name of the episode image. |
| `chapters` | File name of the episode chapters file. |

#### Download

Download files to the local machine. The current use case is to download Auphonic output afterwards in order to upload it manually to Patreon/Steady.

```yml
    - download:
        host: ftp.host.at
        port: "21"
        username: "{{env.FTP_USER}}"
        password:  "{{env.FTP_PWD}}"
        files:
          - target: '{{episodeNumber}}_{{folderName}}.m4a'
            source: '{{episodeNumber}}_{{folderName}}.m4a'
```

| Argument      | Description |
| ------------- | -------------------------------
| `target` | File name on your local machine |
| `source` | File name in the S3 bucket |

#### Wordpress

Schedule WordPress blog post. [Podlove](https://podlove.org/) version 4 (or higher) is required to be installed on the WordPress site.

```yml
    - wordpress:
        apiKey: "{{env.WORDPRESS_API_KEY}}"
        server: wordpress.server.at
        episode: '{{episodeNumber}}_{{folderName}}'
        image: '{{folderName}}.png'
        showNotes: '{{folderName}}.md'
        chapter: '{{folderName}}.chapters.txt'
```

| Argument      | Description |
| ------------- | -------------------------------
| `episode` | File name of the episode without extension. This is used to link your Auphonic production with Podlove |
| `image` | Featured image of the post |
| `showNotes` | Blog post content |
| `chapter` | Chapters used for the Podlove web player |

#### SteadyHq

Schedule SteadyHQ audio posts.

```yml
    - steadyhq:
        apiKey: '{{env.STEADYHQ_API_KEY}}'
        title: 'LEP#{{episodeNumber}} - {{episodeTitle}}'
        image: http://{{episodeNumber}}.png
        episode: http://{{episodeNumber}}.mp3
        showNotes: '{{folderName}}.md'
```

| Argument      | Description |
| ------------- | -------------------------------
| `episode` | URL of the episode |  
| `title` | Title of the episode |  
| `image` | URL of the featured image |  
| `showNotes` | File of blog post content |  

### Archive

```yaml
archive:
	target: <foldername>
```

Specify a folder where the podcast production should be archived. Currently, only folders are supported; no FTP or anything else. If you want to store it on a different server or even a NAS, you would need to mount it.

### Example used by the laufendentdecken podcast

```yml
currentEpisode: 240
releaseDay: Friday
releaseTime: "09:00:00"
files:
    - name: Episode
      fileName: '{{folderName}}.m4a'
      required: true
      notEmpty: false
      umlauteNotAllowed: false
    - name: Shownote
      fileName: '{{folderName}}.md'
      required: true
      notEmpty: true
      umlauteNotAllowed: false
    - name: Cover
      fileName: '{{folderName}}.png'
      required: true
      notEmpty: false
      umlauteNotAllowed: false
    - name: Chapters
      fileName: '{{folderName}}.chapters.txt'
      required: true
      notEmpty: false
      umlauteNotAllowed: false
archive:
	target: <folder>
steps:
    - ftp:
        host: ftp.host.at
        port: "21"
        username: "{{env.FTP_USER}}"
        password:  "{{env.FTP_PWD}}"
        files:
          - source: '{{folderName}}.m4a'
            target: '{{episodeNumber}}_{{folderName}}.m4a'
          - source: '{{folderName}}.png'
            target: '{{episodeNumber}}_{{folderName}}.png'
          - source: '{{folderName}}.chapters.txt'
            target: '{{episodeNumber}}_{{folderName}}.chapters.txt'

    - s3:
        buckets:
          - region: eu-central-1
            name: main-bucket
            files:
              - source: '{{folderName}}.m4a'
                target: '{{episodeNumber}}_{{folderName}}.m4a'
              - source: '{{folderName}}.png'
                target: '{{episodeNumber}}_{{folderName}}.png'
              - source: '{{folderName}}.chapters.txt'
                target: '{{episodeNumber}}_{{folderName}}.chapters.txt'
          - region: eu-west-3
            name: backup-bucket
            files:
              - source: '{{folderName}}.m4a'
                target: '{{episodeNumber}}_{{folderName}}.m4a'
              - source: '{{folderName}}.png'
                target: '{{episodeNumber}}_{{folderName}}.png'
              - source: '{{folderName}}.chapters.txt'
                target: '{{episodeNumber}}_{{folderName}}.chapters.txt'

    - auphonic:
        username: "{{env.AUPHONIC_USERNAME}}"
        password: "{{env.AUPHONIC_PWD}}"
        preset: <auphonic-preset>
        fileServer: "http://fileserver.at/"
        title: "{{episodeTitle}}"
        files:
          - episode: '{{episodeNumber}}_{{folderName}}.m4a'
            image: '{{episodeNumber}}_{{folderName}}.png'
            chapters: '{{episodeNumber}}_{{folderName}}.chapters.txt'
          - episode: '{{episodeNumber}}_{{folderName}}_adfree.m4a'
            image: '{{episodeNumber}}_{{folderName}}.png'
            chapters: '{{episodeNumber}}_{{folderName}}.chapters.txt'

    - download:
        host: ftp.host.at
        port: "21"
        username: "{{env.FTP_USER}}"
        password:  "{{env.FTP_PWD}}"
        files:
          - target: '{{episodeNumber}}_{{folderName}}.m4a'
            source: '{{episodeNumber}}_{{folderName}}.m4a'

    - wordpress:
        apiKey: "{{env.WORDPRESS_API_KEY}}"
        server: "https://your-wordpress-url.at"
        episode: '{{episodeNumber}}_{{folderName}}'
        image: '{{folderName}}.png'
        showNotes: '{{folderName}}.md'
        chapter: '{{folderName}}.chapters.txt'

    - steadyhq:
        apiKey: '{{env.STEADYHQ_API_KEY}}'
        title: 'LEP#{{episodeNumber}} - {{episodeTitle}}'
        image: http://rssfeed.laufendentdecken-podcast.at/data/{{episodeNumber}}_{{folderName}}.png
        episode: http://rssfeed.laufendentdecken-podcast.at/data/{{episodeNumber}}_{{folderName}}.mp3
        showNotes: '{{folderName}}.md'

    - ftp:
        host: rssfeed.laufendentdecken-podcast.at
        port: "21"
        username: '{{env.FTP_USER}}'
        password: '{{env.FTP_PWD}}'
        delete:
            - target: '{{episodeNumber}}_{{folderName}}.chapters.txt'


```
# ✍️ Author
Florian Kimmel [florian@le-podcast.at](mailto:florian@le-podcast.at)
