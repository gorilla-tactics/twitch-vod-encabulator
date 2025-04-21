#!/bin/bash
# twitch_vod_backup.sh
# Script to download Twitch VODs using yt-dlp
# Dependencies: yt-dlp, jq, curl
# Usage: ./twitch_vod_backup.sh [--id VOD_ID] [--url URL] [--date YYYY-MM-DD] [--category NAME] [--type TYPE] [--dry-run]

MAX_RETRIES=3
REQUIRED_TOOLS=("yt-dlp" "jq" "curl" "bash")
COOKIES_FILE=./config/cookies.txt

# Optional filters
FILTER_ID=""
FILTER_URL=""
FILTER_DATE=""
FILTER_CATEGORY=""
FILTER_TYPE=""
DRY_RUN=false

# Help text
if [[ "$1" == "--help" ]]; then
  echo "Usage: ./twitch_vod_backup.sh [OPTIONS]"
  echo "\nOptions:"
  echo "  --id VOD_ID           Filter by specific VOD ID"
  echo "  --url URL             Filter by specific VOD URL"
  echo "  --date YYYY-MM-DD     Filter by upload date"
  echo "  --category NAME       Filter by game/category name"
  echo "  --type TYPE           Filter by video type (archive, highlight, upload)"
  echo "  --dry-run             Simulate downloads without saving files"
  echo "  --help                Show this help message"
  exit 0
fi

# Parse CLI args
while [[ $# -gt 0 ]]; do
  case "$1" in
    --id) FILTER_ID="$2"; shift ;;
    --url) FILTER_URL="$2"; shift ;;
    --date) FILTER_DATE="$2"; shift ;;
    --category) FILTER_CATEGORY="$2"; shift ;;
    --type) FILTER_TYPE="$2"; shift ;;
    --dry-run) DRY_RUN=true ;;
    *) echo "❌ Unknown option: $1" >&2; exit 1 ;;
  esac
  shift
done

echo "🔍 Checking dependencies..."
for tool in "${REQUIRED_TOOLS[@]}"; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "❌ Missing dependency: $tool"
    echo "➡️  Please install '$tool' before running this script."
    exit 1
  fi
  echo "✅ $tool is installed."
done

echo "🔍 Checking for .env file..."
if [ -f .env ]; then
  source .env
else
  echo "❌ Missing .env file. Aborting."
  exit 1
fi

