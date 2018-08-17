#!/bin/bash
TOKEN="$1"

# {ALERT.SUBJECT}
subject="$2"

# {ALERT.MESSAGE}
message="$3"

# Line Notify notice message.
notice="
${subject}
${message}
"

curl https://notify-api.line.me/api/notify -H "Authorization: Bearer ${TOKEN}" -d "message=${notice}"
