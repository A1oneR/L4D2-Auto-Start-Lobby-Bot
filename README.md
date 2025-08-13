# 求生之路2 开服机器人脚本
（English is translated by Gemini 2.5 Pro and will be ticketed under the Chinese part.）

由Gemini 2.5 Pro所制作而成，感谢现在的AI发展如此猛，我都不用学PowerShell语言就能够变出一个脚本出来。

需要有一台Windows虚拟机（至少能运行L4D2）一个Steam账户，没了。

测试环境为服务器**Windows 2019 Server 1H6G**

在下载好L4D2游戏程序后，复制该脚本至任意位置后，右键运行PowerShell，或者打开PowerShell后移动到对应目录下，输入**.\l4d2_autostart_bat.ps1**

脚本内要填的内容有：
- steamUsername = 机器人steam账户
- steamPassword = 机器人steam账户密码
- serverList = 要监控并开服的服务器
- steamExePath = Steam位置
- playerThreshold = 玩家数超过此值则退出服务器
- inGameCheckInterval = 在游戏中每隔多少秒检查一次人数和时间
- maxStayInSeconds = 无论人数多少, 在服务器内停留的最长时间(秒), 120秒 = 2分钟
- checkIntervalInSeconds = 所有服务器都满时的扫描间隔 (5分钟)
- steamCooldownSeconds = 切换服务器后的冷却时间, 确保Steam同步
- startHour = 脚本开始工作的小时 (9代表 9:00 AM)
- restCheckIntervalSeconds = 休息时段的检查间隔 (900秒 = 15分钟)

没了。

### 目前潜在改进项：
1. 不要死盯着一个服务器磕开服（虽然他就应该这样盯着，目前脚本会从上往下轮询，所以代表着除非上面的服务器都有人了，不然最后一个服会始终得不到关爱。）
2. 有时候游戏程序启动不正常（脚本想休息一会儿说是。）

# Left 4 Dead 2 Auto-Server Starter Bot Script
Created by Gemini 2.5 Pro. It's amazing how far AI has come; I was able to generate this script without having to learn PowerShell myself.

All you need is a Windows virtual machine (that can at least run L4D2) and a Steam account. That's it.

The testing environment was a **Windows 2019 Server with 1 Core, 6GB RAM**.

After downloading the L4D2 game files, copy this script to any location. Then, either right-click the script and select "Run with PowerShell," or open PowerShell, navigate to the script's directory, and run **.\l4d2_autostart_bat.ps1**

Here are the variables you need to configure within the script:
- steamUsername = The Steam account for the bot
- steamPassword = The Steam account password for the bot
- serverList = The list of servers to monitor and start
- steamExePath = The location of your Steam executable
- playerThreshold = The bot will leave the server if the player count exceeds this value
- inGameCheckInterval = The interval in seconds for checking the player count and time while in-game
- maxStayInSeconds = The maximum time in seconds the bot will stay in a server, regardless of player count (e.g., 120 seconds = 2 minutes)
- checkIntervalInSeconds = The scanning interval when all servers are full (e.g., 300 seconds = 5 minutes)
- steamCooldownSeconds = The cooldown period after switching servers to ensure Steam synchronization
- startHour = The hour at which the script will start running (e.g., 9 for 9:00 AM)
- restCheckIntervalSeconds = The check interval during the script's rest period (e.g., 900 seconds = 15 minutes)

That's all.

### Potential Future Improvements:
1. Prevent the script from getting stuck trying to start a single server. (Although its purpose is to keep trying. Currently, the script polls servers from top to bottom, meaning servers lower on the list won't get attention unless the ones above them are occupied.)
2. Address occasional game startup failures (the script might need a break).
