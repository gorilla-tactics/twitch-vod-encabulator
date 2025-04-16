# convert_cookies.py
# Run to convert cookies from JSON format to Netscape format
# First, make sure to export cookies from your browser in JSON format
# Then run this script to convert them to Netscape format
# eg: python3 convert_cookies.py

import sys
import json
from datetime import datetime

input_file = "../config/cookies.json"
output_file = "../config/cookies.txt"

if sys.version_info[0] < 3:
    print("This script requires Python 3. Please upgrade your Python version.")
    exit(1)

with open(input_file, "r") as f:
    cookies = json.load(f)

with open(output_file, "w") as f:
    f.write("# Netscape HTTP Cookie File\n\n")
    for cookie in cookies:
        domain = cookie.get("domain", "")
        include_subdomain = "TRUE" if domain.startswith(".") else "FALSE"
        path = cookie.get("path", "/")
        secure = "TRUE" if cookie.get("secure", False) else "FALSE"
        expires = str(int(cookie.get("expirationDate", 2147483647)))  # default to far future if missing
        name = cookie.get("name", "")
        value = cookie.get("value", "")
        f.write("\t".join([domain, include_subdomain, path, secure, expires, name, value]) + "\n")

if not cookies:
    print("No cookies found in JSON. Aborting.")
    exit(1)

print(f"Converted {len(cookies)} cookies from JSON to Netscape format.")
print(f"Saved to {output_file}.")
print("Conversion complete.")
