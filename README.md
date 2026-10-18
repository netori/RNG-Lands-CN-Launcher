# RNG Lands 整合启动器（YAFSML 注入）

把 **RNG Lands（随机暗黑）的多个变体包** 与 **Elden Ring Randomizer 的随机化输出** 用
YAFSML 注入式加载器统一起启动的小工具：

- 想玩哪个包就选哪个包（支持 16 个变体 × 2 难度，共 32 个包）；
- 启动分两种模式：**有敌人随机**（叠随机器输出）和 **无敌人随机**（直接玩原包）；
- 默认包会记住，双击 → 回车即可玩；
- **游戏路径不用手填**：首次自动检测（Steam 库 / 整合包附近 / 常见目录），
  找不到或想换时用菜单 `[6]` 选择，结果保存在 `_launcher\game_path.txt`；
- YAFSML 是运行时注入，**游戏目录一个文件都不会改**；
- 独立存档：`ER0000.sl2` → `ER0000.cnv`（和原版存档天然隔离）。

> 本仓库 **只包含启动脚本**，不包含任何游戏本体 / mod / 补丁文件。
> 你需要自己准备：Elden Ring 1.17.x、RNG Lands 0.7.2 的包、本项目的汉化补丁、
> EldenRingRandomizer v0.12.2、YAFSML。

---

## 依赖

| 组件 | 说明 |
|---|---|
| Elden Ring 1.17.x | 需要能免 EAC 启动（ModEngine / me3 等常规方式） |
| RNG Lands 0.7.2 | Nexus mod 3229：Ruby / Apache / Pack 10（14 配置）× recommended・vanilla 难度 |
| [RNG Lands 简体中文补丁](https://github.com/netori/RNG-Lands-CN) | 放进各包目录的 `msg/zhocn/`（本启动器直接兼容） |
| EldenRingRandomizer v0.12.2 | 放在 `randomizer\`，随机化输出也写在这里 |
| YAFSML v0.10.4+ | 放在 `yafsml\`（`YAFSML.exe` / `YAFSML.dll` / `YAFSML.ini`） |

目录结构见 [`示例_目录结构.txt`](示例_目录结构.txt)。

## 用法

双击 **`启动_RNG_Lands_整合版.bat`**：

```
 [1] 选择默认包（32 个里挑，记住）
 [2] 启动 · 有敌人随机（最近一次随机化输出 + 它合并的那个包）
 [3] 启动 · 无敌人随机（直接玩默认包，不经过随机器）
 [4] 打开随机器（默认包路径复制到剪贴板）
 [5] 先换默认包，再启动无随机版
 [6] 设置游戏路径（自动检测 / 浏览选择，会记住）
 [0] 退出；直接回车 = [3]
```

### 做「有敌人随机」的流程

1. `[1]` 选要玩的包；
2. `[4]` 打开随机器：GUI 里 **Merge other mod → 选剪贴板里那个目录**，勾选敌人随机，点随机化；
3. 随机化完成后回菜单按 `[2]` 启动 —— 启动器会自动读最新 `spoiler_logs` 里的
   `Checking other mod directory`，**上次合并哪个包就叠哪个包**。


### 游戏路径（第一次启动选一次）

启动器不再写死路径，查找顺序：

1. `_launcher\game_path.txt`（上次选择/自动检测后保存）；
2. 自动检测：Steam 库（读注册表 + `libraryfolders.vdf`）、**本整合包附近的 `ELDEN RING*` 目录**、常见安装目录；
3. 仍找不到（或找到多个）→ 启动时会弹出设置界面。

手动换：主菜单 `[6]` → 选候选序号 / `F` 浏览文件夹 / `E` 直接选 `eldenring.exe` / `A` 重新检测 / `Q` 取消。
选 `Game` 文件夹、`eldenring.exe` 或版本根目录都可以，会自动换算成版本根目录并保存。

> 换电脑、移动游戏目录后按 `[6]` 重选一次即可；删掉 `_launcher\game_path.txt` 会重新自动检测。

## 实现要点

- `_launcher\rng_lands_launcher.ps1`：菜单、包扫描、默认包记录、读随机器日志、生成 ini、启动。
- `_launcher\YAFSML.ini.tpl`：YAFSML 配置模板，`@MOD_LINES@` / `@DLL_LINES@` 每次启动前填充。
- 两种模式的 `[mod]`：
  - 有敌人随机：`RNG_Lands_Base=<来源包>` + `RNG_Lands_Randomizer=<randomizer>`（后者最后声明、优先级最高）
  - 无敌人随机：只有 `RNG_Lands_Base=<默认包>`
- 有随机模式会给 `RandomizerCrashFix.dll` 配 `|early`（基础+DLC 敌人一起随机时防崩溃）。
- 独立存档/不写 regulation 标记：`replace_save_filename=.cnv` + `prevent_regulation_save_write=1`。

## 排障

- 日志：`yafsml\log\YAFSML.log`（每次启动重写）。健康的样子应包含
  `INFO: [mod] added mod RNG_Lands_Base ...`（有随机模式还有 `RNG_Lands_Randomizer`）。
- 游戏没启动：**不要用管理员身份运行**；游戏路径可用菜单 `[6]` 重新检测/选择。
- 敌人刷出时崩溃：把 `_launcher\YAFSML.ini.tpl` 里 `randomizer_crashfix=...|early` 改成不带 `|early`。
- 更多见 [`启动说明_RNG_Lands_整合版.md`](启动说明_RNG_Lands_整合版.md)。

## 授权 / 声明

- 脚本以 **MIT** 发布（见 [LICENSE](LICENSE)）。
- 本仓库不含任何游戏、mod、补丁文件；RNG Lands © 其作者，Elden Ring © FromSoftware / Bandai Namco。
- 与 FromSoftware、Bandai Namco、RNG Lands 作者、YAFSML / Randomizer 作者均无隶属关系。
