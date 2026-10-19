# RNG Lands 整合启动器（YAFSML 注入）
# 由 启动_RNG_Lands_整合版.bat 调用；也可命令行：
#   powershell -NoProfile -ExecutionPolicy Bypass -File rng_lands_launcher.ps1 -Action list
#   ... -Action vanilla -NoLaunch / -DryRun
#   ... -Action rand -Pack "Ruby\recommended increased difficulty"
#
# 功能：
#   [1] 选默认包（记住）      [2] 启动 有敌人随机（最近一次随机化输出）
#   [3] 启动 无敌人随机（默认包直接玩）   [4] 打开随机器（包路径复制到剪贴板）
#   [6] 设置游戏路径（自动检测 / 浏览选择；记住到 _launcher\game_path.txt）
#   [7] 其他 mod（附加加载：可叠别的 mod；含 regulation 的可在随机化时合并）
#   [8] Seamless Co-op 无缝联机 mod：开 / 关（固定集成，文件在 _mods\SeamlessCoop）
#
# 游戏路径不写死：优先读 _launcher\game_path.txt，其次自动检测
#（Steam 库 / 整合包附近 / 常见目录），仍找不到就弹选择框。

[CmdletBinding()]
param(
    [ValidateSet('menu', 'list', 'select', 'rand', 'vanilla', 'randomizer', 'help', 'setgame',
             'extlist', 'extadd', 'extremove', 'exttoggle', 'extpriority', 'extmerge',
             'seamless', 'seamlesson', 'seamlessoff')]
    [string]$Action = 'menu',
    [int]$Index = 0,
    [string]$Pack = '',
    [string]$GamePath = '',
    [string]$ModPath = '',
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
$GamePathFile = Join-Path $LauncherDir 'game_path.txt'
$ExtraModsFile = Join-Path $LauncherDir 'extra_mods.json'
$MergeToml     = Join-Path $LauncherDir 'merge_mods.toml'
$SeamlessDir   = Join-Path $Paly '_mods\SeamlessCoop'
$SeamlessDll   = Join-Path $SeamlessDir 'ersc.dll'
$SeamlessIni   = Join-Path $SeamlessDir 'ersc_settings.ini'
$SeamlessState = Join-Path $LauncherDir 'seamless_enabled.txt'
# 本整合包独有的独立存档（避免和 法魂 等用 .cnv 的 mod 串档）
$SaveExt       = '.rnglands'
$SaveName      = 'ER0000' + $SaveExt
$SaveNameCoop  = $SaveName + '.co2'
$script:CacheGameRoot = $null

# ---------------------------------------------------------------- 输出小工具
function Write-Head([string]$Text) {
    Write-Host ''
    Write-Host ('=== ' + $Text + ' ===') -ForegroundColor Cyan
}
function Write-Ok([string]$Text)   { Write-Host ('  [OK] '   + $Text) -ForegroundColor Green }
function Write-Warn([string]$Text) { Write-Host ('  [提示] ' + $Text) -ForegroundColor Yellow }
function Write-Err([string]$Text)  { Write-Host ('  [错误] ' + $Text) -ForegroundColor Red }
function Pause-Any { Write-Host ''; [void](Read-Host '按回车返回菜单') }
# ---------------------------------------------------------------- 游戏路径
# 游戏路径不写死：优先读 _launcher\game_path.txt（用户选择/自动检测后保存），
# 其次自动检测（Steam 库 / 整合包附近 / 常见目录），仍找不到就弹选择框。
function Test-NormalizeGameRoot([string]$Path) {
    if (-not $Path) { return $null }
    $p = $Path.Trim()
    $p = $p.Trim('"').Trim()
    if (-not $p) { return $null }
    try { $p = [System.IO.Path]::GetFullPath($p) } catch { return $null }
    $p = $p.TrimEnd('\')
    if ((Split-Path $p -Leaf) -ieq 'eldenring.exe') {
        if (Test-Path -LiteralPath $p -PathType Leaf) { $p = Split-Path (Split-Path $p -Parent) -Parent } else { return $null }
    }
    if (Test-Path -LiteralPath (Join-Path $p 'eldenring.exe') -PathType Leaf) { return (Split-Path $p -Parent) }
    if (Test-Path -LiteralPath (Join-Path $p 'Game\eldenring.exe') -PathType Leaf) { return $p }
    return $null
}

function Get-SavedGameRoot {
    if (-not (Test-Path -LiteralPath $GamePathFile)) { return $null }
    $line = Get-Content -LiteralPath $GamePathFile -TotalCount 1 -Encoding UTF8 -ErrorAction SilentlyContinue
    if (-not $line) { return $null }
    return (Test-NormalizeGameRoot ([string]$line))
}

function Save-GameRoot([string]$Root) {
    [System.IO.File]::WriteAllText($GamePathFile, $Root + "`r`n", (New-Object System.Text.UTF8Encoding($false)))
    $script:CacheGameRoot = $Root
    Write-Ok ('已保存游戏路径：' + $Root)
}

function Find-SteamGameRoots {
    $roots = New-Object System.Collections.Generic.List[string]
    $steamPath = $null
    try { $steamPath = (Get-ItemProperty -Path 'HKCU:\Software\Valve\Steam' -Name SteamPath -ErrorAction Stop).SteamPath } catch { }
    if (-not $steamPath) {
        try { $steamPath = (Get-ItemProperty -Path 'HKLM:\SOFTWARE\WOW6432Node\Valve\Steam' -Name InstallPath -ErrorAction Stop).InstallPath } catch { }
    }
    $libs = New-Object System.Collections.Generic.List[string]
    if ($steamPath) {
        $libs.Add($steamPath)
        $vdf = Join-Path $steamPath 'steamapps\libraryfolders.vdf'
        if (Test-Path -LiteralPath $vdf) {
            try {
                $txt = Get-Content -LiteralPath $vdf -Raw -Encoding UTF8 -ErrorAction Stop
                foreach ($m in [regex]::Matches($txt, '"path"\s+"([^"]+)"')) {
                    $libs.Add(($m.Groups[1].Value -replace '\\\\', '\'))
                }
            } catch { }
        }
    }
    foreach ($l in $libs) {
        foreach ($sub in @('steamapps\common\ELDEN RING', 'steamapps\common\ELDEN RING\Game')) {
            $r = Test-NormalizeGameRoot (Join-Path $l $sub)
            if ($r) { $roots.Add($r) }
        }
    }
    return @($roots | Select-Object -Unique)
}

function Find-NearbyGameRoots {
    $roots = New-Object System.Collections.Generic.List[string]
    $dir = $LauncherDir
    for ($depth = 0; $depth -lt 4; $depth++) {
        if (-not $dir) { break }
        foreach ($pat in @('ELDEN RING*', '*ELDEN*', '*elden*', '*Ring*')) {
            $dirs = Get-ChildItem -LiteralPath $dir -Directory -Filter $pat -ErrorAction SilentlyContinue | Select-Object -First 40
            foreach ($d in $dirs) {
                $r = Test-NormalizeGameRoot $d.FullName
                if ($r) { $roots.Add($r) }
                $subs = Get-ChildItem -LiteralPath $d.FullName -Directory -ErrorAction SilentlyContinue | Select-Object -First 40
                foreach ($d2 in $subs) {
                    $r2 = Test-NormalizeGameRoot $d2.FullName
                    if ($r2) { $roots.Add($r2) }
                }
            }
        }
        $dir = Split-Path $dir -Parent
    }
    return @($roots | Select-Object -Unique)
}

function Find-CommonGameRoots {
    $roots = New-Object System.Collections.Generic.List[string]
    $drives = @()
    try {
        $drives = @(Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue |
            Where-Object { $_.Root -match '^[A-Za-z]:\\$' } | ForEach-Object { $_.Root })
    } catch { }
    $rels = @(
        'SteamLibrary\steamapps\common\ELDEN RING',
        'Steam\steamapps\common\ELDEN RING',
        'SteamLibrary2\steamapps\common\ELDEN RING',
        'Games\ELDEN RING',
        'Game\ELDEN RING',
        'Program Files (x86)\Steam\steamapps\common\ELDEN RING',
        'Program Files\Steam\steamapps\common\ELDEN RING'
    )
    foreach ($d in $drives) {
        foreach ($rel in $rels) {
            $r = Test-NormalizeGameRoot (Join-Path $d $rel)
            if ($r) { $roots.Add($r) }
        }
    }
    return @($roots | Select-Object -Unique)
}

function Get-GameCandidates {
    $all = New-Object System.Collections.Generic.List[string]
    foreach ($r in (@(Find-SteamGameRoots) + @(Find-NearbyGameRoots) + @(Find-CommonGameRoots))) {
        if ($r) { $all.Add($r) }
    }
    return @($all | Select-Object -Unique)
}

function Resolve-GameRoot([switch]$Refresh) {
    if (-not $Refresh -and $script:CacheGameRoot) { return $script:CacheGameRoot }
    $saved = Get-SavedGameRoot
    if ($saved) { $script:CacheGameRoot = $saved; return $saved }
    $cands = @(Get-GameCandidates)
    if ($cands.Count -eq 1) {
        $script:CacheGameRoot = $cands[0]
        try {
            [System.IO.File]::WriteAllText($GamePathFile, $cands[0] + "`r`n", (New-Object System.Text.UTF8Encoding($false)))
        } catch { }
        Write-Ok ('自动检测到游戏路径并已记住：' + $cands[0])
        return $cands[0]
    }
    return $null
}

function Pick-FolderDialog([string]$Title) {
    try { Add-Type -AssemblyName System.Windows.Forms | Out-Null } catch { return $null }
    try {
        $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
        $dlg.Description = $Title
        $dlg.ShowNewFolderButton = $false
        $cur = Resolve-GameRoot
        if ($cur) { $dlg.SelectedPath = $cur }
        if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { return $dlg.SelectedPath }
    } catch { }
    return $null
}

function Pick-ExeDialog([string]$Title) {
    try { Add-Type -AssemblyName System.Windows.Forms | Out-Null } catch { return $null }
    try {
        $dlg = New-Object System.Windows.Forms.OpenFileDialog
        $dlg.Title = $Title
        $dlg.Filter = 'eldenring.exe|eldenring.exe|所有文件|*.*'
        $cur = Resolve-GameRoot
        if ($cur) { $dlg.InitialDirectory = (Join-Path $cur 'Game') }
        if ($dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) { return $dlg.FileName }
    } catch { }
    return $null
}

function Set-GameRootInteractive {
    while ($true) {
        $cur = Get-SavedGameRoot
        $cands = @(Get-GameCandidates)
        Clear-Host
        Write-Host '==============================================================' -ForegroundColor Cyan
        Write-Host '   设置 Elden Ring 游戏路径（只需选一次，会记住）' -ForegroundColor Cyan
        Write-Host '==============================================================' -ForegroundColor Cyan
        if ($cur) {
            Write-Host ('  当前：' + $cur) -ForegroundColor Green
        } else {
            $resolved = Resolve-GameRoot
            if ($resolved) { Write-Host ('  当前：' + $resolved) -ForegroundColor Green }
            else { Write-Host '  当前：未设置' -ForegroundColor Yellow }
        }
        Write-Host ''
        if ($cands.Count -gt 0) {
            Write-Host '  自动检测到的候选：'
            for ($i = 0; $i -lt $cands.Count; $i++) {
                Write-Host ('   [{0}] {1}' -f ($i + 1), $cands[$i]) -ForegroundColor White
            }
        } else {
            Write-Host '  自动检测：没有找到（可手动浏览）' -ForegroundColor DarkGray
        }
        Write-Host ''
        Write-Host '   输入序号 = 使用该候选'
        Write-Host '   [F] 浏览文件夹（选包含 Game\eldenring.exe 的目录，或 Game 目录本身）'
        Write-Host '   [E] 直接选择 eldenring.exe'
        Write-Host '   [A] 重新自动检测'
        Write-Host '   [Q] 取消'
        Write-Host '=============================================================='
        $sel = Read-Host '请选择'
        if ($null -eq $sel) { return $false }
        $sel = ([string]$sel).Trim()
        if ($sel -eq '') { continue }
        if ($sel -match '^[qQ]$') { return $false }
        if ($sel -match '^[aA]$') { $script:CacheGameRoot = $null; continue }
        if ($sel -match '^[fF]$') {
            $picked = Pick-FolderDialog '选择 Elden Ring 目录（包含 Game\eldenring.exe 的那层，或直接选 Game 文件夹）'
            if (-not $picked) { continue }
            $root = Test-NormalizeGameRoot $picked
            if ($root) { Save-GameRoot $root; return $true }
            Write-Err ('这个目录里没找到 Game\eldenring.exe：' + $picked)
            [void](Read-Host '按回车重试')
            continue
        }
        if ($sel -match '^[eE]$') {
            $picked = Pick-ExeDialog '选择 eldenring.exe'
            if (-not $picked) { continue }
            $root = Test-NormalizeGameRoot $picked
            if ($root) { Save-GameRoot $root; return $true }
            Write-Err ('这个 exe 的位置不像 Elden Ring 安装：' + $picked)
            [void](Read-Host '按回车重试')
            continue
        }
        $n = 0
        if ([int]::TryParse($sel, [ref]$n) -and $n -ge 1 -and $n -le $cands.Count) {
            Save-GameRoot $cands[$n - 1]
            return $true
        }
        $root = Test-NormalizeGameRoot $sel
        if ($root) { Save-GameRoot $root; return $true }
        Write-Err ('无法识别（可输入序号、[F]/[E]/[A]/[Q]，或粘贴路径）：' + $sel)
        [void](Read-Host '按回车重试')
    }
    return $false
}


# ---------------------------------------------------------------- 其他 mod
# 往整合里叠加别的 mod 目录：启动时写进 YAFSML 的 [mod] 段（YAFSML 后声明覆盖先声明）。
#   low  = 排在 RNG Lands 基础包/随机器输出之前 → 冲突文件被它们覆盖（安全默认）
#   high = 排在之后 → 覆盖随机化结果（适合 UI / 贴图 / 字体 / 音效等）
#   merge= true 时，打开随机器会生成 ModEngine 格式的合并清单（merge_mods.toml），
#          可在随机器「Merge other mod」里一次合并列表里所有 mod。
# 含 regulation.bin 的 mod：启动时只能按优先级“整个替换/被替换”，不能数值合并；
# 要让它和 RNG Lands 的参数同时生效，需要在随机化时合并（[M] 开关），或接受一方覆盖。
function Get-ExtraMods {
    if (-not (Test-Path -LiteralPath $ExtraModsFile)) { return @() }
    $raw = ''
    try { $raw = Get-Content -LiteralPath $ExtraModsFile -Raw -Encoding UTF8 -ErrorAction Stop } catch { return @() }
    if (-not $raw -or -not $raw.Trim()) { return @() }
    $data = $null
    try { $data = $raw | ConvertFrom-Json } catch {
        Write-Warn ('其他 mod 配置解析失败（按空处理）：' + $_.Exception.Message)
        return @()
    }
    $list = @()
    if ($data -is [System.Array]) { $list = @($data) }
    elseif ($null -ne $data.mods) { $list = @($data.mods) }
    $out = @()
    foreach ($m in $list) {
        if ($null -eq $m) { continue }
        $enabled = $true
        if ($null -ne $m.enabled) { $enabled = [bool]$m.enabled }
        $priority = 'low'
        if ([string]$m.priority -eq 'high') { $priority = 'high' }
        $merge = $false
        if ($null -ne $m.merge) { $merge = [bool]$m.merge }
        $out += [pscustomobject]@{
            name     = [string]$m.name
            path     = [string]$m.path
            enabled  = $enabled
            priority = $priority
            merge    = $merge
        }
    }
    return @($out)
}

function Save-ExtraMods($Mods) {
    $arr = @()
    foreach ($m in @($Mods)) {
        if ($null -eq $m) { continue }
        $arr += [ordered]@{
            name     = [string]$m.name
            path     = [string]$m.path
            enabled  = [bool]$m.enabled
            priority = [string]$m.priority
            merge    = [bool]$m.merge
        }
    }
    $obj = [ordered]@{ version = 2; mods = @($arr) }
    $json = $obj | ConvertTo-Json -Depth 6
    [System.IO.File]::WriteAllText($ExtraModsFile, $json + "`r`n", (New-Object System.Text.UTF8Encoding($false)))
}

function Test-ModRootLike([string]$Dir) {
    if (-not $Dir) { return $false }
    if (-not (Test-Path -LiteralPath $Dir -PathType Container)) { return $false }
    if (Test-Path -LiteralPath (Join-Path $Dir 'regulation.bin') -PathType Leaf) { return $true }
    $marks = @('event','map','msg','script','sfx','chr','parts','menu','action','asset','material','param','sound','remap','font','shader')
    $hits = 0
    foreach ($m in $marks) { if (Test-Path -LiteralPath (Join-Path $Dir $m)) { $hits++ } }
    return ($hits -ge 2)
}

function Resolve-ModRoot([string]$Path) {
    if (-not $Path) { return $null }
    $p = ([string]$Path).Trim().Trim('"').Trim()
    if (-not $p) { return $null }
    if (-not [System.IO.Path]::IsPathRooted($p)) { $p = Join-Path (Get-Location).Path $p }
    if (Test-Path -LiteralPath $p -PathType Leaf) { $p = [System.IO.Path]::GetDirectoryName($p) }
    try { $p = [System.IO.Path]::GetFullPath($p) } catch { return $null }
    $p = $p.TrimEnd('\')
    if (-not (Test-Path -LiteralPath $p -PathType Container)) { return $null }
    # 1) 本身就是 mod 根（含 regulation.bin，或至少两个标准资产目录）
    if (Test-ModRootLike $p) { return $p }
    # 2) 里面是 mod 子目录（Nexus 常见解压结构：<Mod>\mod\...）
    $modSub = Join-Path $p 'mod'
    if (Test-Path -LiteralPath $modSub -PathType Container) {
        $inner = @(Get-ChildItem -LiteralPath $modSub -Force -ErrorAction SilentlyContinue | Select-Object -First 1)
        if ($inner.Count -gt 0) { return $modSub }
    }
    # 3) 单层包装：<解压目录>\<Mod>\mod\... 或 <解压目录>\<Mod>\...
    $children = @(Get-ChildItem -LiteralPath $p -Directory -ErrorAction SilentlyContinue | Select-Object -First 12)
    foreach ($c in $children) {
        $cm = Join-Path $c.FullName 'mod'
        if (Test-Path -LiteralPath $cm -PathType Container) {
            $inner = @(Get-ChildItem -LiteralPath $cm -Force -ErrorAction SilentlyContinue | Select-Object -First 1)
            if ($inner.Count -gt 0) { return $cm }
        }
    }
    foreach ($c in $children) {
        if (Test-ModRootLike $c.FullName) { return $c.FullName }
    }
    return $null
}

function Get-ExtraModInfo($Mod) {
    $exists = $false
    if ($Mod.path -and (Test-Path -LiteralPath $Mod.path -PathType Container)) { $exists = $true }
    $hasReg = $false
    $hasCore = $false
    if ($exists) {
        if (Test-Path -LiteralPath (Join-Path $Mod.path 'regulation.bin') -PathType Leaf) { $hasReg = $true }
        foreach ($d in @('msg','script','event','map')) {
            if (Test-Path -LiteralPath (Join-Path $Mod.path $d)) { $hasCore = $true }
        }
    }
    return [pscustomobject]@{ Exists = $exists; HasRegulation = $hasReg; HasCoreData = $hasCore }
}

function Write-ExtraModNotes($Mod) {
    $info = Get-ExtraModInfo $Mod
    if (-not $info.Exists) { Write-Host '        ! 目录不在了（请删除或重新添加）' -ForegroundColor Red; return }
    if ($info.HasRegulation) {
        if ($Mod.priority -eq 'high') {
            Write-Host '        ! 含 regulation.bin 且为「高」：会覆盖随机化输出的参数表（随机化可能失效）' -ForegroundColor Red
        } else {
            Write-Host '        · 含 regulation.bin：「低」时它的参数表会被 RNG Lands / 随机器输出覆盖；要让它生效请改「高」或勾选「随机化合并」' -ForegroundColor Yellow
        }
    } elseif ($Mod.priority -eq 'high' -and $info.HasCoreData) {
        Write-Host '        · 含文本/脚本/事件类文件且为「高」：会覆盖随机化后的内容；若只想补充素材，建议改「低」' -ForegroundColor Yellow
    }
}

function Add-ExtraMod([string]$Path) {
    $root = Resolve-ModRoot $Path
    if (-not $root) {
        Write-Err ('不像是 mod 目录（没找到 regulation.bin 或 mod 资产目录）：' + $Path)
        Write-Host '        支持：<mod 根>（含 regulation.bin / event / msg 等）、<mod 根>\mod、下载解压后的单层包装目录。' -ForegroundColor DarkGray
        return $false
    }
    $mods = @(Get-ExtraMods)
    foreach ($m in $mods) {
        if ($m.path -and ($m.path.TrimEnd('\') -ieq $root.TrimEnd('\'))) {
            Write-Warn ('这个 mod 已经在列表里了：' + $root)
            return $false
        }
    }
    $name = [System.IO.Path]::GetFileName($root)
    if ($name -ieq 'mod') { $name = [System.IO.Path]::GetFileName([System.IO.Path]::GetDirectoryName($root)) }
    $info = Get-ExtraModInfo ([pscustomobject]@{ path = $root })
    $entry = [pscustomobject]@{
        name     = $name
        path     = $root
        enabled  = $true
        priority = $(if ($info.HasRegulation) { 'low' } else { 'high' })
        merge    = $false
    }
    $mods += $entry
    Save-ExtraMods $mods
    Write-Ok ('已添加其他 mod：' + $name)
    Write-Host ('        目录：' + $root) -ForegroundColor DarkGray
    Write-ExtraModNotes $entry
    return $true
}

function Add-ExtraModInteractive {
    Write-Host ''
    Write-Host '  输入其他 mod 的目录（可直接粘贴路径）；B = 浏览文件夹；Q = 取消'
    Write-Host '  支持：<mod 根>（含 regulation.bin / 资产目录）、<mod 根>\mod、单层包装目录。'
    $text = Read-Host '  路径'
    if ($null -eq $text) { return $false }   # 输入流结束
    $t = ([string]$text).Trim().Trim('"').Trim()
    if (-not $t) { return $false }
    if ($t -match '^[qQ]$') { return $false }
    if ($t -match '^[bB]$') {
        $t = Pick-FolderDialog '选择其他 mod 的目录（含 regulation.bin 或 mod 子目录的那层）'
        if (-not $t) { return $false }
    }
    return (Add-ExtraMod $t)
}

function Update-ExtraMods([string]$Op, [int]$Index) {
    $mods = @(Get-ExtraMods)
    if ($mods.Count -eq 0) { Write-Warn '还没有添加任何 mod（先按 [A] 添加）'; return $false }
    if ($Index -lt 1 -or $Index -gt $mods.Count) { Write-Err ('序号超出范围（1 - ' + $mods.Count + '）'); return $false }
    $m = $mods[$Index - 1]
    switch ($Op) {
        'toggle' {
            $m.enabled = -not $m.enabled
            $state = $(if ($m.enabled) { '启用' } else { '停用' })
            Write-Ok ('已' + $state + '：' + $m.name)
        }
        'priority' {
            if ($m.priority -eq 'high') { $m.priority = 'low' } else { $m.priority = 'high' }
            $prio = $(if ($m.priority -eq 'high') { '高' } else { '低' })
            Write-Ok ('优先级已设为「' + $prio + '」：' + $m.name)
        }
        'merge' {
            $m.merge = -not $m.merge
            if ($m.merge) { Write-Ok ('已加入随机化合并清单：' + $m.name) }
            else { Write-Ok ('已移出随机化合并清单：' + $m.name) }
        }
        'up' {
            if ($Index -le 1) { Write-Warn '已经在最上面了'; return $false }
            $mods[$Index - 1] = $mods[$Index - 2]
            $mods[$Index - 2] = $m
            Write-Ok ('已上移：' + $m.name)
        }
        'down' {
            if ($Index -ge $mods.Count) { Write-Warn '已经在最下面了'; return $false }
            $mods[$Index - 1] = $mods[$Index]
            $mods[$Index] = $m
            Write-Ok ('已下移：' + $m.name)
        }
        'remove' {
            $new = @()
            for ($i = 0; $i -lt $mods.Count; $i++) {
                if ($i -eq ($Index - 1)) { continue }
                $new += $mods[$i]
            }
            $mods = $new
            Write-Ok ('已删除：' + $m.name)
        }
        default { Write-Err ('未知操作：' + $Op); return $false }
    }
    Save-ExtraMods $mods
    return $true
}

function Read-ExtraModIndex($Mods) {
    if ($Mods.Count -eq 0) { Write-Warn '列表是空的'; return 0 }
    $text = Read-Host '  序号（直接回车取消）'
    if (-not $text) { return 0 }
    $n = 0
    if (-not [int]::TryParse(([string]$text).Trim(), [ref]$n)) { Write-Warn '输入的不是数字'; return 0 }
    if ($n -lt 1 -or $n -gt $Mods.Count) { Write-Warn '序号超出范围'; return 0 }
    return $n
}

function Get-ExtraModLines([string]$Priority) {
    $lines = New-Object System.Collections.Generic.List[string]
    $mods = @(Get-ExtraMods)
    $n = 0
    foreach ($m in $mods) {
        $n++
        if (-not $m.enabled) { continue }
        if ($m.priority -ne $Priority) { continue }
        $role = '低优先级：被基础包/随机结果覆盖'
        if ($Priority -eq 'high') { $role = '高优先级：覆盖随机结果' }
        $lines.Add('; 附加 mod（' + $role + '）：' + $m.name)
        $lines.Add('Extra_' + $Priority + '_' + $n + '=' + $m.path)
    }
    return @($lines)
}

function Format-TomlModEntry([string]$Name, [string]$Path) {
    $n = ([string]$Name).Replace('\', '\\').Replace('"', '\"')
    $p = ([string]$Path).Replace('\', '\\').Replace('"', '\"')
    return ('{ enabled = true, name = "' + $n + '", path = "' + $p + '" }')
}

function New-MergeToml([string]$BaseFull) {
    $extras = @((Get-ExtraMods) | Where-Object { $_.enabled -and $_.merge })
    $entries = New-Object System.Collections.Generic.List[string]
    foreach ($m in $extras) {
        if ($m.priority -eq 'high') { $entries.Add((Format-TomlModEntry $m.name $m.path)) }
    }
    $entries.Add((Format-TomlModEntry 'RNG_Lands_Base' $BaseFull))
    foreach ($m in $extras) {
        if ($m.priority -ne 'high') { $entries.Add((Format-TomlModEntry $m.name $m.path)) }
    }
    $lines = New-Object System.Collections.Generic.List[string]
    $lines.Add('# 由 RNG Lands 整合启动器自动生成（每次打开随机器时重写）')
    $lines.Add('# 用法：EldenRingRandomizer -> Merge other mod -> 选这个 .toml 文件')
    $lines.Add('# 顺序 = ModEngine 优先级（排前面的冲突文件优先）；RNG_Lands_Base 是当前默认包')
    $lines.Add('')
    $lines.Add('[modengine]')
    $lines.Add('debug = false')
    $lines.Add('external_dlls = []')
    $lines.Add('')
    $lines.Add('[extension.mod_loader]')
    $lines.Add('enabled = true')
    $lines.Add('loose_params = false')
    $lines.Add('mods = [')
    for ($i = 0; $i -lt $entries.Count; $i++) {
        $tail = ','
        if ($i -eq ($entries.Count - 1)) { $tail = '' }
        $lines.Add('    ' + $entries[$i] + $tail)
    }
    $lines.Add(']')
    return (($lines -join "`r`n") + "`r`n")
}

function Show-ExtraModsMenu {
    while ($true) {
        $mods = @(Get-ExtraMods)
        Clear-Host
        Write-Host '==============================================================' -ForegroundColor Cyan
        Write-Host '  其他 mod（附加加载 / 随机化合并）' -ForegroundColor Cyan
        Write-Host '==============================================================' -ForegroundColor Cyan
        Write-Host '  「低」= 排在 RNG Lands/随机器输出之前：冲突文件被覆盖（安全默认）'
        Write-Host '  「高」= 排在之后：会覆盖随机化结果（适合 UI / 贴图 / 字体 / 音效）'
        Write-Host '  [M] 只影响「打开随机器」时生成的合并清单，不改变启动顺序。'
        Write-Host '--------------------------------------------------------------'
        if ($mods.Count -eq 0) {
            Write-Host '  （还没有添加任何 mod）' -ForegroundColor DarkGray
        } else {
            $i = 0
            foreach ($m in $mods) {
                $i++
                $state = $(if ($m.enabled) { '启用' } else { '停用' })
                $prio = $(if ($m.priority -eq 'high') { '高' } else { '低' })
                $mergeTag = ''
                if ($m.merge) { $mergeTag = ' [随机化合并]' }
                Write-Host ('  {0,3}. [{1}] 优先级:{2}{3}  {4}' -f $i, $state, $prio, $mergeTag, $m.name)
                Write-Host ('        ' + $m.path) -ForegroundColor DarkGray
                Write-ExtraModNotes $m
            }
        }
        Write-Host ''
        Write-Host ' [A] 添加 mod（粘贴路径 / B 浏览文件夹）'
        Write-Host ' [E] 启用/停用   [P] 低/高优先级   [M] 随机化合并开关'
        Write-Host ' [U] 上移   [D] 下移   [R] 删除'
        Write-Host ' [Q] 返回主菜单'
        Write-Host ''
        $sel = Read-Host '请选择'
        if ($null -eq $sel) { return }   # 输入流结束（非交互调用）时直接返回主菜单
        $cmd = $sel.Trim().ToLower()
        switch ($cmd) {
            'a' { [void](Add-ExtraModInteractive); Pause-Any }
            'e' { $n = Read-ExtraModIndex $mods; if ($n -gt 0) { [void](Update-ExtraMods 'toggle' $n) }; Pause-Any }
            'p' { $n = Read-ExtraModIndex $mods; if ($n -gt 0) { [void](Update-ExtraMods 'priority' $n) }; Pause-Any }
            'm' { $n = Read-ExtraModIndex $mods; if ($n -gt 0) { [void](Update-ExtraMods 'merge' $n) }; Pause-Any }
            'u' { $n = Read-ExtraModIndex $mods; if ($n -gt 0) { [void](Update-ExtraMods 'up' $n) }; Pause-Any }
            'd' { $n = Read-ExtraModIndex $mods; if ($n -gt 0) { [void](Update-ExtraMods 'down' $n) }; Pause-Any }
            'r' { $n = Read-ExtraModIndex $mods; if ($n -gt 0) { [void](Update-ExtraMods 'remove' $n) }; Pause-Any }
            'q' { return }
            default { }
        }
    }
}

# ---------------------------------------------------------------- Seamless Co-op（固定集成）
# 说明：Seamless Co-op 靠一个外部 DLL（ersc.dll）+ 同目录的 ersc_settings.ini / locale / crashpad 工作。
#       文件固定放在 paly\_mods\SeamlessCoop，用绝对路径加载；开关只决定 [dll] 里有没有这一行。
#       先例：旧 YAFSML 配置里 seamlesscoop=../SeamlessCoop/ersc.dll（不写加载条件）可正常联机。
function Get-SeamlessEnabled {
    if (-not (Test-Path -LiteralPath $SeamlessState)) { return $false }
    $v = Get-Content -LiteralPath $SeamlessState -TotalCount 1 -Encoding UTF8 -ErrorAction SilentlyContinue
    if ($null -eq $v) { return $false }
    return ($v.Trim() -eq '1')
}
function Set-SeamlessEnabled([bool]$Enabled) {
    $v = '0'
    if ($Enabled) { $v = '1' }
    [System.IO.File]::WriteAllText($SeamlessState, $v + "`r`n", (New-Object System.Text.UTF8Encoding($false)))
}
function Get-SeamlessVersion {
    $vf = Join-Path $SeamlessDir 'VERSION.txt'
    if (Test-Path -LiteralPath $vf) {
        $v = Get-Content -LiteralPath $vf -TotalCount 1 -Encoding UTF8 -ErrorAction SilentlyContinue
        if ($v) { return $v.Trim() }
    }
    return '（未知版本）'
}
function Get-SeamlessDllLine {
    if (-not (Get-SeamlessEnabled)) { return '' }
    if (-not (Test-Path -LiteralPath $SeamlessDll)) {
        Write-Warn ('Seamless Co-op 已开启，但找不到 DLL：' + $SeamlessDll)
        return ''
    }
    return ('seamlesscoop=' + $SeamlessDll)
}
function Show-SeamlessMenu {
    while ($true) {
        $enabled = Get-SeamlessEnabled
        $hasDll = Test-Path -LiteralPath $SeamlessDll
        Clear-Host
        Write-Host '==============================================================' -ForegroundColor Cyan
        Write-Host '  Seamless Co-op（无缝联机）· 固定集成' -ForegroundColor Cyan
        Write-Host '==============================================================' -ForegroundColor Cyan
        $state = '关闭'
        if ($enabled) { $state = '开启' }
        Write-Host ('  当前状态 : ' + $state)
        Write-Host ('  版本     : ' + (Get-SeamlessVersion))
        Write-Host ('  DLL      : ' + $SeamlessDll + '  (存在=' + $hasDll + ')')
        Write-Host ('  配置     : ' + $SeamlessIni + '  (存在=' + (Test-Path -LiteralPath $SeamlessIni) + ')')
        Write-Host ''
        Write-Host '  说明：' -ForegroundColor Yellow
        Write-Host '   - 开启后启动游戏时由 YAFSML 加载 ersc.dll；关掉就完全不加载（游戏回到纯单机）。'
        Write-Host ('   - 联机存档独立：' + $SaveNameCoop + '（不覆盖单机存档 ' + $SaveName + '）。')
        Write-Host '   - 联机要求：游戏版本一致 + Steam 在线 + 同一密码（ersc_settings.ini 里 cooppassword）；'
        Write-Host '     队友也要装同版本 Seamless Co-op。'
        Write-Host '   - 与随机 mod 叠加不保证稳定：联机异常时先关掉它，用单机模式复现问题。'
        Write-Host ''
        Write-Host '  [1] 开启    [2] 关闭    [Q] 返回' -ForegroundColor Yellow
        $sel = Read-Host '请选择'
        if ($null -eq $sel) { return }
        $sel = $sel.Trim().ToLower()
        if ($sel -eq '1') {
            if (-not $hasDll) {
                Write-Err ('找不到 DLL：' + $SeamlessDll + '（先把 Seamless Co-op 解压到 _mods\SeamlessCoop）')
                Pause-Any
            } else {
                Set-SeamlessEnabled $true
                Write-Ok '已开启 Seamless Co-op（下次启动游戏生效）'
                Start-Sleep -Seconds 1
            }
        } elseif ($sel -eq '2') {
            Set-SeamlessEnabled $false
            Write-Ok '已关闭 Seamless Co-op'
            Start-Sleep -Seconds 1
        } elseif ($sel -eq 'q') {
            return
        }
    }
}

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
        if ($line -match '^\s*(RNG_Lands_Base|RNG_Lands_Randomizer|Extra_[A-Za-z]+_\d+)\s*=\s*(.+)$') {
            $k = $Matches[1]; $v = $Matches[2].Trim()
            $exists = Test-Path -LiteralPath $v
            Write-Host ('  ' + $k + ' -> ' + $v + '  (存在=' + $exists + ')')
        }
    }
    foreach ($line in ($DllLines -split "`r?`n")) {
        if ($line -match '^\s*([A-Za-z0-9_]+)\s*=\s*(.+)$') {
            $k = $Matches[1]; $v = $Matches[2].Trim()
            $vPath = ($v -split '\|')[0].Trim()
            if (-not [System.IO.Path]::IsPathRooted($vPath)) { $vPath = Join-Path $YafDir $vPath }
            $exists = Test-Path -LiteralPath $vPath
            Write-Host ('  dll.' + $k + ' -> ' + $v + '  (存在=' + $exists + ')')
        }
    }
}

# ---------------------------------------------------------------- 启动游戏
function Start-YafGame {
    if (-not (Test-Path -LiteralPath $YafExe))  { Write-Err ('找不到 YAFSML：' + $YafExe); return $false }
    $erRoot = Resolve-GameRoot
    if (-not $erRoot) {
        Write-Warn '还没有可用的游戏路径（未设置，或自动检测到多个候选）。先选一下游戏目录：'
        if (-not (Set-GameRootInteractive)) { Write-Err '未选择游戏路径，取消启动。'; return $false }
        $erRoot = Resolve-GameRoot -Refresh
    }
    $gameExe = Join-Path $erRoot 'Game\eldenring.exe'
    if (-not (Test-Path -LiteralPath $gameExe)) { Write-Err ('游戏路径无效（找不到 Game\eldenring.exe）：' + $erRoot); return $false }
    Write-Host ('  游戏：' + $gameExe)
    if (Get-SeamlessEnabled) { Write-Host '  联机 mod：Seamless Co-op 已开启' }
    # 旧共用存档提醒：v1.4.0 之前用 ER0000.cnv（和 法魂 等 mod 共用），现在本整合包用 ER0000.rnglands
    $erSaveDir = Join-Path $env:APPDATA 'EldenRing'
    if (Test-Path -LiteralPath $erSaveDir) {
        $legacySaves = @(Get-ChildItem -LiteralPath $erSaveDir -Recurse -File -Filter 'ER0000.cnv' -ErrorAction SilentlyContinue)
        $newSaves = @(Get-ChildItem -LiteralPath $erSaveDir -Recurse -File -Filter $SaveName -ErrorAction SilentlyContinue)
        if ($legacySaves.Count -gt 0 -and $newSaves.Count -eq 0) {
            Write-Warn ('旧存档 ER0000.cnv 未动：它和 法魂 等用 .cnv 的 mod 是同一个文件；本整合包现在用 ' + $SaveName + '，不会自动搬过去。')
            Write-Warn ('想沿用旧进度：退出游戏后把 ER0000.cnv 复制/改名为 ' + $SaveName + '（旧文件可能混着别的 mod 的进度，自己判断）。')
        }
    }
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
    $arg = @('--game-path', ('"' + $erRoot + '"'))
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
    if (Get-SeamlessEnabled) {
        Write-Host ('  存档：%APPDATA%\EldenRing\<SteamID>\' + $SaveNameCoop + '（Seamless 联机存档；本整合包独有）')
    } else {
        Write-Host ('  存档：%APPDATA%\EldenRing\<SteamID>\' + $SaveName + '（本整合包独有，独立于原版 .sl2）')
    }
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
    $lowLines = @(Get-ExtraModLines 'low')
    $highLines = @(Get-ExtraModLines 'high')
    $core = @(('RNG_Lands_Base=' + $base), ('RNG_Lands_Randomizer=' + $RandomDir))
    $modLines = (@($lowLines) + $core + @($highLines)) -join "`r`n"
    $dllParts = @('randomizer_crashfix=..\randomizer\dll\RandomizerCrashFix.dll|early')
    $seamlessLine = Get-SeamlessDllLine
    if ($seamlessLine) { $dllParts += $seamlessLine }
    $dllLines = $dllParts -join "`r`n"
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
    $lowLines = @(Get-ExtraModLines 'low')
    $highLines = @(Get-ExtraModLines 'high')
    $modLines = (@($lowLines) + @('RNG_Lands_Base=' + $full) + @($highLines)) -join "`r`n"
    $dllParts = @()
    $seamlessLine = Get-SeamlessDllLine
    if ($seamlessLine) { $dllParts += $seamlessLine }
    if ($dllParts.Count -eq 0) { $dllParts = @('; 无敌人随机模式：不需要额外 DLL') }
    $dllLines = $dllParts -join "`r`n"
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
    $mergeMods = @((Get-ExtraMods) | Where-Object { $_.enabled -and $_.merge })
    $tomlPath = $null
    if ($mergeMods.Count -gt 0) {
        if (-not $DryRun) {
            [System.IO.File]::WriteAllText($MergeToml, (New-MergeToml $full), (New-Object System.Text.UTF8Encoding($false)))
            $tomlPath = $MergeToml
        }
    }
    $clip = $full
    if ($tomlPath) { $clip = $tomlPath }
    try { Set-Clipboard -Value $clip | Out-Null } catch { }
    Write-Head '打开随机器（先选好要合并的包 / mod）'
    if ($mergeMods.Count -gt 0) {
        Write-Host '  合并清单（已复制到剪贴板）：' -ForegroundColor Green
        Write-Host ('  ' + $MergeToml)
        Write-Host ('  包含：RNG Lands 基础包 + ' + $mergeMods.Count + ' 个附加 mod（高优先级排前面）')
        foreach ($m in $mergeMods) { Write-Host ('    - ' + $m.name + '  (' + $m.priority + ')') -ForegroundColor DarkGray }
        Write-Host ''
        Write-Host '  在随机器窗口里按下面做：' -ForegroundColor Yellow
        Write-Host '    1) 选好游戏 exe'
        Write-Host '    2) 点「Merge other mod」→ 选上面这个 .toml 文件（或路径框 Ctrl+V）'
        Write-Host '       （随机器会合并清单里列出的所有目录；冲突文件按清单顺序取第一个）'
        Write-Host '    3) 勾选敌人随机（Enemy Randomizer 页）等选项'
        Write-Host '    4) 点随机化；完成后关掉随机器，回本菜单按 [2] 启动'
    } else {
        Write-Host '  默认包路径（已复制到剪贴板）：' -ForegroundColor Green
        Write-Host ('  ' + $full)
        Write-Host ''
        Write-Host '  在随机器窗口里按下面做：' -ForegroundColor Yellow
        Write-Host '    1) 选好游戏 exe'
        Write-Host '    2) 点「Merge other mod」→ 选上面这个目录（或直接在路径框里 Ctrl+V）'
        Write-Host '    3) 勾选敌人随机（Enemy Randomizer 页）等选项'
        Write-Host '    4) 点随机化；完成后关掉随机器，回本菜单按 [2] 启动'
        Write-Host ''
        Write-Host '  想再合并别的 mod：主菜单 [7] 添加并打开「随机化合并」开关，再回 [4]。'
    }
    Write-Host ''
    Write-Host '  想换别的包：回主菜单按 [1]，再按 [4]。'
    if ($DryRun) {
        if ($mergeMods.Count -gt 0) {
            Write-Host ''
            Write-Host '  —— merge_mods.toml 预览 ——' -ForegroundColor Cyan
            Write-Host (New-MergeToml $full)
        }
        Write-Warn '[-DryRun] 不启动随机器。'
        return
    }
    Start-Process -FilePath $RandomExe -WorkingDirectory $RandomDir
    try { Start-Process -FilePath 'explorer.exe' -ArgumentList ('"' + $full + '"') } catch { }
}

# ---------------------------------------------------------------- 状态显示
function Show-Status {
    $packs = Get-Packs
    $rel = Get-DefaultRel $packs
    $latest = Get-LatestRandom
    Write-Host ('  可玩包数   : ' + $packs.Count)
    $gameRoot = Resolve-GameRoot
    if ($gameRoot) { Write-Host ('  游戏路径   : ' + $gameRoot) }
    else { Write-Host '  游戏路径   : （未设置 / 有多个候选，按 [6] 选择）' -ForegroundColor Yellow }
    if ($rel) { Write-Host ('  默认包     : ' + ($rel -replace '\\', ' / ')) } else { Write-Host '  默认包     : （未设置）' }
    $enabledExtras = @(@(Get-ExtraMods) | Where-Object { $_.enabled })
    if ($enabledExtras.Count -eq 0) {
        Write-Host '  其他 mod   : （未添加；主菜单 [7] 可叠加别的 mod）'
    } else {
        $lowCount = @($enabledExtras | Where-Object { $_.priority -ne 'high' }).Count
        $highCount = $enabledExtras.Count - $lowCount
        $mergeCount = @($enabledExtras | Where-Object { $_.merge }).Count
        $extraText = '  其他 mod   : ' + $enabledExtras.Count + ' 个启用（低 ' + $lowCount + ' / 高 ' + $highCount
        if ($mergeCount -gt 0) { $extraText += '；随机化合并 ' + $mergeCount + ' 个' }
        $extraText += '）'
        Write-Host $extraText
    }
    if (Get-SeamlessEnabled) {
        $sState = '开启'
        if (-not (Test-Path -LiteralPath $SeamlessDll)) { $sState = '开启（但 DLL 缺失！）' }
        Write-Host ('  Seamless   : ' + $sState + '（无缝联机，主菜单 [8] 切换）')
    } else {
        Write-Host '  Seamless   : 关闭（无缝联机，主菜单 [8] 切换）'
    }
    $saveShown = $SaveName
    if (Get-SeamlessEnabled) { $saveShown = $SaveName + '（联机：' + $SaveNameCoop + '）' }
    Write-Host ('  独立存档   : ' + $saveShown + '（本整合包独有，不和 法魂 等 .cnv 共用）')
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
        Write-Host ' [6] 设置游戏路径（自动检测 / 浏览选择，会记住）'
        Write-Host ' [7] 其他 mod（叠加别的 mod；含 regulation 的可随机化时合并）'
        Write-Host ' [8] Seamless Co-op 无缝联机 mod：开 / 关（固定集成）'
        Write-Host ' [0] 退出'
        Write-Host ' 直接回车 = [3] 启动无敌人随机（默认包）'
        Write-Host '=============================================================='
        $choice = Read-Host '请选择'
        if ($null -eq $choice) { return }   # 输入流结束（管道/非交互）时退出
        switch ($choice) {
            ''    { Invoke-Vanilla; Pause-Any }
            '1'   { [void](Select-Pack (Get-Packs)); Pause-Any }
            '2'   { Invoke-Rand; Pause-Any }
            '3'   { Invoke-Vanilla; Pause-Any }
            '4'   { Invoke-Randomizer; Pause-Any }
            '5'   { if (Select-Pack (Get-Packs)) { Invoke-Vanilla }; Pause-Any }
            '6'   { [void](Set-GameRootInteractive); Pause-Any }
            '7'   { Show-ExtraModsMenu }
            '8'   { Show-SeamlessMenu }
            '0'   { return }
            default { }
        }
    }
}

function Show-Help {
    Write-Host '用法：'
    Write-Host '  双击 启动_RNG_Lands_整合版.bat 打开菜单（推荐）'
    Write-Host '  主菜单 [1] 选默认包 → [3] 直接玩；[4] 随机化 → [2] 玩随机版'
    Write-Host '  主菜单 [8] 开关 Seamless Co-op（无缝联机；固定集成在 _mods\SeamlessCoop）'
    Write-Host ''
    Write-Host '命令行（调试用）：'
    Write-Host '  ... -Action list'
    Write-Host '  ... -Action select -Pack "Ruby\recommended increased difficulty"'
    Write-Host '  ... -Action vanilla -DryRun        （只打印将写入的配置）'
    Write-Host '  ... -Action rand -DryRun'
    Write-Host '  ... -Action vanilla -NoLaunch      （只写配置不启动）'
    Write-Host '  ... -Action setgame -GamePath "D:\ELDEN RING\Game"   （设置/修改游戏路径）'
    Write-Host '  ... -Action extlist                          （查看其他 mod 列表）'
    Write-Host '  ... -Action extadd -ModPath "D:\SomeMod"     （添加其他 mod）'
    Write-Host '  ... -Action exttoggle -Index 1               （启用/停用）'
    Write-Host '  ... -Action extpriority -Index 1             （切换低/高优先级）'
    Write-Host '  ... -Action extmerge -Index 1                （随机化合并开关）'
    Write-Host '  ... -Action extremove -Index 1               （删除）'
    Write-Host '  ... -Action seamlesson                       （开启 Seamless Co-op）'
    Write-Host '  ... -Action seamlessoff                      （关闭 Seamless Co-op）'
    Write-Host '  ... -Action seamless                         （查看/切换 Seamless 开关）'
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
        'extlist'    {
            Write-Head '其他 mod（附加加载）'
            $mods = @(Get-ExtraMods)
            if ($mods.Count -eq 0) { Write-Host '  （还没有添加任何 mod）' }
            $i = 0
            foreach ($m in $mods) {
                $i++
                $state = $(if ($m.enabled) { '启用' } else { '停用' })
                $prio = $(if ($m.priority -eq 'high') { '高' } else { '低' })
                $mergeTag = ''
                if ($m.merge) { $mergeTag = ' [随机化合并]' }
                Write-Host ('  ' + $i + '. [' + $state + '] 优先级:' + $prio + $mergeTag + '  ' + $m.name)
                Write-Host ('     ' + $m.path)
                Write-ExtraModNotes $m
            }
        }
        'extadd'     {
            if (-not $ModPath) { Write-Err '需要 -ModPath "<mod 目录>"'; exit 1 }
            if (-not (Add-ExtraMod $ModPath)) { exit 1 }
        }
        'extremove'   { if (-not (Update-ExtraMods 'remove' $Index)) { exit 1 } }
        'exttoggle'   { if (-not (Update-ExtraMods 'toggle' $Index)) { exit 1 } }
        'extpriority' { if (-not (Update-ExtraMods 'priority' $Index)) { exit 1 } }
        'extmerge'    { if (-not (Update-ExtraMods 'merge' $Index)) { exit 1 } }
        'setgame'    {
            if ($GamePath) {
                $root = Test-NormalizeGameRoot $GamePath
                if (-not $root) { Write-Err ('路径无效（需要包含 Game\eldenring.exe）：' + $GamePath); exit 1 }
                Save-GameRoot $root
            } else {
                [void](Set-GameRootInteractive)
            }
        }
        'rand'       { Invoke-Rand }
        'vanilla'    { Invoke-Vanilla }
        'randomizer' { Invoke-Randomizer }
        'seamless'   {
            if (Get-SeamlessEnabled) {
                Set-SeamlessEnabled $false
                Write-Ok 'Seamless Co-op 已关闭'
            } else {
                if (-not (Test-Path -LiteralPath $SeamlessDll)) { Write-Err ('找不到 DLL：' + $SeamlessDll); exit 1 }
                Set-SeamlessEnabled $true
                Write-Ok 'Seamless Co-op 已开启（下次启动游戏生效）'
            }
            Show-Status
        }
        'seamlesson' {
            if (-not (Test-Path -LiteralPath $SeamlessDll)) { Write-Err ('找不到 DLL：' + $SeamlessDll + '（先解压到 _mods\SeamlessCoop）'); exit 1 }
            Set-SeamlessEnabled $true
            Write-Ok 'Seamless Co-op 已开启（下次启动游戏生效）'
            Show-Status
        }
        'seamlessoff' { Set-SeamlessEnabled $false; Write-Ok 'Seamless Co-op 已关闭'; Show-Status }
        'help'       { Show-Help }
    }
} catch {
    Write-Err ('运行出错：' + $_.Exception.Message)
    Write-Host ('  位置：' + $_.InvocationInfo.PositionMessage) -ForegroundColor DarkGray
    exit 1
}
