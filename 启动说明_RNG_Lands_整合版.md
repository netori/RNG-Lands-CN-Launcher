# RNG Lands（随机暗黑）整合包 · 启动说明

## 这个文件夹是什么

`RNG LANDS paly\` 是一个**整合启动包**：

- `RNG Lands\` —— 16 个已打汉化补丁的 RNG Lands 0.7.2 变体 × 2 种难度 = **32 个可玩包**
  （Ruby / Apache / Pack 10 的 14 个配置；每个都有 `recommended increased difficulty` 与 `vanilla difficulty`）
- `randomizer\` —— EldenRingRandomizer v0.12.2 工作目录，**随机化输出也写在这里**
- `yafsml\` —— YAFSML 注入式加载器（不改游戏目录一个文件）
- `_launcher\` —— 启动器逻辑、配置模板、默认包记录（`extra_mods.json` / `merge_mods.toml` 会自动生成）
- `_mods\SeamlessCoop\` —— Seamless Co-op（可选，固定集成；菜单 `[8]` 开关，需自己解压一次）

## 怎么启动

双击 **`启动_RNG_Lands_整合版.bat`**，出现菜单：

| 选项 | 作用 |
|---|---|
| `[1]` | 选择默认包（列表里挑，会记住） |
| `[2]` | **有敌人随机**：用最近一次随机化输出 + 它当时合并的那个包 |
| `[3]` | **无敌人随机**：直接玩默认包（不经过随机器） |
| `[4]` | 打开随机器，并把默认包路径**复制到剪贴板** |
| `[5]` | 先换包，再启动无随机版 |
| `[6]` | **设置游戏路径**（自动检测 / 浏览选择，会记住） |
| `[7]` | **其他 mod**：叠加别的 mod（低 / 高优先级；可勾选随机化时合并） |
| `[8]` | **Seamless Co-op**：无缝联机开关（固定集成，文件在 `_mods\SeamlessCoop\`） |
| `回车` | 直接启动无随机版（默认包） |

旧的 `启动_RNG_Lands_随机_YAFSML.bat` 保留为「直接启动有敌人随机版」快捷方式。


## 游戏路径（第一次启动选一次，不用手改文件）

启动器**不再写死游戏路径**，按下面顺序找游戏：

1. 读 `_launcher\game_path.txt`（你上次选择/自动检测后保存的路径）；
2. 自动检测：Steam 库（`steamapps\common\ELDEN RING`）、**整合包附近**的 `ELDEN RING*` 目录、常见安装目录；
3. 都找不到（或找到多个）时，启动时会弹出「设置游戏路径」界面。

手动更换：主菜单按 **`[6]`**，可以：
- 输入候选序号（自动检测到的列表）；
- `F` 浏览文件夹（选**包含 `Game\eldenring.exe` 的那层**，或直接选 `Game` 文件夹也行）；
- `E` 直接选中 `eldenring.exe`；
- `A` 重新自动检测；`Q` 取消。

> 选什么都会被自动换算成「版本根目录」（含 `Game` 子目录的那层），并保存到
> `_launcher\game_path.txt`。换电脑 / 移动了游戏之后，重新按 `[6]` 选一次即可。

## 想做「有敌人随机」的流程（推荐）

1. 菜单按 `[1]` 选你要玩的包（比如 `Pack 10 / golden targeted 1 / recommended increased difficulty`）。
2. 菜单按 `[4]`：随机器打开，包路径已在剪贴板。
   在随机器里：**Merge other mod → 选这个目录**（路径框里 Ctrl+V 也行）；
   **勾选敌人随机**；点随机化。
3. 随机化完成、关掉随机器，回菜单按 `[2]` 启动。
   - 启动器会自动读取 `randomizer\spoiler_logs` 里**最新一次日志**，用它记录的
     `Checking other mod directory` 路径作为叠加包 —— 所以**你上次合并的是哪个包，它就叠哪个包**，不会叠错。
   - 如果最新日志里没有 `enemy` 选项，会提示这版不是“有敌人随机”。

## 叠加其他 mod（可选，菜单 `[7]`）

想再叠别的 mod（贴图、武器、骨灰、UI 等）时用它：

1. 主菜单按 `[7]`；
2. 按 `[A]` 添加：粘贴 mod 目录路径（或按 `B` 浏览）。可以选 mod 文件夹本身、它的上一层、
   或带 `mod` 子目录的包装目录 —— 启动器会自动找到里面真正的 mod 根，并给个名字；
3. `[P]` 选优先级：
   - **低**（默认给带 `regulation.bin` 的 mod）：被 RNG Lands 包同名文件覆盖 —— 适合贴图/UI；
   - **高**（默认给不带 `regulation.bin` 的 mod）：覆盖 RNG Lands 包 —— 适合要抢占的小改动；
4. `[M]` 勾选「随机化时合并」（想和敌人随机一起用时打开），`[E]` 启用/停用，`[U]/[D]` 调先后，`[R]` 删除；
5. 返回主菜单，按 `[3]`（无随机）或先 `[4]`（有随机）即可。

**有随机时怎么合并**：菜单 `[7]` 里给 mod 打开 `[M]` 后，按 `[4]` 打开随机器 —— 启动器会生成
`_launcher\merge_mods.toml`，路径已复制到剪贴板；在随机器里 **Merge other mod → 选这个 .toml**，
再勾敌人随机、点随机化。合并顺序（冲突文件取先声明的）：高优先级 mod → RNG Lands 包 → 低优先级 mod。

> 含 `regulation.bin` 的 mod 和 RNG Lands 的 `regulation.bin` 天然冲突（低优先级会被覆盖、高优先级会盖掉
> RNG Lands 的改动，菜单里会提示）；随机器也只能合并文件级可合并的 mod，部分 mod 合并后可能无效，
> 以随机化日志和游戏内实际效果为准。

## Seamless Co-op 无缝联机（可选，菜单 `[8]`）

Seamless Co-op 是「固定集成」的：文件固定放 `_mods\SeamlessCoop\`，默认关闭，菜单 `[8]` 开 / 关。

一次性安装：

1. Nexus mod 510 下载 Seamless Co-op v2.0.1；
2. 解压压缩包里 `SeamlessCoop\` 文件夹**里面的内容**到 `_mods\SeamlessCoop\`
   （形成 `_mods\SeamlessCoop\ersc.dll`、`ersc_settings.ini`、`locale\`、`crashpad\`）；
3. 主菜单 `[8]` → `[P]` 设置**联机密码**（队友要用同一个；不设置会报
   `Fatal Error: Please enter a session password`）；
4. 主菜单 `[8]` → `[1]` 开启（之后每次启动都会加载；关掉就完全不加载）。

注意：

- 联机存档 `ER0000.rnglands.co2`，与单机 `ER0000.rnglands` 分开；
- 必须设置 `cooppassword`（菜单 `[8]` → `[P]`，或改 `_mods\SeamlessCoop\ersc_settings.ini`），队友要一样；
  为空时启动器会拒绝启动，免得进游戏才弹 Fatal Error；
- 双方游戏版本 + Seamless 版本必须一致；
- 和随机 / 其他 mod 一起用属于附加组合，出问题先 `[8]` 关掉再单机排查。

## 换包以后

- 只是换「无随机版」玩：`[1]` 选新包 → `[3]`。
- 「有随机版」永远跟着**最近一次随机化**走：重新随机化（[4]）之后按 `[2]` 即可。

## 存档

- 独立存档（本整合包独有）：`%APPDATA%\EldenRing\<SteamID>\ER0000.rnglands`
  （v1.4.0 起；以前是 `ER0000.cnv`，和 法魂 mod 的独立存档同名会串档）
- 开了 Seamless Co-op（菜单 `[8]`）时联机存档：同目录 `ER0000.rnglands.co2`
- 原版存档：同目录 `ER0000.sl2` —— 两边隔离，互不覆盖
- 机制：`replace_save_filename=.rnglands` + `replace_seamless_coop_save_filename=.rnglands.co2`
  + `prevent_regulation_save_write=1`
- **旧存档 `ER0000.cnv` 不会被删改**；想沿用旧进度：退出游戏后把 `ER0000.cnv` 复制/改名为
  `ER0000.rnglands`（那份文件可能同时被 法魂 用过，自己确认进度对不对）

## 日志 / 排障

- YAFSML 日志：`yafsml\log\YAFSML.log`（每次启动重写）
  健康的样子包含：
  ```
  INFO: [mod] added mod RNG_Lands_Base from `...\RNG Lands\Ruby\recommended increased difficulty`
  INFO: [extdll] loaded external DLL randomizer_crashfix from `..\randomizer\dll\RandomizerCrashFix.dll`
  INFO: [extdll] loaded external DLL seamlesscoop from `...\_mods\SeamlessCoop\ersc.dll`   （[8] 开启时才有）
  ```
  并把 `request=regulation:` 指到随机化输出的 `regulation.bin`。
- 进游戏没变化：确认日志里 `[mod] added mod` 是哪个路径；无随机版应只有 `RNG_Lands_Base` 一行。
- Seamless 弹 `Fatal Error: Please enter a session password`：联机密码为空 → 菜单 `[8]` → `[P]` 设置。
- 游戏没启动：看日志；确认**不要用管理员身份运行**、游戏路径正确（菜单 `[6]` 可以重新选/自动检测）。
- 敌人刷出时崩溃：把 `_launcher\YAFSML.ini.tpl` 里 `randomizer_crashfix=...|early` 改成不带 `|early`，
  或注释掉那一行（模板是唯一来源，生成的 ini 不用手改）。

## 高级

- 配置模板：`_launcher\YAFSML.ini.tpl`（`@MOD_LINES@` / `@DLL_LINES@` 由启动器填充）。
- 默认包记录：`_launcher\default_pack.txt`（一行相对路径）。
- 其他 mod 列表：`_launcher\extra_mods.json`（菜单 `[7]` 自动维护，JSON）；
  随机化合并清单：`_launcher\merge_mods.toml`（按 `[4]` 时自动生成，Mod Engine 格式）。
- 游戏路径记录：`_launcher\game_path.txt`（一行绝对路径；删掉就会重新自动检测）。
- Seamless 开关：`_launcher\seamless_enabled.txt`（`1` 开 / `0` 关；删掉 = 关闭）；
  Seamless 本体：`_mods\SeamlessCoop\`（`ersc.dll` + `ersc_settings.ini` + `locale\` + `crashpad\`）。
- 命令行调试：
  ```
  powershell -NoProfile -ExecutionPolicy Bypass -File _launcher\rng_lands_launcher.ps1 -Action list
  powershell ... -Action vanilla -DryRun      # 只打印将写入的配置
  powershell ... -Action rand -DryRun
  powershell ... -Action vanilla -NoLaunch    # 只写配置不启动
  powershell ... -Action setgame -GamePath "D:\ELDEN RING\Game"   # 设置游戏路径
  powershell ... -Action extlist                  # 查看已添加的其他 mod
  powershell ... -Action extadd -ModPath "D:\mods\SomeMod"   # 添加其他 mod
  powershell ... -Action exttoggle -Index 1       # 启用/停用第 1 个
  powershell ... -Action extpriority -Index 1     # 切换低/高优先级
  powershell ... -Action extmerge -Index 1        # 切换随机化时合并
  powershell ... -Action extremove -Index 1       # 删除第 1 个
  powershell ... -Action seamlesson               # 开启 Seamless Co-op
  powershell ... -Action seamlessoff              # 关闭 Seamless Co-op
  powershell ... -Action seamless                 # 切换开/关并显示状态
  ```
