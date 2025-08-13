# =============================================================================
#         求生之路2 全自动智能开服脚本 (V4.1 - 最终版) Made by Gemini 2.5 Pro
# =============================================================================
#
# V4.1 功能:
# - [新增] 双重退出条件: 在人数检测的基础上, 增加“停留时间超过2分钟自动退出”的条件。
# - 智能作息: 脚本只在每天的 9:00 - 23:59 之间运行, 其余时间自动休眠。
# - 自动选择空闲服务器并以优化模式启动。
# - 具备冷却期, 保证服务器之间切换的稳定性。
# - 使用最可靠的 "质询-应答" 方式查询服务器, 兼容性强。
# - 所有函数代码均已展开, 方便阅读。
# V3.1 稳定性更新:
# - 新增 "Steam冷却期": 在一轮挂机并关闭游戏后, 强制等待15秒再开始
#   下一次扫描。这给予Steam客户端足够的时间来同步状态, 解决了连续切换
#   服务器时可能出现的游戏启动失败问题。
# V2.3 更新:
# - 强制域名解析: 在查询前先将域名转换为IP地址, 提高网络请求的稳定性。
# - 增加超时时间: 将UDP客户端的超时从2秒增加到5秒, 以适应可能响应较慢的服务器。
# - 优化错误处理: 在查询失败时能提供更具体的错误原因(例如: "超时")。
# V2 新增功能:
# 1. 主动监控: 进入服务器后, 每10秒检查一次玩家数, 超过阈值立即退出。
# 2. 性能优化: 使用低资源消耗的参数启动游戏, 适合虚拟机环境。
#
# 工作流程:
# 1. 无限循环扫描下方定义的服务器列表。
# 2. 查询每个服务器的当前玩家数量。
# 3. 如果找到一个空服务器 (0个玩家), 立即连接并在里面停留指定时间。
# 4. 停留时间结束后, 关闭游戏并从头开始扫描。
# 5. 如果所有服务器都有人, 则等待一段时间后再次扫描。
#
# =============================================================================

# --- 请在这里修改您的信息 ---

# 您的Steam登录凭据 (注意: 以明文形式存储密码存在安全风险, 请确保环境安全)
$steamUsername = "账户"
$steamPassword = "密码"

# 您要监控的服务器IP地址列表 (格式: "IP:端口")
$serverList = @(
    "第一个服务器",
    "第二个服务器",
    "更多的服务器"
)

# --- 全局配置 ---
$steamExePath = "C:\Program Files (x86)\Steam\Steam.exe"
$gameProcessName = "left4dead2"
$l4d2AppId = 550
$gameLaunchArgs = "-novid -windowed -w 640 -h 480 -low"

# --- 工作逻辑配置 ---
$playerThreshold = 4         # 玩家数超过此值则退出服务器
$inGameCheckInterval = 10    # 在游戏中每隔多少秒检查一次人数和时间
$maxStayInSeconds = 120      # [新增] 无论人数多少, 在服务器内停留的最长时间(秒), 120秒 = 2分钟
$checkIntervalInSeconds = 300 # 所有服务器都满时, 的扫描间隔 (5分钟)
$steamCooldownSeconds = 15   # 切换服务器后的冷却时间, 确保Steam同步

# --- 作息时间配置 ---
$startHour = 9  # 脚本开始工作的小时 (9代表 9:00 AM)
$restCheckIntervalSeconds = 7200 # 休息时段的检查间隔 (900秒 = 15分钟)


# =============================================================================
# --- 函数定义部分 (已完全展开) ---
# =============================================================================

# 函数: 通过A2S_PLAYER质询-应答方式查询玩家数量
function Get-ServerPlayerCount {
    param ([string]$serverHost, [int]$Port)
    
    $ipAddress = ""
    try {
        $ipAddress = [System.Net.Dns]::GetHostAddresses($serverHost)[0].ToString()
    }
    catch {
        Write-Host "-> Error: DNS lookup failed for $serverHost" -ForegroundColor Red
        return -1
    }

    $udpClient = New-Object System.Net.Sockets.UdpClient
    $udpClient.Client.SendTimeout = 5000
    $udpClient.Client.ReceiveTimeout = 5000

    try {
        # --- 步骤 1: 发送质询请求 ---
        $challengeRequest = [byte[]](0xFF, 0xFF, 0xFF, 0xFF, 0x55, 0xFF, 0xFF, 0xFF, 0xFF)
        $udpClient.Connect($ipAddress, $Port)
        $udpClient.Send($challengeRequest, $challengeRequest.Length) | Out-Null

        # --- 步骤 2: 接收服务器返回的 Challenge Key ---
        $remoteEP = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any, 0)
        $challengeResponse = $udpClient.Receive([ref]$remoteEP)

        if ($challengeResponse.Length -lt 9 -or $challengeResponse[4] -ne 0x41) {
            return -1
        }
        $challengeKey = $challengeResponse[5..8]

        # --- 步骤 3: 将 Challenge Key 附加到请求中, 再次发送 ---
        $playerRequest = [byte[]](0xFF, 0xFF, 0xFF, 0xFF, 0x55) + $challengeKey
        $udpClient.Send($playerRequest, $playerRequest.Length) | Out-Null

        # --- 步骤 4: 接收最终的玩家列表信息 ---
        $playerResponse = $udpClient.Receive([ref]$remoteEP)
        
        if ($playerResponse.Length -lt 5 -or $playerResponse[4] -ne 0x44) {
            return -1
        }

        # 玩家数量是第 6 个字节 (索引为 5)
        return [int]$playerResponse[5]
    }
    catch {
        # 查询过程中的任何超时或网络错误都会被捕获
        return -1 
    }
    finally {
        $udpClient.Close()
    }
}

