#!/usr/bin/env bash

# $0 is the path
dir=$(dirname "$0")
# getent says $ip             STREAM $fqdn
fqdn=$(getent ahostsv4 "$HOSTNAME" | head -n 1 | cut -c 24-)
max_lines=5
# $USER = `whoami` and is not set in cron
uid=$(id -u "$(whoami)")
ram=/dev/shm/$uid
ram_dir=$ram/YOLObot

send() {
	# Avoid filename expansion
	echo "-> $*"
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
	# Kill script process
	# exit does not exit script when forked
	kill $$
	exit
}

# If $1 doesn't exist
if [ -z "$1" ]; then
	nick=YOLObot
else
	nick=$1
fi
# Make directory and parents quietly
mkdir -p ~/.YOLObot
buffer=~/.YOLObot/${nick}Buffer
# Kill all doppelgangers
# Duplicate bots exit if $buffer is removed
rm -f "$buffer"
mkfifo "$buffer"

join_file=~/.YOLObot/${nick}Join.txt
join=$(cut -d $'\n' -f 1 < "$join_file")
server=$(cut -d $'\n' -f 2 -s < "$join_file")

mkdir -p "$ram_dir"
# Forked processes cannot share variables
ping_time=$ram_dir/$nick
touch "$ping_time"
trap 'rm -r "$ram_dir"; rmdir --ignore-fail-on-non-empty "$ram"' EXIT

ping_timeout &

# Last 10 lines of $buffer as IRC appends to it
tail -f "$buffer" | openssl s_client -connect "$server" | while true; do
	if [ -z "$started" ]; then
		# $USER, $HOSTNAME, and $fqdn are verified, name is clearly not
		send "USER $(whoami) $HOSTNAME $fqdn :The Mafia"
		send "NICK $nick"
		send "$join"
		started=true
	fi

	read -r irc
	# If disconnected YOLObot reads an empty string
	if [ -n "$irc" ]; then
		# Reset timeout
		touch "$ping_time"
		echo "<- $irc"
		if [ "$(echo "$irc" | cut -d ' ' -f 1)" = PING ]; then
			send PONG
		elif [ "$(echo "$irc" | cut -d ' ' -f 1)" = ERROR ]; then
			if echo "$irc" | grep -q 'Closing Link'; then
				exit
			fi
		elif [ "$(echo "$irc" | cut -d ' ' -f 2)" = NOTICE ]; then
			if echo "$irc" | grep -q 'Server Terminating'; then
				exit
			fi
		# If PRIVMSG and WHOIS isn't running
		# $user is unset after WHOIS or Cmd.sh run
		# If 2nd string divided by space is PRIVMSG and $user doesn't exist
		elif [ "$(echo "$irc" | cut -d ' ' -f 2)" = PRIVMSG ] && [ -z "$user" ]; then
			# IRC says :$user!$username@$host PRIVMSG $chan :$msg
			# 2nd character onwards from first string divided by !
			user=$(echo "$irc" | cut -d ! -f 1 | cut -c 2-)
			chan=$(echo "$irc" | cut -d ' ' -f 3)
			# Remove new line from 2nd character onwards from 4th string onwards divided by space
			msg=$(echo "$irc" | cut -d ' ' -f 4- | tr -d '\r\n' | cut -c 2-)
			# $chan = $nick in PMs
			if [ "$chan" = "$nick" ]; then
				send "WHOIS $user"
			else
				reply "$chan"
			fi
		# Check if user joined common channel after WHOIS
		# After WHOIS IRC says :$host.cat.pdx.edu 319 $nick $user :$chans
		elif [ "$(echo "$irc" | cut -d ' ' -f 2)" = 319 ]; then
			# Closing space to grep "# " instead of #
			# #chan contains # but not "# "
			# User mode might precede chan
			# @#chan
			# Remove + and @ from 3rd string divided by : and add space at the end
			joined="$(echo "$irc" | cut -d : -f 3 | tr -d +@) "
			# grep $chan1 or $chan2 ...
			# Replace , with ' |' from 2nd string divided by space and add space at the end
			chans="$(echo "$join" | cut -d ' ' -f 2 | sed 's/,/ |/g') "

			if echo "$joined" | grep -Eq "$chans"; then
				reply "$user"
			else
				reject
			fi
		# If user has no common channels after WHOIS
		# After WHOIS IRC says :$host 312 $nick $user $host :$server_msg
		# If 2nd string divided by space is 312 and $user isn't empty string
		elif [ "$(echo "$irc" | cut -d ' ' -f 2)" = 312 ] && [ -n "$user" ]; then
			reject
		fi
	fi
done
