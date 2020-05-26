#!/usr/bin/env bash

# $0 is the path
dir=$(dirname "$0")
if [ -z "$1" ]; then
	name=YOLObot
else
	name=$1
fi

if ! tmux ls 2>&1 | grep -q "^$name:"; then
	# Makes session $name in background
	tmux new -ds "$name" "$dir/Bot.sh" -i "$name"
fi
