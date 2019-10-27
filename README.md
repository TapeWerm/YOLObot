# Description
IRC bot framework example, says YOLO and not much else, but PMs only to people in a same channel as it

The YOLO IRC bot framework PMs only to people in a same channel as it, features timeouts, multi-line message truncation, send as bot, test instances, /me support, uses s_client, and is a verifable member of the mafia written in bash for better and worse.

Heavily forked from a basic IRC bot framework taught to new IT support, it grew to power an internal bot in production after much learning by trial and error. Permission was granted to upload the framework under MIT, and after years gathering dust, I had to add timeouts to fix a holdout from the Rocket.Chat migration based on the framework. And if my last grievance is fixed, I may as well strip it back down to its memebot roots and finally open-source its cool channel checking feature. Can't have engineering students using our work bots through private messages. Yay tech debt.
# Notes
How to dump tmux scrollback for debugging:
```bash
# $sessionname is YOLObot
tmux capture-pane -pt "$sessionname" -S - | less
```
How to speak through YOLObot:
```bash
echo "PRIVMSG #chan :Test" >> ~/.YOLObot/YOLObotBuffer
```
Only replies to messages from users in channels it's in. If it's only in keyed channels outsiders can't use it, if it's in no channels no one can.
# Setup
Open Terminal:
```bash
sudo apt install git tmux
git clone https://github.com/TapeWerm/YOLObot.git
cd YOLObot
```
Copy and paste this block:
```bash
# Do not run prod in a git repo you're working in
mkdir ~/YOLObotProd
for file in $(ls *.sh); do cp "$file" ~/YOLObotProd/; done
mkdir ~/.YOLObot
```
Enter `nano ~/.YOLObot/YOLObotJoin.txt`, fill this in, and write out (^G = Ctrl-G):
```
JOIN #chan,#chan $key,$key
irc.domain.tld:$port
```
List channels with no password last.

Do not use both crontab and systemd.
## crontab Setup
Enter `crontab -e` and add this to your crontab:
```
* * * * * ~/YOLObotProd/Cron.sh > /dev/null 2>&1
# &> does not work in crontab cause it uses sh, not bash
```
## systemd Setup
Copy and paste this block:
```bash
mkdir -p ~/.config/systemd/user
for file in $(ls systemd); do cp "systemd/$file" ~/.config/systemd/user/; done
systemctl --user enable yolobot.service --now
systemctl --user enable yolobot.timer --now
loginctl enable-linger "$USER"
```
# Files
## Bot.sh
IRC parser called by Cron.sh. Updates require restart to take effect. Test with a different nick ($1). Based on kekbot by dom, Aatrox, and Hunner.
## Cmd.sh
Commands called by Bot.sh.
## Cron.sh
Script called by crontab to avoid duplicate sessions. Test with a different nick ($1).
## ~/.YOLObot/${nick}Buffer
Named pipe made by Bot.sh for IRC I/O. Reading with tail -f blocks output to IRC.
## ~/.YOLObot/${nick}Join.txt
List of channels and passwords to join them read by Bot.sh.
