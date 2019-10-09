#!/usr/bin/env bash
read -r Nick user chan msg
# $0 is the path
dir=$(dirname "$0")
# Decapitalizes uppercase letters
nick=$(echo "$Nick" | tr [:upper:] [:lower:])

reply() {
	echo YOLO
}

# Pets or pats back
action() {
	case "$1 $2" in
	# `/me pets YOLObot for scaring students` moves closing Start of Header
	`echo -e "pets $nick\001"`|"pets $nick")
		echo -e "\001ACTION pets $user\001"
		;;
	`echo -e "pats $nick\001"`|"pats $nick")
		echo -e "\001ACTION pats $user\001"
		;;
	esac
}

# Rocket.Chat bridge omits action and replaces Start of Header with _
pet() {
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

# Filter filename expansion
msg=$(echo "$msg" | tr -d '*')
# If $msg contains a flag
if echo "$msg" | grep -Eq '^-| -'; then
	# Remove leading - from flags
	msg=$(echo "$msg" | sed s/^-// | sed s/\ -/\ /)
fi

if [ "$chan" = "$Nick" ]; then
	# No trigger if you're messaging
	# Case statements are only case sensitive if parameters are passed by script
	reply `echo $msg | tr [:upper:] [:lower:]`
# YOLObot doesn't take orders from other bots
# WermBot ACRONYMbot werm_bot werm-bot
# Bots with hard-to-parse nicks that prefix a trigger
# Names can end in bot and people can be voiced in #bots too
elif echo "$user" | grep -Evq "Bot\b|[A-Z][A-Z]bot\b|[_-]bot\b|ExampleSpambot"; then
	cmd=$(echo "$msg" | cut -d ' ' -f 1 | tr [:upper:] [:lower:])
	case $cmd in
	$nick:|@$nick|$nick|+$nick|!$nick)
		# Without -s the first string is counted if there isn't a 2nd
		reply $(echo "$msg" | cut -d ' ' -f 2- -s | tr [:upper:] [:lower:])
		;;
	# /me pets YOLObot
	$(echo -e "\001action"))
		action $(echo "$msg" | cut -d ' ' -f 2-3 -s | tr [:upper:] [:lower:])
		;;
	esac
fi
