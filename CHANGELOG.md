# Changelog / 更新日志

## [1.4.1] - 2026-10-21

- **修 Seamless Co-op 的 `Fatal Error: Please enter a session password`**：这个 mod 要求
  `_mods\SeamlessCoop\ersc_settings.ini` 里 `[PASSWORD]` 的 `cooppassword` 不能为空，
  否则一进游戏就直接弹 Fatal Error 退出。
  - 菜单 `[8]` 新增 `[P] 设置联机密码`（写进 `ersc_settings.ini`，队友要用同一个）；
  - 密码为空时启动器**直接拒绝启动**并给出设置指引，不再等到游戏里才报错；
  - 新增命令行 `-Action seamlesspass -Password "你的密码"`；
  - 状态栏 / Seamless 子菜单显示密码是否已设置。

## [1.4.0] - 2026-10-19

- **独立存档改成整合包独有，不再和 法魂 mod 串档**：存档扩展名从 `.cnv` 改成 `.rnglands`
  （`ER0000.sl2` → `ER0000.rnglands`），Seamless Co-op 联机存档同步改成 `ER0000.rnglands.co2`。
  - 原因：`法魂mod`（以及其它一些整合包）也用 `replace_save_filename=.cnv`，两个 mod 共用
    `ER0000.cnv`，来回切换会看到同一份角色/进度。
  - 旧的 `ER0000.cnv` 不会被删除或修改；本整合包从 `ER0000.rnglands` 重新开始。
  - 想沿用旧进度：手动把 `ER0000.cnv` 复制/改名为 `ER0000.rnglands`
    （注意旧文件可能混着其它 mod 的进度）。
  - 启动时若只有旧 `.cnv`、还没有 `.rnglands`，会打印提醒；状态栏（含 `-Action list`）显示当前存档名。
  - 主菜单 Seamless 说明、启动提示、README / 启动说明同步更新。

## [1.3.0] - 2026-10-19

- **固定集成 Seamless Co-op v2.0.1（无缝联机）**：菜单 `[8]` 开 / 关，默认关闭。
  - 文件固定放 `_mods\SeamlessCoop\`（`ersc.dll` + `ersc_settings.ini` + `locale\` + `crashpad\`），
    YAFSML 用绝对路径加载；关闭时 `[dll]` 里完全不出现。
  - 开启后联机存档为 `ER0000.cnv.co2`（与单机 `ER0000.cnv` 分开），启动时会打印当前联机状态与存档路径。
  - 菜单 `[8]` 显示版本 / DLL 是否存在 / 配置路径，并提供 `[1]` 开 `[2]` 关；
    `-Action seamlesson / seamlessoff / seamless` 可在命令行开关。
  - 状态记在 `_launcher\seamless_enabled.txt`（`1` 开 / `0` 关）；只影响加载，不复制/改动游戏目录。
  - 本仓库不附带 Seamless Co-op 二进制，安装方式见 README / 启动说明。
- 路径检查（`-DryRun`）现在也检查 `[dll]` 里 DLL 是否存在（去掉 `|early` 等条件后再解析相对路径）。

## [1.2.0] - 2026-10-19

- **新增「其他 mod」功能**：菜单 `[7]` 可以叠加任意 mod 目录（自动识别 mod 根，支持
  `<目录>\mod` 包装）。每个 mod 可设：
  - 启用 / 停用；
  - 低 / 高优先级（低 = 被 RNG Lands 包覆盖，高 = 覆盖 RNG Lands 包）；
  - 是否「随机化时合并」；
  - 上下移动（同类内先后）。
- `[mod]` 顺序：低优先级 mod → `RNG_Lands_Base` → 高优先级 mod（有随机模式再叠 `RNG_Lands_Randomizer`）。
- 勾选了「随机化时合并」的 mod，在按 `[4]` 打开随机器时会生成 `_launcher\merge_mods.toml`
  （Mod Engine 格式，顺序：高优先级 mod → RNG_Lands_Base → 低优先级 mod，冲突取先声明者），
  路径自动复制到剪贴板，可直接在随机器里 **Merge other mod → 选这个 .toml**。
- 菜单 `[7]` 内置风险提示（含 `regulation.bin` 的 mod 与 RNG Lands 冲突、高优先级会覆盖改动等）。
- 命令行新增 `-Action extlist / extadd / extremove / exttoggle / extpriority / extmerge`。

## [1.1.0] - 2026-10-18

- **游戏路径不再写死**。首次启动自动检测（Steam 库 / 整合包附近 / 常见安装目录），
  检测不到或想更换时用菜单 `[6]` 选择（自动候选 / 浏览文件夹 / 直接选 `eldenring.exe`），
  选择结果保存到 `_launcher\game_path.txt`；启动前会校验 `Game\eldenring.exe` 是否存在，
  无效会提示重新选择。
- 命令行新增 `-Action setgame -GamePath "<路径>"`，便于脚本设置。

## [1.0.0] - 2026-10-18

- 首个版本：32 个 RNG Lands 包选择、有敌人随机 / 无敌人随机双模式、YAFSML 注入、
  独立存档（`ER0000.cnv`）、默认包记忆。
