# ez-ssh-bot

SSH Reverse Tunnel with Login Notifications via Telegram Bot

![Diagram](ez-ssh-bot.png)

## Create a Telegram bot

We contact [@BotFather](https://t.me/botfather) on Telegram and type `/start`. Then we follow the instructions to create a bot and get an access token. The token will look like this: `4098346289:YUI_OLIJi98y78078yyhi7ovghjoTGniuss`. It grants full control over our bot, so we must keep it private.

Now we have to create a new Telegram channel and add our bot as a member, so it can send messages to the channel. Let's post a "test" message from our own account and navigate to this page to find the channel ID:
[https://api.telegram.org/bot&lt;bot-access-token&gt;/getUpdates](https://api.telegram.org/bot4098346289:YUI_OLIJi98y78078yyhi7ovghjoTGniuss/getUpdates). We find the channel ID in field `result/message/chat/id` of the returned JSON:

```json
{
  "ok": true,
  "result": [
    {
      "update_id": 108063316,
      "message": {
        "message_id": 1,
        "from": {
          "id": <channel ID>,
          "is_bot": false,
          "first_name": "Stefan",
          "username": "weliveindetail",
          "language_code": "en"
        },
        "chat": {
          "id": <channel ID>,
          "first_name": "Stefan",
          "username": "weliveindetail",
          "type": "private"
        },
        "date": 1667396395,
        "text": "test"
      }
    }
  ]
}
```

We enter both, our bot-token and channel ID in the `ez-ssh-bot` scripts in this repo:
```
CHAT_ID=<our channel ID>
BOT_TOKEN=<our bot-token>
message="$(date +"%Y-%m-%d, %A %R")"$'\n'"External SSH Login Failed: $PAM_USER@$(hostname)"
```

We can test our bot like this:
```shell
> PAM_RHOST=127.0.0.1 PAM_TYPE=open_session ./ez-ssh-bot-success.sh
> PAM_RHOST=127.0.0.1 PAM_TYPE=auth ./ez-ssh-bot-fail.sh
```

In our Telegram channel we should receive two messages &mdash; one "External SSH Login" and one "External SSH Login Failed". Once that works, we copy the scripts to `/etc/ssh` and restrict access:
```shell
> sudo cp ez-ssh-bot-*.sh /etc/ssh/.
> sudo chown root /etc/ssh/ez-ssh-bot-*.sh
> sudo chmod 100 /etc/ssh/ez-ssh-bot-*.sh
```

## Set up a free AWS EC2 Instance

This article guides through the configuration step by step &mdash; we must remember our elastic IP address and where we saved the `.pem` file from our key pair: https://www.opensourceforu.com/2021/09/how-to-do-reverse-tunnelling-with-the-amazon-ec2-instance/

## Create a dedicated user for AutoSSH

Let's create a dedicated user, set a password, copy over the `.pem` file for our EC2 instance and make sure the `known_hosts` file exists:
```shell
> sudo useradd -m ez-ssh-bot
> sudo passwd ez-ssh-bot
> sudo mkdir -p /home/ez-ssh-bot/.ssh
> sudo cp /path/to/private/ec2-key.pem /home/ez-ssh-bot/.ssh/ez-ssh-bot.pem
> sudo chown ez-ssh-bot /home/ez-ssh-bot/.ssh/ez-ssh-bot.pem
> sudo chmod 600 /home/ez-ssh-bot/.ssh/ez-ssh-bot.pem
> sudo touch /home/ez-ssh-bot/.ssh/known_hosts
> sudo chown ez-ssh-bot /home/ez-ssh-bot/.ssh/known_hosts
```

We switch to the new user once in order to test the SSH connection and confirm the server fingerprint. Here we need the elastic IP address of our EC2 instance:
```shell
> su - ez-ssh-bot
Password: ...
ez-ssh-bot> ssh -i ~/.ssh/ez-ssh-bot.pem ec2-user@<elastic IP>
The authenticity of host '<elastic IP> (<elastic IP>)' can't be established.
ECDSA key fingerprint is SHA256:VhApmMgDG00DVRlwAeFqmN3hDgtJZpvuvIV9Dy39gyk.
Are you sure you want to continue connecting (yes/no/[fingerprint])? yes
[ec2-user@ip-172-31-43-51 ~]$ exit
ez-ssh-bot> wc --chars /home/ez-ssh-bot/.ssh/known_hosts
221 /home/ez-ssh-bot/.ssh/known_hosts
ez-ssh-bot> exit
```

Eventually, we can give the user a false shell to prevent further logins:
```shell
> sudo usermod -s /usr/sbin/nologin ez-ssh-bot
> su - ez-ssh-bot
Password: ...
This account is currently not available.
```

## Create a Systemd service for AutoSSH

We use AutoSSH to maintain the reverse SSH tunnel connection from our local workstation to the public EC2 instance. SSH connections to the respective port of the EC instance will then be forwarded to our local workstation through the reverse tunnel.  We use Systemd to take care of starting AutoSSH after boot and restarting it in case of failures.

First, we enter our elastic IP in the `ez-ssh-bot.service` in this repo and copy it to the Systemd system services folder:
```shell
> grep "<elastic IP>" ez-ssh-bot.service
ExecStart=/usr/bin/autossh -M 0 -N -f -q -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 -o ServerAliveCountMax=3 -i ~/.ssh/ez-ssh-bot.pem -R 9033:localhost:22 ec2-user@<elastic IP>

> sudo cp ez-ssh-bot.service /etc/systemd/system/.
```

Let's make sure we have the `autossh` package installed. Then we reload all units from disk, start the service and check its status:
```shell
> sudo apt install autossh
> sudo systemctl daemon-reload
> sudo systemctl start ez-ssh-bot
> systemctl status ez-ssh-bot
● ez-ssh-bot.service - SSH Reverse Tunnel with Login Notifications
     Loaded: loaded (/etc/systemd/system/ez-ssh-bot.service; disabled; vendor preset: enabled)
     Active: active (running) since Wed 2022-11-02 13:23:42 CET; 13min ago
    Process: 2337703 ExecStart=/usr/bin/autossh -M 0 -N -f -q -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 -o ServerAliveCountMax=3 -i ~/.ssh/ez-ssh-bot.pem -R 9033:localhost:22 ec2-user@<elastic IP>
   Main PID: 2337706 (autossh)
      Tasks: 2 (limit: 38185)
     Memory: 1.0M
     CGroup: /system.slice/ez-ssh-bot.service
             ├─2337706 /usr/lib/autossh/autossh -M 0 -N    -q -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 -o ServerAliveCountMax=3 -i ~/.ssh/ez-ssh-bot.pem -R 9033:localhost:22 ec2-user@<elastic IP>
             └─2337707 /usr/bin/ssh -N -q -o ExitOnForwardFailure=yes -o ServerAliveInterval=30 -o ServerAliveCountMax=3 -i ~/.ssh/ez-ssh-bot.pem -R 9033:localhost:22 ec2-user@<elastic IP>

Nov 02 13:23:42 i7ubuntu systemd[1]: Starting SSH Reverse Tunnel with Login Notifications...
Nov 02 13:23:42 i7ubuntu autossh[2337703]: port set to 0, monitoring disabled
Nov 02 13:23:42 i7ubuntu autossh[2337706]: starting ssh (count 1)
Nov 02 13:23:42 i7ubuntu systemd[1]: Started SSH Reverse Tunnel with Login Notifications.
Nov 02 13:23:42 i7ubuntu autossh[2337706]: ssh child pid is 2337707
```

We can now SSH into the `user` account on our local workstation from a remote machine through our EC2 instance 🙌
```shell
> ssh -p 9034 user@<elastic IP>
```

Once that works, let Systemd start our service automatically at boot-time:
```shell
> sudo systemctl enable ez-ssh-bot
```

## Add a PAM steps to send notifications

Let's connect the remaining pieces. 
The `/etc/ssh/ez-ssh-bot-success.sh` script sends a "External SSH Login" messsage for logins that originate from the reverse SSH tunnel.
We want to run it whenever a login attempt succeeded.
We can edit `/etc/pam.d/sshd` to achieve this:

```diff
--- a/etc/pam.d/sshd
+++ b/etc/pam.d/sshd
@@ -27,6 +27,9 @@ session    optional     pam_keyinit.so force revoke
 # Standard Un*x session setup and teardown.
 @include common-session
 
+# Send a login notification to Telegram via ez-ssh-bot
+session    optional     pam_exec.so seteuid /etc/ssh/ez-ssh-bot-success.sh
+
 # Print the message of the day upon successful login.
 # This includes a dynamically generated part from /run/motd.dynamic
 # and a static (admin-editable) part from /etc/motd.
```

The `/etc/ssh/ez-ssh-bot-fail.sh` script sends a "External SSH Login Failed" messsage for logins that originate from the reverse SSH tunnel.
So, we want to run it whenever a login attempt failed.
We can edit `/etc/pam.d/common-auth` to achieve this (and also add a 10 seconds delay for failed login attempts):

```diff
--- a/etc/pam.d/common-auth
+++ b/etc/pam.d/common-auth
@@ -14,10 +14,12 @@
 # pam-auth-update(8) for details.
 
 # here are the per-package modules (the "Primary" block)
-auth   [success=1 default=ignore]      pam_unix.so nullok
+auth   [success=3 default=ignore]      pam_unix.so nullok
 
 # here's the fallback if no module succeeds
-auth   requisite                       pam_deny.so
+auth   optional                        pam_exec.so seteuid /etc/ssh/ez-ssh-bot-fail.sh
+auth   optional                        pam_faildelay.so delay=10000000
+auth   requisite                       pam_deny.so
 
 # prime the stack with a positive return value if there isn't one already;
 # this avoids us returning an error just because nothing sets a success code
```

## Voilà!

![ez-ssh-bot](https://user-images.githubusercontent.com/7307454/199520947-0c7dd8ba-807c-4e84-a17a-620936c4b2a1.gif)

