#!/bin/bash

# We are subscribed to auth events
if [ "$PAM_TYPE" == "auth" ]; then
  # Only monitor reverse-tunnel connections (they come in via local loopback)
  if [[ "$PAM_RHOST" == "127.0.0.1" || "$PAM_RHOST" == "::1" ]]; then
    CHAT_ID=<our channel ID>
    BOT_TOKEN=<our bot-token>
    message="$(date +"%Y-%m-%d, %A %R")"$'\n'"External SSH Login Failed: $PAM_USER@$(hostname)"
    curl -s --data "text=$message" --data "chat_id=$CHAT_ID" 'https://api.telegram.org/bot'$BOT_TOKEN'/sendMessage' > /dev/null
  fi
fi
