#!/usr/bin/env bash

dir=$(dirname "$0")
# $0 is the path
max_lines=5
if [ -z "$1" ]; then
# If $1 doesn't exist
	nick=YOLObot
else
	nick=$1
fi
mkdir -p ~/.YOLObot
# Make directory and parents quietly
buffer=~/.YOLObot/${nick}Buffer
rm "$buffer"
mkfifo "$buffer"
join_file=~/.YOLObot/${nick}Join.txt
join=$(cat "$join_file" | cut -d $'\n' -f 1)
server=$(cat "$join_file" | cut -d $'\n' -f 2 -s)
ping_time=/dev/shm/$nick
# Forked processes cannot share variables
echo 0 > "$ping_time"

send() {
	echo "-> $*"
	echo "$*" >> "$buffer"
	# Avoid filename expansion
}

reply() {
# Run Cmd.sh and reply truncated output if YOLObot replies
	output=$(echo "$nick $user $chan $msg" | "$dir/Cmd.sh")
	if [ -n "$output" ]; then
		if [ "$(echo "$output" | wc -l)" -gt "$max_lines" ]; then
		# If $output > $max_lines-long
			output=$(echo "$output" | head -n "$max_lines"
			echo ...)
			# Truncate $output and add ... to avoid flooding
		fi

		echo "$output" | while read -r line; do
		# Echo lines separately
			send "PRIVMSG $1 :$line"
			# $1 is the destination
			# If $chan = $nick send to $user instead
		done
	fi
	unset user
}

reject() {
	output='Join a channel with me senpai! ^_^'
	# Aw, but a cute aw, not the frustrating aw trolls would expect
	send "PRIVMSG $user :$output"
	unset user
}

ping_timeout() {
	while [ "$(cat "$ping_time")" -lt 260 ]; do
	# irc.cat.pdx.edu ping timeout is 4m20s
		sleep 1
		echo $(($(cat "$ping_time") + 1)) > "$ping_time"
	done
	kill $$
	# Kill script process
	# exit does not exit script when forked
}

ping_timeout &

tail -f "$buffer" | openssl s_client -connect "$server" | while true; do
# Last 10 lines of $buffer as IRC appends to it
	if [ -z "$started" ]; then
		fqdn=$(getent ahostsv4 "$HOSTNAME" | head -n 1 | cut -c 24-)
		# getent says $ip             STREAM $fqdn
		send "USER $(whoami) $HOSTNAME $fqdn :The Mafia"
		# $USER, $HOSTNAME, and $fqdn are verified, name is clearly not
		# $USER = `whoami` and is not set in cron
		send "NICK $nick"
		send "$join"
		started=true
	fi

	read -r irc
	if [ -n "$irc" ]; then
	# If disconnected YOLObot reads an empty string
		echo "<- $irc"
		if [ "$(echo "$irc" | cut -d ' ' -f 1)" = PING ]; then
			send PONG
			echo 0 > "$ping_time"
			# Reset timeout
		elif [ "$(echo "$irc" | cut -d ' ' -f 1)" = ERROR ]; then
			if echo "$irc" | grep -q 'Closing Link'; then
				exit
			fi
		elif [ "$(echo "$irc" | cut -d ' ' -f 2)" = NOTICE ]; then
			if echo "$irc" | grep -q 'Server Terminating'; then
				exit
			fi
		elif [ "$(echo "$irc" | cut -d ' ' -f 2)" = PRIVMSG ] && [ -z "$user" ]; then
		# If PRIVMSG and WHOIS isn't running
		# $user is unset after WHOIS or Cmd.sh run
		# If 2nd string divided by space is PRIVMSG and $user doesn't exist
			user=$(echo "$irc" | cut -d ! -f 1 | cut -c 2-)
			# IRC says :$user!$username@$host PRIVMSG $chan :$msg
			# 2nd character onwards from first string divided by !
			chan=$(echo "$irc" | cut -d ' ' -f 3)
			msg=$(echo "$irc" | cut -d ' ' -f 4- | tr -d '\r\n' | cut -c 2-)
			# Remove new line from 2nd character onwards from 4th string onwards divided by space
			if [ "$chan" = "$nick" ]; then
				send "WHOIS $user"
			else
				reply "$chan"
			fi
		elif [ "$(echo "$irc" | cut -d ' ' -f 2)" = 319 ]; then
		# Check if user joined common channel after WHOIS
		# After WHOIS IRC says :$host.cat.pdx.edu 319 $nick $user :$chans
			joined="$(echo "$irc" | cut -d : -f 3 | tr -d +@) "
			# Closing space to grep "# " instead of #
			# #chan contains # but not "# "
			# User mode might precede chan
			# @#chan
			# Remove + and @ from 3rd string divided by : and add space at the end
			chans="$(echo "$join" | cut -d ' ' -f 2 | sed 's/,/ |/g') "
			# grep $chan1 or $chan2 ...
			# Replace , with ' |' from 2nd string divided by space and add space at the end

			if echo "$joined" | grep -Eq "$chans"; then
				reply "$user"
			else
				reject
			fi
		elif [ "$(echo "$irc" | cut -d ' ' -f 2)" = 312 ] && [ -n "$user" ]; then
		# If user has no common channels after WHOIS
		# After WHOIS IRC says :$host 312 $nick $user $host :$server_msg
		# If 2nd string divided by space is 312 and $user isn't empty string
			reject
		fi
	fi
done
