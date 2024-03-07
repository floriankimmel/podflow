# 🎙️ Podflow

A CLI tool to automate everything related to uploading a podcast episode. It is
highly configurable to your specific needs.

## 🫶 Features
- 💡 Fully configurable - define your own workflow
- 🧠 Statefull. Each successful step will not be executed again.
- 🎖️ Choose from different services like FTP (Up- and Download), Amazon S3, Auphonic.
- 🔖 Create chapter marks independent of audio recording tool.

## 📦 Installation

Find all the releases [here](https://github.com/floriankimmel/laufenentdecken-cli/releases). Ether
download it there directly or install directly from source with Go's install command

```bash
go install github.com/floriankimmel/podflow@latest
```

## 🎙️ Usage

### 🔖 Chapter Marks

During recording you can create chapter marks independent of your recording software. Each mark will be stored in the
state yml of the project

```bash
podflow chapter start | end | add | toggle-pause
```
| Argument      | Description |
| ------------- | -------------------------------
| `start`| Mark the time the recording has started |
| `add` | Add a new chapter mark|
| `end` | Mark the time the recording has ended |
| `toggle-pause` | Start/End a pause. This time will be substracted when exporting the chapter marks |

To export chapter marks to a [Ultrashall](https://ultraschall.fm/), [Podlove](https://docs.podlove.org/) and [Auphonic](https://auphonic.com) compatible format use

```bash
podflow chapter export
```

To start publishing a episode move to the folder containing all the necessary files and run:

### 🏁 Publishing

```bash
podflow publish
```
This will first check if all preconditions are met and afterwards executed each configured step.

To just check if all requirements are met before starting the upload run:

```bash
podflow check
```

## 💻 State

Sometimes services are not available and errors can happen. Therefore podflow is statefull and
makes executing the command again and again very easy. Everyting that already happened successfully
will be remember in `{{folderName}}.state.yml` which makes it possible for podflow to continue where it left off.

### 🧑‍💻 Metadata
```yml
- metadata:
    episodeNumber: 239
    releaseDate: "2025-01-12 09:00:00"
    title: Test
```
| Argument      | Description |
| ------------- | -------------------------------
| `episodeNumber` | Episode number taken from the configuration and increased by 1|
| `releaseDate` | The actualy spefic datetime when this episode should be release to the public |
| `title` | Title provided by the user |

### ✅ Successfully executed steps

```yml
ftpUploaded: true
s3Uploaded: true
auphonicProduction: true
wordpressBlogCreated: true
downloaded: true
```

If present the associated step has been executed successfully and will not be tried anymore.

### 🔖 Chapter marks

```yml
chapterMarks:
   - name: Start
     time: 2024-02-20T13:26:29.597423+01:00
```

If during recording chapter marks were added they are part of the state file ready to be exported

## ⚙️ Configuration

### Loading configuration

By default podflow looks for a configuration in the `$HOME\.config\config.yml` file. If there is a need for different configuration files
the default name `config.yml` can be overwritten by using the environment variable `PODFLOW_CONFIG_FILE`. So by running

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
| `currentEpisode` | Current Episode number. Will be updated once a new episode has been published |
| `releaseDay` |  Day of the week: Monday, Tuesday, Wednesday, Thursday, Friday, Saturday or Sunday |
| `releaseTime` | Time of day (hh:mm:ss): 09:00:00 |

So episode #`currentEpisode` will be release next `releaseDay` at `releaseTime`.

### Precondition(s)

To ensure everyting is ready to start the upload workflow certain checks can be configured

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
| `required` | If set to true uploading won't start without this file beeing present |
| `notEmpty` | If set to true uploading won't start without the filesize greater 0  |
| `umlauteNotAllowed` | If set to true uploading won't start without the file name containing umlaute (ä, ü, ö)|

This configuration is used by both commands `check` and `publish`.

### Placeholders

| Placeholder      | Description |
| ------------- | -------------------------------
| `{{folderName}}` | Folder this script is executed in |
| `{{episodeNumber}}` | Currently configured episode number |
| `{{env.ENV_VARIABLE}}` | Any environment variable. Prefered way to store secrets |

### Steps

Combination of services that make up the automated podcast workflow.

```yml
steps:
    - ftp: ...
    - s3: ...
    - auphonic: ...
    - download: ...
    - wordpress: ...
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
| `target` | File name on the ftp server |

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
| `region` | Region id defined by amazon: eu-central-1 |
| `name` | Name of the s3 bucket|
| `source` | File name on your local machine |
| `target` | File name in the s3 bucket |

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
| `preset` | UUID of the referenced preset, you can find it on the [Preset Page](https://auphonic.com/engine/presets/) |
| `fileServer` | Url of the server auphonic tries to get the audio/image/chapter data from |
| `title` | Auphonic title. Only field that allows `{{episodeTitle}}` as a placeholder  |
| `episode` | File name of the episode. If file is not present production will not be started|
| `image` | File name of the episode image.|
| `chpaters` | File name of the episode chapters file.|

#### Download

Download files to local machine. Current use case is to download auphonic output
afterwards in order to upload it manually to patroen/steady.

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
| `source` | File name in the s3 bucket |

#### Wordpress

Schedule wordpress blogpost. [Podlove](https://podlove.org/) Version 4 (or higher) is required to
be installed on the wordpress site.

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
| `episode` | File name of the episode without extension. This is used to link your auphonic production with podlove |
| `image` | Featured Image of post |
| `showNotes` | Blog post content |
| `chapter` | Chapters used for podlove webplayer |

### Example

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

```
# ✍️ Author
Florian Kimmel [florian@le-podcast.at](mailto:florian@le-podcast.at)
