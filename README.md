# Twitch VOD Encabulator

This repository provides a script to **back up your Twitch VODs**, including video files and metadata, using the [Twitch API](https://dev.twitch.tv/docs/api/) and [yt-dlp](https://github.com/yt-dlp/yt-dlp). The scripts also rely on [jq](https://github.com/jqlang/jq), curl, bash, python3, [EditThisCookie](https://www.editthiscookie.com/), and [Twitch Token Generator](https://twitchtokengenerator.com/). Each VOD is saved in a timestamped folder with all associated metadata files (JSON, thumbnail, description, etc.).

Although the functionality of this repository is relatively benign, this is a general disclaimer that you use this repository at your own risk and the author assumes no responsibility. The repository was created with the help of Copilot and ChatGPT code completion. Licensed under GPLv3, you are free to modify and redistribute as open source. Pull requests welcome!

Happy encabulating! 🍌🦍

---

## 🚀 Features

- Downloads all public and subscriber-only VODs from your Twitch channel
- Saves each stream in a dated folder: `vods/YYYY-MM-DDTHH-MM-SS - ID - Title/`
- Includes metadata and thumbnails 
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

### 3. Get an OAuth Token

For simplicity you can use [Twitch Token Generator](https://twitchtokengenerator.com/) to create OAuth token:

- Choose "User Token"
- Use your Twitch Client ID
- Select only the following scopes:
  - user:read:email (Required for most read-level APIs)
  - user:read:broadcast (Required to list your VODs (archives) via the API)
- Authenticate and copy your OAuth Token

✅ You only need those two noted scopes for listing and downloading your own VODs.

Optional: It is possible to configure your own application OAuth via [Dev Console](https://dev.twitch.tv/):

- Click "Register Your Application"
- Give it a name
- Set the OAuth Redirect URL to: https://twitchtokengenerator.com/
- Pick a category
- Client type: Confidential
- Save the Client ID and Client Secret

### 4. Export Your Cookies

Use the [EditThisCookie](https://www.editthiscookie.com/) browser extension and copy/paste the export as `cookies.json` in `/config` - use included `.cookies.json.template` as reference:

- Go to twitch.tv while logged in
- Export cookies as JSON
- Save as cookies.json
- Run the conversion script:

```bash
python3 convert_cookies.py
```

This creates cookies.txt (in Netscape format) for use with yt-dlp.

> ‼️ Important: ⚠️ NEVER commit these files — they contain private credentials. ‼️

### 5. Create a .env File

Create a `.env` file in the root of the project using the `.env.template`:

```bash
CLIENT_ID=your_twitch_client_id
OAUTH_TOKEN=your_oauth_token
USER_LOGIN=your_twitch_username
COOKIES_FILE=cookies.txt
```

> ‼️ Important: ⚠️ NEVER commit this file — it contains private credentials. ‼️

## 🧪 Usage

Run the script:

```bash
./twitch_vod_backup.sh
```

The script will:

- Validate your OAuth token
- Fetch all VOD URLs from your account
- Download them with retries
- Save each one to its own timestamped folder

## 📁 Example Output

```bash
vods/
├── 2025-04-13T20-00-00 - 123456789 - Zelda Run/
│   ├── Zelda Run.mkv
│   ├── Zelda Run.info.json
│   ├── Zelda Run.description
│   └── Zelda Run.jpg
```

## ✅ Future Ideas & Todo

- Validate Windows compatibile script
- YouTube exports integration
- Discord post-download hooks
- Auto-trimming & upload via FFmpeg