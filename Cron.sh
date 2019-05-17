#!/usr/bin/env bash

dir=$(dirname "$0")
# $0 is the path
if [ -z "$1" ]; then
	name=YOLObot
else
	name=$1
fi

if ! tmux ls 2>&1 | grep -q "^$name:"; then
	tmux new -ds "$name" "$dir/Bot.sh" "$name"
	# Makes session $name in background
fi
