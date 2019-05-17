#!/usr/bin/env bash
read -r Nick user chan msg
dir=$(dirname "$0")
# $0 is the path
nick=$(echo "$Nick" | tr [:upper:] [:lower:])
# Decapitalizes uppercase letters

reply() {
	echo YOLO
}

action() {
# Pets or pats back
	case "$1 $2" in
	`echo -e "pets $nick\001"`|"pets $nick")
	# `/me pets YOLObot for scaring students` moves closing Start of Header
		echo -e "\001ACTION pets $user\001"
		;;
	`echo -e "pats $nick\001"`|"pats $nick")
		echo -e "\001ACTION pats $user\001"
		;;
	esac
}

pet() {
# Rocket.Chat bridge omits action and replaces Start of Header with _
	case $1 in
	${nick}_|$nick)
		echo -e "\001ACTION pets $user\001"
		;;
	esac
}

pat() {
	case $1 in
	${nick}_|$nick)
		echo -e "\001ACTION pats $user\001"
		;;
	esac
}

msg=$(echo "$msg" | tr -d '*')
# Filter filename expansion
if echo "$msg" | grep -Eq "^-| -"; then
# If $msg contains a flag
	msg=$(echo "$msg" | sed s/^-// | sed s/\ -/\ /)
	# Remove leading - from flags
fi

if [ "$chan" = "$Nick" ]; then
	reply `echo $msg | tr [:upper:] [:lower:]`
	# No trigger if you're messaging
	# case statements are only case sensitive if parameters are passed by script
elif echo "$user" | grep -Evq "Bot\b|[A-Z][A-Z]bot\b|[_-]bot\b|ExampleSpambot"; then
# YOLObot doesn't take orders from other bots
# WermBot ACRONYMbot werm_bot werm-bot
# Bots with hard-to-parse nicks that prefix a trigger
# Names can end in bot and people can be voiced in #bots too
	cmd=$(echo "$msg" | cut -d ' ' -f 1 | tr [:upper:] [:lower:])
	case $cmd in
	$nick:|@$nick|$nick|+$nick|!$nick)
		reply $(echo "$msg" | cut -d ' ' -f 2- -s | tr [:upper:] [:lower:])
		# Without -s the first string is counted if there isn't a 2nd
		;;
	$(echo -e "\001action"))
	# /me pets WakeBot
		action $(echo "$msg" | cut -d ' ' -f 2-3 -s | tr [:upper:] [:lower:])
		;;
	esac
fi
