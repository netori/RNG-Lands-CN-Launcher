# RNG Lands 整合启动器（YAFSML 注入）
# 由 启动_RNG_Lands_整合版.bat 调用；也可命令行：
#   powershell -NoProfile -ExecutionPolicy Bypass -File rng_lands_launcher.ps1 -Action list
#   ... -Action vanilla -NoLaunch / -DryRun
#   ... -Action rand -Pack "Ruby\recommended increased difficulty"
#
# 功能：
#   [1] 选默认包（记住）      [2] 启动 有敌人随机（最近一次随机化输出）
#   [3] 启动 无敌人随机（默认包直接玩）   [4] 打开随机器（包路径复制到剪贴板）

[CmdletBinding()]
param(
    [ValidateSet('menu', 'list', 'select', 'rand', 'vanilla', 'randomizer', 'help')]
    [string]$Action = 'menu',
    [int]$Index = 0,
    [string]$Pack = '',
    [switch]$DryRun,
    [switch]$NoLaunch
)

$ErrorActionPreference = 'Stop'
try {
    [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
    $OutputEncoding = New-Object System.Text.UTF8Encoding($false)
} catch { }

$LauncherDir = $PSScriptRoot
$Paly        = Split-Path -Parent $LauncherDir
$PacksRoot   = Join-Path $Paly 'RNG Lands'
$YafDir      = Join-Path $Paly 'yafsml'
$YafExe      = Join-Path $YafDir 'YAFSML.exe'
$YafIni      = Join-Path $YafDir 'YAFSML.ini'
$TplPath     = Join-Path $LauncherDir 'YAFSML.ini.tpl'
$DefaultPath = Join-Path $LauncherDir 'default_pack.txt'
$RandomDir   = Join-Path $Paly 'randomizer'
$RandomExe   = Join-Path $RandomDir 'EldenRingRandomizer.exe'
$RandomLog   = Join-Path $YafDir 'log\YAFSML.log'
$ErRoot      = 'F:\game\studygame\elden ring\ELDEN RING Tarnished Edition v1.17'
$GameExe     = Join-Path $ErRoot 'Game\eldenring.exe'

# ---------------------------------------------------------------- 输出小工具
function Write-Head([string]$Text) {
    Write-Host ''
    Write-Host ('=== ' + $Text + ' ===') -ForegroundColor Cyan
}
function Write-Ok([string]$Text)   { Write-Host ('  [OK] '   + $Text) -ForegroundColor Green }
function Write-Warn([string]$Text) { Write-Host ('  [提示] ' + $Text) -ForegroundColor Yellow }
function Write-Err([string]$Text)  { Write-Host ('  [错误] ' + $Text) -ForegroundColor Red }
function Pause-Any { Write-Host ''; [void](Read-Host '按回车返回菜单') }

# ---------------------------------------------------------------- 包列表
function Get-Packs {
    if (-not (Test-Path -LiteralPath $PacksRoot)) { return @() }
    $rootLen = $PacksRoot.TrimEnd('\').Length
    $packs = @()
    $files = Get-ChildItem -LiteralPath $PacksRoot -Recurse -File -Filter 'regulation.bin' -ErrorAction SilentlyContinue
    foreach ($f in $files) {
        $dir = $f.Directory
        if ($dir.Name -ne 'recommended increased difficulty' -and $dir.Name -ne 'vanilla difficulty') { continue }
        $rel = $dir.FullName.Substring($rootLen).TrimStart('\')
        $packs += [pscustomobject]@{
            Rel   = $rel
            Full  = $dir.FullName
            Label = ($rel -replace '\\', ' / ')
        }
    }
    $packOrder = @('Ruby', 'Apache', 'Pack 10')
    $sorted = $packs | Sort-Object `
        @{ Expression = { $top = ($_.Rel -split '\\')[0]; $k = [array]::IndexOf($packOrder, $top); if ($k -lt 0) { $k = 99 }; $k } },
        @{ Expression = { $_.Rel } }
    return @($sorted)
}

function Get-DefaultRel($Packs) {
    $rel = ''
    if (Test-Path -LiteralPath $DefaultPath) {
        $rel = (Get-Content -LiteralPath $DefaultPath -TotalCount 1 -Encoding UTF8).Trim()
    }
    foreach ($p in $Packs) { if ($p.Rel -eq $rel) { return $rel } }
    foreach ($p in $Packs) { if ($p.Rel -eq 'Ruby\recommended increased difficulty') { return 'Ruby\recommended increased difficulty' } }
    if ($Packs.Count -gt 0) { return $Packs[0].Rel }
    return ''
}

function Save-DefaultRel([string]$Rel) {
    [System.IO.File]::WriteAllText($DefaultPath, $Rel + "`r`n", (New-Object System.Text.UTF8Encoding($false)))
}

# ---------------------------------------------------------------- 随机器输出
function Get-LatestRandom {
    $logDir = Join-Path $RandomDir 'spoiler_logs'
    if (-not (Test-Path -LiteralPath $logDir)) { return $null }
    $log = Get-ChildItem -LiteralPath $logDir -Filter '*_log_*.txt' -File -ErrorAction SilentlyContinue |
        Sort-Object LastWriteTime -Descending | Select-Object -First 1
    if (-not $log) { return $null }
    $head = Get-Content -LiteralPath $log.FullName -TotalCount 40 -Encoding UTF8 -ErrorAction SilentlyContinue
    $optLine = $head | Where-Object { $_ -match '^Options and seed:' } | Select-Object -First 1
    $modLine = $head | Where-Object { $_ -match '^Checking other mod directory ' } | Select-Object -First 1
    $mod = $null
    if ($modLine) { $mod = $modLine.Substring('Checking other mod directory '.Length).Trim() }
    $hasEnemy = $false
    if ($optLine -and ($optLine -match '(^|\s)enemy(\s|$)')) { $hasEnemy = $true }
    return [pscustomobject]@{
        Log      = $log.FullName
        Time     = $log.LastWriteTime
        ModDir   = $mod
        HasEnemy = $hasEnemy
    }
}

function Resolve-LogPack([string]$ModDir, [string]$DefaultRel, [switch]$Quiet) {
    if ($ModDir -and (Test-Path -LiteralPath $ModDir)) { return $ModDir }
    $difficulty = ''
    $configName = ''
    $packName = ''
    if ($ModDir) {
        $difficulty = Split-Path -Path $ModDir -Leaf
        if ($ModDir -match 'RNG Lands - (Ruby|Apache)') {
            $packName = $Matches[1]
        } elseif ($ModDir -match 'RNG Lands 0\.7\.2 (.+?)\\') {
            $configName = $Matches[1]
        }
    }
    $cands = @()
    if ($packName -and $difficulty) { $cands += (Join-Path $PacksRoot ($packName + '\' + $difficulty)) }
    if ($configName -and $difficulty) { $cands += (Join-Path $PacksRoot ('Pack 10\' + $configName + '\' + $difficulty)) }
    foreach ($c in $cands) {
        if (Test-Path -LiteralPath (Join-Path $c 'regulation.bin')) {
            if (-not $Quiet) { Write-Warn ('日志里的旧路径已不存在，按包名映射到：' + $c) }
            return $c
        }
    }
    if ($DefaultRel) {
        $d = Join-Path $PacksRoot $DefaultRel
        if ($difficulty -and (Test-Path -LiteralPath (Join-Path $d 'regulation.bin'))) {
            if (-not $Quiet) { Write-Warn ('日志里的合并来源包已不存在，退回默认包：' + ($DefaultRel -replace '\\', ' / ')) }
            return $d
        }
    }
    return $null
}

# ---------------------------------------------------------------- 生成 ini
function Write-IniFile([string]$ModLines, [string]$DllLines) {
    if (-not (Test-Path -LiteralPath $TplPath)) { throw ('缺少模板：' + $TplPath) }
    $tpl = Get-Content -LiteralPath $TplPath -Raw -Encoding UTF8
    $out = $tpl.Replace('@MOD_LINES@', $ModLines).Replace('@DLL_LINES@', $DllLines)
    $out = $out -replace "`r?`n", "`r`n"
    [System.IO.File]::WriteAllText($YafIni, $out, (New-Object System.Text.UTF8Encoding($false)))
    Write-Ok ('已生成配置：' + $YafIni)
}

function Show-IniDry([string]$ModLines, [string]$DllLines) {
    Write-Head 'DRY-RUN：即将写入 yafsml\YAFSML.ini 的 [mod] / [dll]'
    Write-Host '[mod]'
    Write-Host $ModLines
    Write-Host '[dll]'
    Write-Host $DllLines
    Write-Host ''
    Write-Host '路径检查：'
    foreach ($line in ($ModLines -split "`r?`n")) {
        if ($line -match '^\s*(RNG_Lands_Base|RNG_Lands_Randomizer)\s*=\s*(.+)$') {
            $k = $Matches[1]; $v = $Matches[2].Trim()
            $exists = Test-Path -LiteralPath $v
            Write-Host ('  ' + $k + ' -> ' + $v + '  (存在=' + $exists + ')')
        }
    }
}

# ---------------------------------------------------------------- 启动游戏
function Start-YafGame {
    if (-not (Test-Path -LiteralPath $GameExe)) { Write-Err ('找不到游戏：' + $GameExe); return $false }
    if (-not (Test-Path -LiteralPath $YafExe))  { Write-Err ('找不到 YAFSML：' + $YafExe); return $false }
    if ($NoLaunch) {
        Write-Warn '[-NoLaunch] 只写配置，不启动 YAFSML。'
        return $true
    }
    $proc = Get-Process -Name 'eldenring' -ErrorAction SilentlyContinue
    if ($proc) {
        Write-Warn '检测到游戏已在运行，先关闭旧进程...'
        $proc | ForEach-Object { try { $_.Kill() } catch { } }
        Start-Sleep -Milliseconds 1200
    }
    $arg = @('--game-path', ('"' + $ErRoot + '"'))
    Start-Process -FilePath $YafExe -ArgumentList $arg -WorkingDirectory $YafDir -WindowStyle Minimized
    Write-Host ''
    Write-Host '  已启动 YAFSML，等待 eldenring.exe（最多 60 秒）...'
    $ok = $false
    for ($i = 0; $i -lt 60; $i++) {
        Start-Sleep -Seconds 1
        if (Get-Process -Name 'eldenring' -ErrorAction SilentlyContinue) { $ok = $true; break }
    }
    if ($ok) {
        Write-Ok '游戏已启动。'
    } else {
        Write-Warn ('60 秒内没看到 eldenring.exe，看日志：' + $RandomLog)
    }
    Write-Host ('  日志：' + $RandomLog)
    Write-Host '  存档：%APPDATA%\EldenRing\<SteamID>\ER0000.cnv（独立于原版 .sl2）'
    return $ok
}

# ---------------------------------------------------------------- 选包
function Select-Pack($Packs) {
    if ($Packs.Count -eq 0) { Write-Err 'RNG Lands 文件夹里没找到任何包（需要 <包>\<难度>\regulation.bin）'; return $false }
    $defaultRel = Get-DefaultRel $Packs
    Clear-Host
    Write-Host '==============================================================' -ForegroundColor Cyan
    Write-Host '  选择默认包（* = 当前默认；共 ' + $Packs.Count + ' 个）' -ForegroundColor Cyan
    Write-Host '==============================================================' -ForegroundColor Cyan
    $i = 0
    $lastGroup = ''
    foreach ($p in $Packs) {
        $i++
        $parts = $p.Rel -split '\\'
        if ($parts.Count -ge 3) { $group = $parts[0] + ' / ' + $parts[1] } else { $group = $parts[0] }
        if ($group -ne $lastGroup) {
            Write-Host ''
            Write-Host ('  [' + $group + ']') -ForegroundColor DarkCyan
            $lastGroup = $group
        }
        $mark = ''
        if ($p.Rel -eq $defaultRel) { $mark = '   * 当前默认' }
        Write-Host ('  {0,3}. {1}{2}' -f $i, $parts[-1], $mark)
    }
    Write-Host ''
    Write-Host '  输入序号设为默认包；0 = 取消' -ForegroundColor Yellow
    $text = Read-Host '序号'
    $n = 0
    if (-not [int]::TryParse($text, [ref]$n)) { Write-Err '输入的不是数字'; return $false }
    if ($n -eq 0) { return $false }
    if ($n -lt 1 -or $n -gt $Packs.Count) { Write-Err '序号超出范围'; return $false }
    $chosen = $Packs[$n - 1]
    Save-DefaultRel $chosen.Rel
    Write-Ok ('默认包已设为：' + $chosen.Label)
    return $true
}

# ---------------------------------------------------------------- 动作：有敌人随机
function Invoke-Rand {
    $latest = Get-LatestRandom
    if (-not $latest) {
        Write-Err '还没有随机化输出（randomizer\spoiler_logs 里没有日志）。请先按 [4] 打开随机器随机化一次。'
        return
    }
    if (-not (Test-Path -LiteralPath (Join-Path $RandomDir 'regulation.bin'))) {
        Write-Err ('找不到随机化输出：' + (Join-Path $RandomDir 'regulation.bin'))
        return
    }
    $packs = Get-Packs
    $baseRel = Get-DefaultRel $packs
    $base = Resolve-LogPack $latest.ModDir $baseRel
    if (-not $base) { Write-Err '无法确定要叠哪个基础包（默认包也未设置）'; return }

    Write-Head '启动 · 有敌人随机（随机器输出 + 合并来源包）'
    Write-Host ('  随机化时间 : ' + $latest.Time.ToString('yyyy-MM-dd HH:mm:ss'))
    Write-Host ('  合并来源包 : ' + $base)
    Write-Host ('  随机化输出 : ' + $RandomDir)
    if (-not $latest.HasEnemy) {
        Write-Warn '最近一次随机化的选项里没有 enemy（敌人随机）——这版不是“有敌人随机”。'
        if (-not $DryRun) {
            $ans = Read-Host '  仍要启动吗？(y/N)'
            if ($ans -notmatch '^[yY]') { return }
        }
    }
    $modLines = 'RNG_Lands_Base=' + $base + "`r`n" + 'RNG_Lands_Randomizer=' + $RandomDir
    $dllLines = 'randomizer_crashfix=..\randomizer\dll\RandomizerCrashFix.dll|early'
    if ($DryRun) { Show-IniDry $modLines $dllLines; return }
    Write-IniFile $modLines $dllLines
    [void](Start-YafGame)
}

# ---------------------------------------------------------------- 动作：无敌人随机
function Invoke-Vanilla([switch]$ChooseFirst) {
    if ($ChooseFirst) {
        if (-not (Select-Pack (Get-Packs))) { return }
    }
    $packs = Get-Packs
    $rel = Get-DefaultRel $packs
    if (-not $rel) { Write-Err '没有可玩的包（RNG Lands 文件夹为空？）'; return }
    $full = Join-Path $PacksRoot $rel
    if (-not (Test-Path -LiteralPath (Join-Path $full 'regulation.bin'))) { Write-Err ('包不完整：' + $full); return }

    Write-Head '启动 · 无敌人随机（直接玩默认包，不经过随机器）'
    Write-Host ('  默认包 : ' + ($rel -replace '\\', ' / '))
    Write-Host ('  目录   : ' + $full)
    $modLines = 'RNG_Lands_Base=' + $full
    $dllLines = '; 无敌人随机模式：不需要额外 DLL'
    if ($DryRun) { Show-IniDry $modLines $dllLines; return }
    Write-IniFile $modLines $dllLines
    [void](Start-YafGame)
}

# ---------------------------------------------------------------- 动作：打开随机器
function Invoke-Randomizer {
    $packs = Get-Packs
    $rel = Get-DefaultRel $packs
    if (-not $rel) { Write-Err '没有可用的包'; return }
    $full = Join-Path $PacksRoot $rel
    if (-not (Test-Path -LiteralPath $RandomExe)) { Write-Err ('找不到随机器：' + $RandomExe); return }
    try { Set-Clipboard -Value $full | Out-Null } catch { }
    Write-Head '打开随机器（先选好要合并的包）'
    Write-Host ('  默认包路径（已复制到剪贴板）：')
    Write-Host ('  ' + $full) -ForegroundColor Green
    Write-Host ''
    Write-Host '  在随机器窗口里按下面做：' -ForegroundColor Yellow
    Write-Host '    1) 选好游戏 exe'
    Write-Host '    2) 点「Merge other mod」→ 选上面这个目录（或直接在路径框里 Ctrl+V）'
    Write-Host '    3) 勾选敌人随机（Enemy Randomizer 页）等选项'
    Write-Host '    4) 点随机化；完成后关掉随机器，回本菜单按 [2] 启动'
    Write-Host ''
    Write-Host '  想换别的包：回主菜单按 [1]，再按 [4]。'
    if ($DryRun) { Write-Warn '[-DryRun] 不启动随机器。'; return }
    Start-Process -FilePath $RandomExe -WorkingDirectory $RandomDir
    try { Start-Process -FilePath 'explorer.exe' -ArgumentList ('"' + $full + '"') } catch { }
}

# ---------------------------------------------------------------- 状态显示
function Show-Status {
    $packs = Get-Packs
    $rel = Get-DefaultRel $packs
    $latest = Get-LatestRandom
    Write-Host ('  可玩包数   : ' + $packs.Count)
    if ($rel) { Write-Host ('  默认包     : ' + ($rel -replace '\\', ' / ')) } else { Write-Host '  默认包     : （未设置）' }
    if ($latest) {
        if ($latest.HasEnemy) { $tag = '有敌人随机' } else { $tag = '未勾选敌人随机' }
        Write-Host ('  随机器输出 : ' + $latest.Time.ToString('yyyy-MM-dd HH:mm:ss') + '（' + $tag + '）')
        $resolved = Resolve-LogPack $latest.ModDir $rel -Quiet
        if ($resolved) {
            $label = $resolved
            if ($label.StartsWith($PacksRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
                $label = $label.Substring($PacksRoot.Length).TrimStart('\') -replace '\\', ' / '
            }
            Write-Host ('  上次合并包 : ' + $label)
        } else {
            Write-Host '  上次合并包 : （无，纯原版随机）'
        }
    } else {
        Write-Host '  随机器输出 : （还没有）'
    }
}

# ---------------------------------------------------------------- 主菜单
function Show-Menu {
    while ($true) {
        Clear-Host
        Write-Host '==============================================================' -ForegroundColor Cyan
        Write-Host '        RNG Lands（随机暗黑）整合启动器 · YAFSML 注入' -ForegroundColor Cyan
        Write-Host '==============================================================' -ForegroundColor Cyan
        Show-Status
        Write-Host '--------------------------------------------------------------'
        Write-Host ' [1] 选择默认包（用户自选，会记住）'
        Write-Host ' [2] 启动 · 有敌人随机（最近一次随机化输出 + 它合并的那个包）'
        Write-Host ' [3] 启动 · 无敌人随机（直接玩默认包，不经过随机器）'
        Write-Host ' [4] 打开随机器（把默认包路径复制到剪贴板）'
        Write-Host ' [5] 先换默认包，再启动无随机版'
        Write-Host ' [0] 退出'
        Write-Host ' 直接回车 = [3] 启动无敌人随机（默认包）'
        Write-Host '=============================================================='
        $choice = Read-Host '请选择'
        switch ($choice) {
            ''    { Invoke-Vanilla; Pause-Any }
            '1'   { [void](Select-Pack (Get-Packs)); Pause-Any }
            '2'   { Invoke-Rand; Pause-Any }
            '3'   { Invoke-Vanilla; Pause-Any }
            '4'   { Invoke-Randomizer; Pause-Any }
            '5'   { if (Select-Pack (Get-Packs)) { Invoke-Vanilla }; Pause-Any }
            '0'   { return }
            default { }
        }
    }
}

function Show-Help {
    Write-Host '用法：'
    Write-Host '  双击 启动_RNG_Lands_整合版.bat 打开菜单（推荐）'
    Write-Host '  主菜单 [1] 选默认包 → [3] 直接玩；[4] 随机化 → [2] 玩随机版'
    Write-Host ''
    Write-Host '命令行（调试用）：'
    Write-Host '  ... -Action list'
    Write-Host '  ... -Action select -Pack "Ruby\recommended increased difficulty"'
    Write-Host '  ... -Action vanilla -DryRun        （只打印将写入的配置）'
    Write-Host '  ... -Action rand -DryRun'
    Write-Host '  ... -Action vanilla -NoLaunch      （只写配置不启动）'
}

# ---------------------------------------------------------------- 入口
try {
    switch ($Action) {
        'menu'       { Show-Menu }
        'list'       { Write-Head 'RNG Lands 整合包状态'; Show-Status; Write-Host ''; foreach ($p in (Get-Packs)) { Write-Host ('  - ' + $p.Label) } }
        'select'     {
            $packs = Get-Packs
            if ($Pack) {
                $hit = $packs | Where-Object { $_.Rel -eq $Pack } | Select-Object -First 1
                if (-not $hit) { Write-Err ('没有这个包：' + $Pack); exit 1 }
                Save-DefaultRel $hit.Rel
                Write-Ok ('默认包已设为：' + $hit.Label)
            } elseif ($Index -gt 0) {
                if ($Index -gt $packs.Count) { Write-Err '序号超出范围'; exit 1 }
                Save-DefaultRel $packs[$Index - 1].Rel
                Write-Ok ('默认包已设为：' + $packs[$Index - 1].Label)
            } else {
                [void](Select-Pack $packs)
            }
        }
        'rand'       { Invoke-Rand }
        'vanilla'    { Invoke-Vanilla }
        'randomizer' { Invoke-Randomizer }
        'help'       { Show-Help }
    }
} catch {
    Write-Err ('运行出错：' + $_.Exception.Message)
    Write-Host ('  位置：' + $_.InvocationInfo.PositionMessage) -ForegroundColor DarkGray
    exit 1
}
