#!/bin/bash
# twitch_vod_backup.sh
# Script to download Twitch VODs using yt-dlp
# Dependencies: yt-dlp, jq, curl
# Usage: ./twitch_vod_backup.sh
# Ensure the script is executable eg. chmod +x twitch_vod_backup.sh

MAX_RETRIES=3
REQUIRED_TOOLS=("yt-dlp" "jq" "curl" "bash")
COOKIES_FILE=./config/cookies.txt

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
# Load environment variables from .env file
if [ -f .env ]; then
  source .env
else
  echo "❌ Missing .env file. Aborting."
  exit 1
fi

# Validate OAuth token
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

# Validate required environment variables
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

# Validate cookies file
echo "🔍 Validating cookies file..."
if [ -z "$COOKIES_FILE" ]; then
  echo "❌ COOKIES_FILE is not set in .env file."
  exit 1
fi
if [ ! -f "$COOKIES_FILE" ]; then
  echo "❌ Cookies file not found at: $COOKIES_FILE"
  exit 1
fi
echo "✅ Cookies file exists at: $COOKIES_FILE"

# Validate contents of cookies file
echo "🔍 Validating contents of cookies file..."
if ! grep -q ".twitch.tv" "$COOKIES_FILE"; then
  echo "❌ Cookies file does not contain entries for .twitch.tv domain."
  exit 1
fi
if ! grep -q "auth-token" "$COOKIES_FILE"; then
  echo "❌ Cookies file does not contain an auth-token entry."
  exit 1
fi
if ! grep -q "login" "$COOKIES_FILE"; then
  echo "❌ Cookies file does not contain a login entry."
  exit 1
fi
echo "✅ Cookies file contains valid Twitch session entries."

# Validate vods directory
echo "🔍 Checking for vods directory..."
if [ ! -d "./vods" ]; then
  echo "❌ VODS directory not found. Creating it..."
  mkdir -p ./vods
fi
echo "✅ VODS directory is ready."

# Step 1: Get user_id from username
USER_ID=$(curl -s -H "Client-ID: $CLIENT_ID" \
               -H "Authorization: Bearer $OAUTH_TOKEN" \
               "https://api.twitch.tv/helix/users?login=$USER_LOGIN" \
          | jq -r '.data[0].id')

if [ -z "$USER_ID" ]; then
  echo "Failed to retrieve user ID. Check your credentials."
  exit 1
fi

# Step 2: Get list of VOD URLs (type=archive)
echo "Fetching VOD list for user_id $USER_ID..."
curl -s -H "Client-ID: $CLIENT_ID" \
        -H "Authorization: Bearer $OAUTH_TOKEN" \
        "https://api.twitch.tv/helix/videos?user_id=$USER_ID&type=archive&first=100" \
  | jq -r '.data[].url' > ./config/vod_urls.txt

# Step 3: Download each VOD with retries
download_vod() {
  local url="$1"
  local attempt=1
  local result=1

  # Use yt-dlp to download VOD and metadata
  yt-dlp \
    --cookies "$COOKIES_FILE" \
    --write-info-json \
    --write-description \
    --write-thumbnail \
    --write-all-thumbnails \
    --embed-thumbnail \
    --embed-metadata \
    --merge-output-format mkv \
    --output "vods/%(upload_date>%Y-%m-%d)sT%(upload_date>%H-%M-%S)s - %(id)s - %(title).60s/%(title).60s.%(ext)s" \
    "$url"

  result=$?

  while [ $result -ne 0 ] && [ $attempt -lt $MAX_RETRIES ]; do
    echo "Retrying ($attempt/$MAX_RETRIES) for $url..."
    sleep 5
    yt-dlp \
      --cookies "$COOKIES_FILE" \
      --write-info-json \
      --write-description \
      --write-thumbnail \
      --write-all-thumbnails \
      --embed-thumbnail \
      --embed-metadata \
      --merge-output-format mkv \
      --output "vods/%(upload_date>%Y-%m-%d)sT%(upload_date>%H-%M-%S)s - %(id)s - %(title).60s/%(title).60s.%(ext)s" \
      "$url"
    result=$?
    ((attempt++))
  done

  # After download, find the info JSON file and write a log
  if [ $result -eq 0 ]; then
    local info_json
    info_json=$(find vods/ -type f -name '*.info.json' -newermt "-1 minute" | head -n 1)

    if [ -f "$info_json" ]; then
      local folder
      folder=$(dirname "$info_json")
      local log_file="$folder/vod.log"

      local vod_id title category upload_date duration

      vod_id=$(jq -r '.id' "$info_json")
      title=$(jq -r '.title' "$info_json")
      category=$(jq -r '.category // .tags[0] // "Unknown"' "$info_json")
      upload_date=$(jq -r '.upload_date' "$info_json")
      duration=$(jq -r '.duration' "$info_json")

      {
        echo "VOD ID: $vod_id"
        echo "Title: $title"
        echo "Category: $category"
        echo "Upload Date: $upload_date"
        echo "Duration: $duration"
        echo "Source URL: $url"
      } > "$log_file"

      echo "📝 Log written to $log_file"
    else
      echo "⚠️ Could not find .info.json to generate log for $url"
    fi
  fi

  return $result
}

if [ ! -s ./config/vod_urls.txt ]; then
  echo "❌ VOD URL list is empty. No VODs to download."
  exit 1
fi

# Read VOD URLs from the file and download each one
echo "🔍 Starting VOD download process..."
while read -r url; do
  echo "Processing $url"
  download_vod "$url"
done < ./config/vod_urls.txt
echo "✅ All VODs processed."