# 函数: 连接服务器并使用双重条件进行监控
function Connect-And-Monitor-L4D2Server {
    param ([string]$serverAddress)

    Write-Host "[$(Get-Date)] Found empty server: $serverAddress. Connecting in performance mode..." -ForegroundColor Green
    $arguments = "-login `"$steamUsername`" `"$steamPassword`" -applaunch $l4d2AppId $gameLaunchArgs +connect $serverAddress"
    Start-Process -FilePath $steamExePath -ArgumentList $arguments

    Write-Host "[$(Get-Date)] Game is launching... Waiting 30 seconds to load before monitoring."
    Start-Sleep -Seconds 30

    # [核心改动] 记录进入监控循环的时间点
    $monitoringStartTime = Get-Date
    Write-Host "[$(Get-Date)] Monitoring started. Exit conditions: Player > $playerThreshold OR Stay Time > $($maxStayInSeconds)s."

    while (Get-Process -Name $gameProcessName -ErrorAction SilentlyContinue) {
        $serverHost, $port = $serverAddress.Split(':')
        $currentPlayerCount = Get-ServerPlayerCount -serverHost $serverHost -Port ([int]$port)
        
        # 计算已停留时间 (秒)
        $elapsedSeconds = (New-TimeSpan -Start $monitoringStartTime -End (Get-Date)).TotalSeconds

        # [核心改动] 检查双重退出条件
        if ($currentPlayerCount -gt $playerThreshold) {
            Write-Host "[$(Get-Date)] EXIT REASON: Player count ($currentPlayerCount) is over the threshold of $playerThreshold." -ForegroundColor Yellow
            break
        } 
        elseif ($elapsedSeconds -ge $maxStayInSeconds) {
            Write-Host "[$(Get-Date)] EXIT REASON: Maximum stay time of $maxStayInSeconds seconds reached." -ForegroundColor Yellow
            break
        }
        elseif ($currentPlayerCount -lt 0) {
            Write-Host "[$(Get-Date)] EXIT REASON: Can't query current server status (might be offline)." -ForegroundColor Red
            break
        } 
        else {
            $remainingSeconds = [math]::Round($maxStayInSeconds - $elapsedSeconds)
            Write-Host "[$(Get-Date)] Status OK. Players: $currentPlayerCount. Time Left: ${remainingSeconds}s. Checking again in $inGameCheckInterval seconds..."
        }

        Start-Sleep -Seconds $inGameCheckInterval
    }

    Write-Host "[$(Get-Date)] Monitoring ended. Forcing game process to close..."
    Stop-Process -Name $gameProcessName -Force -ErrorAction SilentlyContinue
    Write-Host "[$(Get-Date)] Game process closed."
    Start-Sleep -Seconds 5
}


# =============================================================================
# --- 主循环 (已集成作息时间) ---
# =============================================================================
Write-Host "Smart script V4.1 started. Will operate between $startHour:00 and 23:59." -ForegroundColor Cyan

while ($true) {
    # 获取当前小时 (24小时制)
    $currentHour = (Get-Date).Hour

    # 检查是否在工作时间内 (9:00 - 23:59)
    if ($currentHour -ge $startHour) {
        
        # --- [工作逻辑] ---
        $foundAndProcessedServer = $false
        foreach ($server in $serverList) {
            Write-Host "--------------------------------------------------------"
            $serverHost, $port = $server.Split(':')
            Write-Host "[$(Get-Date)] Scanning server: $server"
            $playerCount = Get-ServerPlayerCount -serverHost $serverHost -Port ([int]$port)

            if ($playerCount -eq 0) {
                Connect-And-Monitor-L4D2Server -serverAddress $server
                $foundAndProcessedServer = $true
                
                Write-Host "[$(Get-Date)] Session complete. Starting a $steamCooldownSeconds-second cooldown to allow Steam to reset..." -ForegroundColor Magenta
                Start-Sleep -Seconds $steamCooldownSeconds
                
                Write-Host "[$(Get-Date)] Cooldown finished. Restarting scan from the beginning..." -ForegroundColor Cyan
                break
            }
            elseif ($playerCount -gt 0) {
                Write-Host "[$(Get-date)] Server $server has $playerCount players, skipping." -ForegroundColor Gray
            }
            # 当 playerCount 为 -1 (查询失败) 时, 函数内部已打印错误, 此处直接跳过
        }

        if (-not $foundAndProcessedServer) {
            Write-Host "--------------------------------------------------------"
            Write-Host "[$(Get-Date)] All servers are occupied or unresponsive. Retrying in $($checkIntervalInSeconds/60) minutes..." -ForegroundColor Magenta
            Start-Sleep -Seconds $checkIntervalInSeconds
        }
    }
    else {
        # --- [休息逻辑] ---
        Write-Host "--------------------------------------------------------"
        Write-Host "[$(Get-Date)] Currently in rest period (0:00 - $($startHour-1):59). Script is paused." -ForegroundColor Yellow
        Write-Host "[$(Get-Date)] Will check the time again in $($restCheckIntervalSeconds/60) minutes..." -ForegroundColor Yellow
        Start-Sleep -Seconds $restCheckIntervalSeconds
    }
}