echo "🔍 Validating OAuth token..."
validate_token() {
  local response
  response=$(curl -s -H "Authorization: OAuth $OAUTH_TOKEN" https://id.twitch.tv/oauth2/validate)

  if echo "$response" | jq -e '.status' &>/dev/null; then
    echo "Invalid or expired OAuth token: $(echo "$response" | jq -r '.message')"
    exit 1
  fi

  local expires_in
  expires_in=$(echo "$response" | jq -r '.expires_in')

  if [ "$expires_in" -lt 3600 ]; then
    echo "OAuth token expires in less than 1 hour. Consider refreshing it."
  else
    echo "OAuth token is valid. Expires in $((expires_in / 3600)) hours."
  fi
}
validate_token

echo "🔍 Validating environment variables..."
validate_env_var() {
  local var_name="$1"
  local template_value="$2"
  local actual_value="${!var_name}"

  if [ -z "$actual_value" ]; then
    echo "❌ $var_name is not set in .env file."
    exit 1
  elif [ "$actual_value" == "$template_value" ]; then
    echo "❌ $var_name is set to the default value in .env.template. Please update it."
    exit 1
  else
    echo "✅ $var_name is set to $actual_value."
  fi
}
validate_env_var "CLIENT_ID" "your_client_id_here"
validate_env_var "OAUTH_TOKEN" "your_oauth_token_here"
validate_env_var "USER_LOGIN" "your_username_here"

echo "🔍 Validating cookies file..."
if [ -z "$COOKIES_FILE" ]; then
  echo "❌ COOKIES_FILE is not set in .env file."
  exit 1
fi
if [ ! -f "$COOKIES_FILE" ]; then
  echo "❌ Cookies file not found at: $COOKIES_FILE"
  exit 1
fi
if ! grep -q ".twitch.tv" "$COOKIES_FILE" || ! grep -q "auth-token" "$COOKIES_FILE" || ! grep -q "login" "$COOKIES_FILE"; then
  echo "❌ Cookies file does not contain expected Twitch session entries."
  exit 1
fi
echo "✅ Cookies file is valid."

echo "🔍 Checking for vods directory..."
mkdir -p ./vods
mkdir -p ./config

# Step 1: Get user_id from username
USER_ID=$(curl -s -H "Client-ID: $CLIENT_ID" \
               -H "Authorization: Bearer $OAUTH_TOKEN" \
               "https://api.twitch.tv/helix/users?login=$USER_LOGIN" \
          | jq -r '.data[0].id')

if [ -z "$USER_ID" ]; then
  echo "Failed to retrieve user ID. Check your credentials."
  exit 1
fi

# Step 2: Get list of videos (archive, highlight, upload)
echo "" > ./config/vod_urls.txt
all_vods="[]"
for video_type in archive highlight upload; do
  [[ -n "$FILTER_TYPE" && "$video_type" != "$FILTER_TYPE" ]] && continue
  echo "📦 Fetching $video_type videos..."
  response=$(curl -s -H "Client-ID: $CLIENT_ID" \
                  -H "Authorization: Bearer $OAUTH_TOKEN" \
                  "https://api.twitch.tv/helix/videos?user_id=$USER_ID&type=$video_type&first=100")

  vod_data=$(echo "$response" | jq -c --arg type "$video_type" '[.data[] | . + {video_type: $type}]')
  all_vods=$(jq -s 'add' <(echo "$all_vods") <(echo "$vod_data"))
  echo "$vod_data" | jq -r '.[].url' >> ./config/vod_urls.txt
  echo "✅ Appended $video_type VODs to vod_urls.txt"
  count=$(echo "$vod_data" | jq length)
  echo "✅ Found $count $video_type VOD(s)."
  sleep 1

done

if [ "$(echo "$all_vods" | jq 'length')" -eq 0 ]; then
  echo "❌ No VODs found."
  exit 0
fi
vods="$all_vods"

# Step 3: Download each VOD with retries
download_vod() {
  local vod_id="$1"
  local title="$2"
  local upload_date="$3"
  local category="$4"
  local url="$5"
  local video_type="$6"

  [[ -n "$FILTER_ID" && "$vod_id" != "$FILTER_ID" ]] && { echo "❌ Skipped (ID filter): $vod_id"; return; }
  [[ -n "$FILTER_URL" && "$url" != "$FILTER_URL" ]] && { echo "❌ Skipped (URL filter): $url"; return; }
  [[ -n "$FILTER_DATE" && "$upload_date" != "$FILTER_DATE"* ]] && { echo "❌ Skipped (Date filter): $upload_date"; return; }
  if [[ -n "$FILTER_CATEGORY" ]]; then
    if [[ "$category" == "Unknown" ]]; then
      echo "⚠️  Warning: No game_name found for VOD $vod_id ($title)"
      echo "❌ Skipped (Category filter): $category"
      return
    fi
    category_normalized=$(echo "$category" | tr '[:upper:]' '[:lower:]')
    filter_normalized=$(echo "$FILTER_CATEGORY" | tr '[:upper:]' '[:lower:]')
    if [[ "$category_normalized" != "$filter_normalized" ]]; then
      echo "❌ Skipped (Category filter): $category"
      return
    fi
  fi

  local clean_title
  clean_title=$(echo "$title" | iconv -c -f utf8 -t ascii | tr -cd '[:alnum:] _-()[]{}.,' | tr ' ' '_')
  local clean_id="${vod_id#v}"
  local folder="vods/${video_type}/${upload_date} - ${clean_id} - ${clean_title}"
  local mp4_path="$folder/${clean_id}_${clean_title}.mp4"

  if [[ "$DRY_RUN" == "true" ]]; then
    echo "💡 [Dry run] Would download to: $mp4_path"
    return
  fi

  if [ -f "$mp4_path" ]; then
    echo "⏩ Skipping already downloaded VOD: $mp4_path"
    return
  fi

  echo "⬇️  Downloading: $vod_id | $upload_date | $category | $title"

  yt-dlp \
    --cookies "$COOKIES_FILE" \
    --write-info-json \
    --write-description \
    --write-thumbnail \
    --write-all-thumbnails \
    --no-mtime \
    --windows-filenames \
    --output "$folder/${clean_id}_${clean_title}.%(ext)s" \
    "$url"
}

echo "🔍 Starting VOD download process..."
matched=0
jq -c '.[]' <<< "$vods" | while IFS= read -r vod; do
  vod_id=$(echo "$vod" | jq -r '.id')
  title=$(echo "$vod" | jq -r '.title')
  upload_date=$(echo "$vod" | jq -r '.created_at' | cut -dT -f1)
  category=$(echo "$vod" | jq -r '.game_name // "Unknown"')
  url=$(echo "$vod" | jq -r '.url')
  video_type=$(echo "$vod" | jq -r '.video_type')

  download_vod "$vod_id" "$title" "$upload_date" "$category" "$url" "$video_type" && matched=$((matched+1))
done

echo "✅ Processed $matched matching VOD(s)."
