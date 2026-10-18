# RNG Lands（随机暗黑）整合包 · 启动说明

## 这个文件夹是什么

`RNG LANDS paly\` 是一个**整合启动包**：

- `RNG Lands\` —— 16 个已打汉化补丁的 RNG Lands 0.7.2 变体 × 2 种难度 = **32 个可玩包**
  （Ruby / Apache / Pack 10 的 14 个配置；每个都有 `recommended increased difficulty` 与 `vanilla difficulty`）
- `randomizer\` —— EldenRingRandomizer v0.12.2 工作目录，**随机化输出也写在这里**
- `yafsml\` —— YAFSML 注入式加载器（不改游戏目录一个文件）
- `_launcher\` —— 启动器逻辑、配置模板、默认包记录

## 怎么启动

双击 **`启动_RNG_Lands_整合版.bat`**，出现菜单：

| 选项 | 作用 |
|---|---|
| `[1]` | 选择默认包（列表里挑，会记住） |
| `[2]` | **有敌人随机**：用最近一次随机化输出 + 它当时合并的那个包 |
| `[3]` | **无敌人随机**：直接玩默认包（不经过随机器） |
| `[4]` | 打开随机器，并把默认包路径**复制到剪贴板** |
| `[5]` | 先换包，再启动无随机版 |
| `回车` | 直接启动无随机版（默认包） |

旧的 `启动_RNG_Lands_随机_YAFSML.bat` 保留为「直接启动有敌人随机版」快捷方式。

## 想做「有敌人随机」的流程（推荐）

1. 菜单按 `[1]` 选你要玩的包（比如 `Pack 10 / golden targeted 1 / recommended increased difficulty`）。
2. 菜单按 `[4]`：随机器打开，包路径已在剪贴板。
   在随机器里：**Merge other mod → 选这个目录**（路径框里 Ctrl+V 也行）；
   **勾选敌人随机**；点随机化。
3. 随机化完成、关掉随机器，回菜单按 `[2]` 启动。
   - 启动器会自动读取 `randomizer\spoiler_logs` 里**最新一次日志**，用它记录的
     `Checking other mod directory` 路径作为叠加包 —— 所以**你上次合并的是哪个包，它就叠哪个包**，不会叠错。
   - 如果最新日志里没有 `enemy` 选项，会提示这版不是“有敌人随机”。

## 换包以后

- 只是换「无随机版」玩：`[1]` 选新包 → `[3]`。
- 「有随机版」永远跟着**最近一次随机化**走：重新随机化（[4]）之后按 `[2]` 即可。

## 存档

- 独立存档：`%APPDATA%\EldenRing\<SteamID>\ER0000.cnv`
- 原版存档：同目录 `ER0000.sl2` —— 两边隔离，互不覆盖
- 机制：`replace_save_filename=.cnv` + `prevent_regulation_save_write=1`

## 日志 / 排障

- YAFSML 日志：`yafsml\log\YAFSML.log`（每次启动重写）
  健康的样子包含：
  ```
  INFO: [mod] added mod RNG_Lands_Base from `...\RNG Lands\Ruby\recommended increased difficulty`
  INFO: [extdll] loaded external DLL randomizer_crashfix from `..\randomizer\dll\RandomizerCrashFix.dll`
  ```
  并把 `request=regulation:` 指到随机化输出的 `regulation.bin`。
- 进游戏没变化：确认日志里 `[mod] added mod` 是哪个路径；无随机版应只有 `RNG_Lands_Base` 一行。
- 游戏没启动：看日志；确认**不要用管理员身份运行**、游戏路径没变（启动器里 `$ErRoot`）。
- 敌人刷出时崩溃：把 `_launcher\YAFSML.ini.tpl` 里 `randomizer_crashfix=...|early` 改成不带 `|early`，
  或注释掉那一行（模板是唯一来源，生成的 ini 不用手改）。

## 高级

- 配置模板：`_launcher\YAFSML.ini.tpl`（`@MOD_LINES@` / `@DLL_LINES@` 由启动器填充）。
- 默认包记录：`_launcher\default_pack.txt`（一行相对路径）。
- 命令行调试：
  ```
  powershell -NoProfile -ExecutionPolicy Bypass -File _launcher\rng_lands_launcher.ps1 -Action list
  powershell ... -Action vanilla -DryRun      # 只打印将写入的配置
  powershell ... -Action rand -DryRun
  powershell ... -Action vanilla -NoLaunch    # 只写配置不启动
  ```
