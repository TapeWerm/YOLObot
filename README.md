# Description
IRC bot framework example, says YOLO and not much else, but PMs only to people in a same channel as it

The YOLO IRC bot framework PMs only to people in a same channel as it, features timeouts, multi-line message truncation, send as bot, test instances, /me support, uses s_client, and is a verifable member of the mafia written in bash for better and worse.

Forked from a basic IRC bot framework taught to new IT support, it grew to power an internal bot in production after much learning by trial and error. Permission was granted to upload the framework under MIT, and after years gathering dust, I had to add timeouts to fix a holdout from the Rocket.Chat migration based on the framework. And if my last grievance is fixed, I may as well strip it back down to its memebot roots and finally open-source its cool channel checking feature. Can't have engineering students using our work bots through private messages. Yay tech debt.
# [Contributing](CONTRIBUTING.md)
# Table of contents
- Notes
  - [cron notes](#cron-notes)
  - [systemd notes](#systemd-notes)
  - [IRC notes](#irc-notes)
- [Setup](#setup)
  - [cron setup](#cron-setup)
  - [systemd setup](#systemd-setup)
- [Files](#files)
## cron notes
How to dump tmux scrollback for debugging:
```bash
# $sessionname is YOLObot
tmux capture-pane -pt "$sessionname" -S - | less
```
## systemd notes
How to dump scrollback for debugging:
```bash
journalctl --user -eu yolobot
```
## IRC notes
How to speak through YOLObot:
```bash
echo "PRIVMSG #chan :Test" >> ~/.YOLObot/YOLObotBuffer
```
Only replies to messages from users in channels it's in. If it's only in keyed channels outsiders can't use it, if it's in no channels no one can.
# Setup
Open Terminal:
```bash
sudo apt install git tmux
cd ~
git clone https://github.com/TapeWerm/YOLObot.git
cd YOLObot
```
Copy and paste this block:
```bash
# Do not run prod in a git repo you're working in
mkdir ~/YOLObotProd
cp -v *.sh ~/YOLObotProd/
mkdir ~/.YOLObot
```
Enter `nano ~/.YOLObot/YOLObotJoin.txt`, fill this in, and write out (^G = Ctrl-G):
```
NICK $nick
JOIN #chan,#chan $key,$key
PRIVMSG #chan :$msg
...
irc.domain.tld:$port
```
If NICK line is missing it defaults to YOLObot. List channels with no key last. PRIVMSG lines are optional and can be used before JOIN to identify with NickServ.

Do not use both cron and systemd.
## cron setup
Enter `crontab -e` and add this to your crontab:
```
* * * * * ~/YOLObotProd/Cron.sh > /dev/null 2>&1
# &> does not work in crontab cause it uses sh, not bash
```
## systemd setup
Copy and paste this block:
```bash
mkdir -p ~/.config/systemd/user
cp -v systemd/* ~/.config/systemd/user/
loginctl enable-linger "$USER"
```
Replace $hostname with the host YOLObot will run on.
```bash
for file in systemd/*.service; do sed -i s/^ConditionHost=.*/ConditionHost=$hostname/ ~/.config/systemd/user/"$(basename "$file")"; done
systemctl --user enable yolobot.service yolobot.timer --now
```
# Files
## Bot.sh
IRC parser called by Cron.sh. Updates require restart to take effect. Test with a different nick (-i $nick).
## Cmd.sh
Commands called by Bot.sh.
## Cron.sh
Script called by crontab to avoid duplicate sessions. Test with a different nick ($1).
## ~/.YOLObot/${nick}Buffer
Named pipe made by Bot.sh for IRC I/O. Reading with tail -f blocks output to IRC.
## ~/.YOLObot/${nick}Join.txt
List of channels and passwords to join them read by Bot.sh.
