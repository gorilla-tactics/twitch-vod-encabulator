# Twitch VOD Encabulator

This repository provides a script to **back up your Twitch VODs**, including video files and metadata, using the [Twitch API](https://dev.twitch.tv/docs/api/) and [yt-dlp](https://github.com/yt-dlp/yt-dlp). The scripts also rely on [jq](https://github.com/jqlang/jq), curl, bash, python3, [EditThisCookie](https://www.editthiscookie.com/), and [Twitch Token Generator](https://twitchtokengenerator.com/). Each VOD is saved in a timestamped folder with all associated metadata files (JSON, thumbnail, description, etc.).

Although the functionality of this repository is relatively benign, this is a general disclaimer that you use this repository at your own risk and the author assumes no responsibility. The repository was created with the help of Copilot and ChatGPT code completion. Licensed under GPLv3, you are free to modify and redistribute as open source. Pull requests welcome!

Happy encabulating! 🍌🦍

---

## 🚀 Features

- Downloads all public and subscriber-only VODs from your Twitch channel
- Saves each stream in a dated folder by VOD type, e.g. `./vods/archive/YYYY-MM-DDTHH-MM-SS - ID - Title/`
- Includes and embeds metadata and thumbnails 
- Retries failed downloads automatically
- Uses your Twitch OAuth token and session cookies for access

---

## ‼️ Security Considerations

This script relies upon your authenticated cookies and OAuth tokens. You should ALWAYS treat these as a password and NEVER share them with anyone. Precautions have been made to avoid inadvertently committing these, but accidents can happen. 

If you think your authentication details are exposed, you should at a minimum reset your Twitch password. You may also want to de-authorize any connected apps, and regenerate your stream key, out of an abundance of caution. Also, if you aren't already, enable 2FA.

## 🔧 Setup

### 1. Clone the Repository

```bash
git clone git@github.com:gorilla-tactics/twitch-vod-encabulator.git
cd twitch-vod-encabulator
```

### 2. Install Dependencies

Ensure these are installed on your system (script will check also):

- [yt-dlp](https://github.com/yt-dlp/yt-dlp)
- [jq](https://github.com/jqlang/jq) (for parsing JSON)
- curl and bash (standard on most systems)
- python3 (optional, for converting cookies)

To install via [Homebrew](https://brew.sh/):

```bash
brew install yt-dlp jq
```

### 3. Export Your Cookies

> [!CAUTION]
> ‼️ Important: ⚠️ NEVER commit these files — they contain private credentials. ‼️

Use the [EditThisCookie](https://www.editthiscookie.com/) browser extension and copy/paste the export as `cookies.json` in `/config` - use included `.cookies.json.template` as reference:

- Go to twitch.tv while logged in
- Export cookies as JSON
- Save as cookies.json
- Run the conversion script:

```bash
python3 convert_cookies.py
```

This creates cookies.txt (in Netscape format) for use with yt-dlp.

### 4. Create a .env File

> [!CAUTION]
> ‼️ Important: ⚠️ NEVER commit this file — it contains private credentials. ‼️

Create a `.env` file in the root of the project using the `.env.template`:

```bash
CLIENT_ID=your_twitch_client_id
OAUTH_TOKEN=your_oauth_token
USER_LOGIN=your_twitch_username
```

### 5. Create a Twitch App & Generate an OAuth Token

To access your VODs via the Twitch API, you'll first need to create a Twitch application to obtain a Client ID. We'll use [Dev Console](https://dev.twitch.tv/) for our Client ID along with [Twitch Token Generator](https://twitchtokengenerator.com/) to help generate the token.

#### Step 1: Register a Twitch Application

1. Visit the Twitch Developer Console
2. Click "Register Your Application"
3. Fill in the fields:
    - Name: Any name you want (e.g. vod-backup)
    - OAuth Redirect URL: https://twitchtokengenerator.com/
    - Category: Choose something like "Application Integration"
    - Client Type: Select Confidential
4. Click Create
5. Copy your new Client ID — you'll need this in the next step

> 💡 You do not need the Client Secret for this script unless you're doing full token refresh logic (not required).

#### Step 2: Generate an OAuth Token

Once you have your Client ID, go to Twitch Token Generator:
1. Choose "User Token"
2. Paste in your Client ID from Step 1
3. Select the following required scopes:
    - `user:read:email`
    - `user:read:broadcast`
4. Log in and authorize the app
5. Copy the generated OAuth token and add it to your `.env` file

## 🧪 Usage

Run the script:

```bash
chmod +x twitch_vod_backup.sh
./twitch_vod_backup.sh [--id VOD_ID] [--url URL] [--date YYYY-MM-DD] [--category NAME] [--type TYPE] [--dry-run]
```

Command flag overview:

- `--category NAME`: Case-insensitive match against the Twitch category (game) title. Falls back to "Unknown" if not present.
- `--type TYPE`: Must be one of archive, highlight, or upload. Filters which types to fetch.
- `--dry-run`: Simulates downloading without saving any files.
- `--id`, `--url`, `--date`: Filters specific VODs by metadata.
- `--help`: Prints available command-line options and exits.

The script will:

- Validate your OAuth token
- Fetch all VOD URLs from your account
- Download them with retries
- Save each one to its own timestamped folder

Behavior notes:

- VODs with no category (game_name) will be shown as "Unknown" and skipped if `--category` is specified. Misspelled or invalid categories will result in 0 matches.
- Downloaded files are named using the VOD ID and a sanitized version of the title.
- File and folder names are sanitized for Windows compatibility using `yt-dlp`’s `--windows-filenames` flag.
- The script checks for already downloaded VODs and skips them unless updated.

## 📁 Example Output

```bash
vods/
├── archive/
│   └── 2025-04-13 - 123456789 - Zelda_Run/
│       ├── 123456789_Zelda_Run.mp4
│       ├── 123456789_Zelda_Run.info.json
│       ├── 123456789_Zelda_Run.description
│       └── 123456789_Zelda_Run.jpg
```

## 📜 Logs

The script writes a list of all discovered VOD URLs to `./config/vod_urls.txt`. This can be useful for archival verification or debugging.

You can safely delete this file between runs — it is regenerated each time.


## ✅ Future Ideas & Todo

- Validate Windows compatibile script
- YouTube exports integration
- Discord post-download hooks
- Auto-trimming & upload via FFmpeg
