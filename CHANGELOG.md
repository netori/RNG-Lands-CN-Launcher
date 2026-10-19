# Changelog / 更新日志

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
