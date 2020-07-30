#!/usr/bin/env bash
# Based on kekbot by dom, Aatrox, and Hunner from the CAT @ Portland State University.

# $0 is the path
dir=$(dirname "$0")
max_lines=5
syntax='Usage: Bot.sh [OPTION] ...'

input() {
	# $USER, $HOSTNAME, and $fqdn are verified, name is clearly not
	# $USER = `whoami` and is not set in cron
	echo "USER $(whoami) $HOSTNAME $fqdn :The Mafia"
	echo "NICK $nick"
	grep -Ev '^NICK |^[^ ]+:[0-9]+$' "$join_file"
	# Last 10 lines of $buffer as IRC appends to it
	tail -f "$buffer"
}

ping_timeout() {
	diff=0
	# 15 minute timeout
	# irc.cat.pdx.edu ping timeout is 4m20s
	while [ "$diff" -lt 900 ]; do
		sleep 1
		# Seconds since epoch
		thyme=$(date +%s)
		# File modification time in seconds since epoch
		mthyme=$(stat -c %Y "$ping_time")
		diff=$((thyme - mthyme))
	done
	>&2 echo Ping timeout
	# Kill session processes of $$ (script PID)
	# exit doesn't exit script when backgrounded
	pkill -s $$
	exit 1
}

send() {
	# Avoid filename expansion
	echo "$*" >> "$buffer"
}

# Run Cmd.sh and reply truncated output if YOLObot replies
reply() {
	output=$(echo "$nick $user $chan $msg" | "$dir/Cmd.sh")
	if [ -n "$output" ]; then
		# If $output > $max_lines-long
		if [ "$(echo "$output" | wc -l)" -gt "$max_lines" ]; then
			# Truncate $output and add ... to avoid flooding
			output=$(echo "$output" | head -n "$max_lines"
			echo ...)
		fi

		# Echo lines separately
		echo "$output" | while read -r line; do
			# $1 is the destination channel
			send "PRIVMSG $1 :$line"
		done
	fi
	unset user
}

reject() {
	# Aw, but a cute aw, not the frustrating aw trolls would expect
	output='Join a channel with me senpai! ^_^'
	send "PRIVMSG $user :$output"
	unset user
}

args=$(getopt -l help,instance: -o hi: -- "$@")
eval set -- "$args"
while [ "$1"  != -- ]; do
	case $1 in
	--help|-h)
		echo "$syntax"
		echo IRC bot framework example, says YOLO and not much else, but PMs only to people in a same channel as it.
		echo
		echo Mandatory arguments to long options are mandatory for short options too.
		echo '-i, --instance=INSTANCE  use configuration file ~/.YOLObot/{INSTANCE}Join.txt. defaults to YOLObot.'
		echo
		echo 'See README.md for format of ~/.YOLObot/{INSTANCE}Join.txt'
		exit
		;;
	--instance|-i)
		instance=$2
		shift 2
		;;
	esac
done
shift

if [ "$#" -gt 0 ]; then
	>&2 echo Too much arguments
	>&2 echo "$syntax"
	exit 1
fi

# If $instance doesn't exist
if [ -z "$instance" ]; then
	instance=YOLObot
fi
# Make directory and parents quietly
mkdir -p ~/.YOLObot
buffer=~/.YOLObot/${instance}Buffer
# Kill all doppelgangers
# Duplicate bots exit if $buffer is removed
rm -f "$buffer"
mkfifo "$buffer"
chmod 600 "$buffer"
ping_time=~/.YOLObot/${instance}Ping
touch "$ping_time"

join_file=~/.YOLObot/${instance}Join.txt
chmod 600 "$join_file"
if ! server=$(grep -E '^[^ ]+:[0-9]+$' "$join_file"); then
	echo "No server in $join_file"
	exit 1
fi
if grep -q '^NICK ' "$join_file"; then
	nick=$(grep '^NICK ' "$join_file" | cut -d ' ' -f 2 -s)
else
	nick=$instance
fi

# DNS check
# Trim off $server after first :
if ! stdout=$(host "${server%%:*}"); then
	>&2 echo "$stdout"
	exit 1
fi
fqdn=$(host "$HOSTNAME" | head -n 1 | cut -d ' ' -f 1)

ping_timeout &

input | openssl s_client -connect "$server" 2>&1 | while read -r irc; do
	# If disconnected YOLObot reads an empty string
	if [ -n "$irc" ]; then
		# Reset timeout
		touch "$ping_time"
		echo "$irc"
		if [ "$(echo "$irc" | cut -d ' ' -f 1)" = PING ]; then
			send PONG
		elif [[ "$(echo "$irc" | cut -d ' ' -f 1)" =~ connect:errno=[0-9]+ ]]; then
			pkill -s $$
			exit 1
		# If PRIVMSG and WHOIS isn't running
		# $user is unset after WHOIS or Cmd.sh run
		# If 2nd string divided by space is PRIVMSG and $user doesn't exist
		elif [ "$(echo "$irc" | cut -d ' ' -f 2 -s)" = PRIVMSG ] && [ -z "$user" ]; then
			# IRC says :$user!$username@$host PRIVMSG $chan :$msg
			# 2nd character onwards from first string divided by !
			user=$(echo "$irc" | cut -d ! -f 1 | cut -c 2-)
			chan=$(echo "$irc" | cut -d ' ' -f 3 -s)
			# Remove new line from 2nd character onwards from 4th string onwards divided by space
			msg=$(echo "$irc" | cut -d ' ' -f 4- -s | tr -d '\r\n' | cut -c 2-)
			# $chan = $nick in PMs
			if [ "$chan" = "$nick" ]; then
				send "WHOIS $user"
			else
				reply "$chan"
			fi
		# Check if user joined common channel after WHOIS
		# After WHOIS IRC says :$host.cat.pdx.edu 319 $nick $user :$chans
		elif [ "$(echo "$irc" | cut -d ' ' -f 2 -s)" = 319 ]; then
			# Closing space to grep "# " instead of #
			# #chan contains # but not "# "
			# User mode might precede chan
			# @#chan
			# Remove + and @ from 3rd string divided by : and add space at the end
			joined="$(echo "$irc" | cut -d : -f 3 -s | tr -d +@) "
			# grep $chan1 or $chan2 ...
			# Replace , with ' |' from 2nd string divided by space and add space at the end
			chans="$(grep '^JOIN ' "$join_file" | cut -d ' ' -f 2 -s | sed 's/,/ |/g') "

			if echo "$joined" | grep -Eq "$chans"; then
				reply "$user"
			else
				reject
			fi
		# If user has no common channels after WHOIS
		# After WHOIS IRC says :$host 312 $nick $user $host :$server_msg
		# If 2nd string divided by space is 312 and $user isn't empty string
		elif [ "$(echo "$irc" | cut -d ' ' -f 2 -s)" = 312 ] && [ -n "$user" ]; then
			reject
		fi
	fi
done
