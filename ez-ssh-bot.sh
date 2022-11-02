#!/bin/bash

# We are subscribed to session events and ignore closing ones
if [ "$PAM_TYPE" != "close_session" ]; then
  # Only monitor reverse-tunnel connections (they come in via local loopback)
  if [ "$PAM_RHOST" == "127.0.0.1" ]; then
    CHAT_ID=<your channel ID>
    BOT_TOKEN=<your bot-token>
    message="$(date +"%Y-%m-%d, %A %R")"$'\n'"External SSH Login: $PAM_USER@$(hostname)"
    curl -s --data "text=$message" --data "chat_id=$CHAT_ID" 'https://api.telegram.org/bot'$BOT_TOKEN'/sendMessage' > /dev/null
  fi
fi
