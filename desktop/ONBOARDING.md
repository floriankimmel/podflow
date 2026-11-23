# Podflow onboarding for the co-host

You are helping the co-host of the Laufend Entdecken podcast set up and use
**Podflow**, the Mac app that turns a finished episode video into YouTube,
podcast audio, shownotes, social posts and a scheduled WordPress post.

## How to work with the co-host

- Speak German, in plain words. The co-host is not technical: no jargon, one
  step at a time, wait until each step is done before the next.
- Do the checks yourself with the terminal where you can (listed below), so the
  co-host only has to click in the app and the browser.
- **Never ask for passwords, keys or access data, and never accept them in the
  chat.** The co-host types them directly into the app. If they paste one into
  the chat anyway, tell them to change it with Florian.
- Don't edit files in episode folders, don't run the Podflow plugin or
  `claude -p` yourself, and don't change app settings files. The app does all
  of that.

## 1. Install the app

1. Find the newest version:
   ```sh
   curl -sL https://github.com/floriankimmel/podflow/releases/download/desktop-appcast/appcast.xml | grep -o 'https://[^"]*\.dmg'
   ```
   Open that link in the browser (`open <url>`), or download it with
   `curl -L -o ~/Downloads/Podflow.dmg <url>`.
2. Ask the co-host to open the downloaded `Podflow-….dmg` and drag **Podflow**
   onto **Programme** (Applications), then start Podflow from Programme.
3. Check: `ls /Applications/Podflow.app` exists. The app is signed and
   notarized; there must be no "unbekannter Entwickler" warning. If there is,
   stop and tell the co-host to contact Florian.

Updates install themselves later: the app asks when a new version is out
(also via the menu **Podflow → Nach Updates suchen…**).

## 2. First start: "Podflow einrichten"

The setup screen opens automatically.

1. **Claude:** the app checks for Claude Code. It is already installed on this
   Mac (you are running in it). If the app shows **Installieren**, let it.
   Then **Anmelden** opens the browser: the co-host signs in with their own
   Claude account. Check with `claude auth status` (`"loggedIn": true`).
2. **Shared accounts:** the co-host gets the values from Florian (e.g. via
   1Password) and types them into the form:
   - Auphonic: Benutzername, Passwort, Preset-ID
   - WordPress: Schlüssel
   - Podcast-Server (FTP): Benutzername, Passwort
   - Gemeinsamer Status: Workspace-Schlüssel

   Server addresses are prefilled; leave them unchanged.
3. Click **Fertig**.

Everything can be changed later in **Podflow → Einstellungen…** (⌘,). If the
app says "Es fehlt noch: …", the listed accounts are still empty there.

Episodes are stored in `~/Podflow/<Nummer>/`. A different folder can be chosen
in the settings under **Episoden → Ordner → Ändern …**.

## 3. An episode, start to finish

1. **Neue Episode**: Nummer (suggested), Titel, **Art der Folge**:
   - **Zencastr-Aufnahme**: also pick the **Transkript aus Zencastr** file.
   - **Interview-Zusammenschnitt**: Auphonic creates the transcript.

   Pick the **Fertiges Video**, then **Anlegen**.
2. **Starten**: the video goes to Auphonic, then the transcript, shownotes,
   social posts, SEO texts and a fact-check are generated. This takes a while
   (Auphonic alone can take up to two hours). The app can stay open in the
   background; the progress shows step by step.
3. **Review** (tabs at the top):
   - **Shownotes** and **Social Media**: edit freely; changes save
     automatically.
   - **SEO**: everything is filled in automatically except the parts marked
     "von Hand einfügen" (Title Tag, Facebook texts). Copy those into the
     WordPress post later.
   - **Faktencheck**: read what was corrected or could not be verified.
   - **Veröffentlichen**: pick the **Cover** and the **Beitragsbild für die
     Website**, check the date (default: next Friday at the usual time), then
     **Veröffentlichen**.
4. Publishing sends the video to YouTube, the audio to the podcast server and
   schedules the WordPress post. The social posts are copied by hand from the
   **Social Media** tab into Instagram, Facebook, etc.

## When something goes wrong

- **A step failed:** the episode shows the failed step and its reason. Click
  **Erneut versuchen**; finished steps are skipped, the video is not uploaded
  again. If it fails again with the same reason, send Florian a screenshot.
- **"nicht auf diesem Mac":** the episode was created on Florian's Mac. Progress
  is visible, but only that Mac can edit and publish it.
- **Claude not signed in / usage limit:** run `claude auth status`; if signed
  out, use the setup again (**Einstellungen… → Einrichtung erneut
  ausführen…**). Each preparation uses the co-host's own Claude account.
- **Deleting an episode** (right-click → **Episode löschen …**) moves its folder
  to the Trash and removes it from the shared status. Only do this on request.

For anything else (wrong texts from the prompts, Auphonic or WordPress
problems), the co-host should contact Florian rather than work around it.
