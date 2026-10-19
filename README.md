# RNG Lands 整合启动器（YAFSML 注入）

把 **RNG Lands（随机暗黑）的多个变体包** 与 **Elden Ring Randomizer 的随机化输出** 用
YAFSML 注入式加载器统一起启动的小工具：

- 想玩哪个包就选哪个包（支持 16 个变体 × 2 难度，共 32 个包）；
- 启动分两种模式：**有敌人随机**（叠随机器输出）和 **无敌人随机**（直接玩原包）；
- 默认包会记住，双击 → 回车即可玩；
- **可以叠加其他 mod**：菜单 `[7]` 添加任意 mod 目录（低 / 高优先级），勾选「随机化合并」后
  `[4]` 打开的随机器会生成一份合并清单（Mod Engine toml），把附加 mod 和 RNG Lands 包一起合并；
- **内置 Seamless Co-op 无缝联机开关**：菜单 `[8]` 开 / 关（v2.0.1，文件放 `_mods\SeamlessCoop\`，
  开时由 YAFSML 加载 `ersc.dll`，联机存档 `ER0000.cnv.co2` 与单机隔离；本仓库不附带二进制）；
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
| Seamless Co-op v2.0.1（可选） | Nexus mod 510：解压到 `_mods\SeamlessCoop\`；本仓库不附带二进制，用菜单 `[8]` 开关 |

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
 [7] 其他 mod（叠加别的 mod；含 regulation 的可随机化时合并）
 [8] Seamless Co-op 无缝联机 mod：开 / 关（固定集成）
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

### 叠加其他 mod（菜单 `[7]`）

除了 RNG Lands 包，还可以再叠别的 mod（贴图、武器、骨灰、UI 等）。菜单 `[7]`：

```
 [A] 添加 mod（粘贴/浏览 mod 目录，自动识别其中真正的 mod 根）
 [E] 启用 / 停用
 [P] 切换优先级：低（被 RNG Lands 包覆盖） / 高（覆盖 RNG Lands 包和随机结果）
 [M] 切换「随机化时合并」（只有开着的 mod 才会进合并清单）
 [U]/[D] 上移 / 下移（同类里的先后，后声明的覆盖先声明的）
 [R] 删除    [Q] 返回
```

两种玩法：

- **只叠加、不随机**：把 mod 的优先级设成「低」（贴图/UI 之类通常够了），直接 `[3]` 启动。
  `[mod]` 顺序：低优先级 mod → `RNG_Lands_Base` → 高优先级 mod。
- **和随机化一起合并**：给 mod 打开 `[M]`，按 `[4]` 打开随机器 —— 启动器会生成
  `_launcher\merge_mods.toml` 并把它的路径复制到剪贴板；在随机器里 **Merge other mod → 选这个 .toml**。
  合并顺序（先声明者优先）：高优先级 mod → `RNG_Lands_Base` → 低优先级 mod。

注意事项：

- 含 `regulation.bin` 的 mod 与 RNG Lands 的 `regulation.bin` **天然冲突**：设为低优先级会被覆盖，
  设为高优先级又会盖掉 RNG Lands 的改动（菜单里会显示红/黄提示）；
- 随机器只能合并「文件级可合并」的 mod，部分 mod（改 param 之外的二进制/脚本）合并后可能无效或被跳过 ——
  以随机化日志与游戏内实际效果为准；
- 想要「有敌人随机 + 其他 mod」，先确认随机器那次随机化是**用带 merge 清单的方式**做的，再按 `[2]` 启动。

### Seamless Co-op 无缝联机（菜单 `[8]`）

启动器把 Seamless Co-op v2.0.1 作为**固定集成的可选 mod**：默认关闭，菜单 `[8]` 开 / 关，
只有开着的时候才把 `ersc.dll` 写进 YAFSML 的 `[dll]`。

一次性安装：

1. 下载 Seamless Co-op v2.0.1（Nexus mod 510）；
2. 把压缩包里 `SeamlessCoop\` 文件夹**里面的内容**解压到 `_mods\SeamlessCoop\`
   （形成 `_mods\SeamlessCoop\ersc.dll`、`ersc_settings.ini`、`locale\`、`crashpad\`）；
3. 主菜单 `[8]` → `[1]` 开启。启动游戏时日志应出现
   `[extdll] loaded external DLL seamlesscoop`。

注意：

- **存档**：开启后联机存档是 `ER0000.cnv.co2`（与单机 `ER0000.cnv` 分开）；
- **密码**：改 `_mods\SeamlessCoop\ersc_settings.ini` 里的 `cooppassword`，队友填同一个；
- **版本**：联机双方的游戏版本、Seamless 版本必须一致；
- 与随机化 / 其他 mod 叠加属于附加组合，稳定性不保证：联机异常时先 `[8]` 关掉它，单机复现问题；
- 换 Seamless 版本：直接替换 `_mods\SeamlessCoop\` 里的文件，开关状态不用动。

## 实现要点

- `_launcher\rng_lands_launcher.ps1`：菜单、包扫描、默认包记录、读随机器日志、生成 ini、启动。
- `_launcher\YAFSML.ini.tpl`：YAFSML 配置模板，`@MOD_LINES@` / `@DLL_LINES@` 每次启动前填充。
- 两种模式的 `[mod]`：
  - 有敌人随机：`RNG_Lands_Base=<来源包>` + `RNG_Lands_Randomizer=<randomizer>`（后者最后声明、优先级最高）
  - 无敌人随机：只有 `RNG_Lands_Base=<默认包>`
- 附加 mod（菜单 `[7]` 维护 `_launcher\extra_mods.json`）会插进 `[mod]`：
  低优先级在基础包**之前**、高优先级在最后；随机化合并清单 `_launcher\merge_mods.toml`
  是高优先级 mod → `RNG_Lands_Base` → 低优先级 mod（first-wins）。
- 有随机模式会给 `RandomizerCrashFix.dll` 配 `|early`（基础+DLC 敌人一起随机时防崩溃）。
- Seamless Co-op（菜单 `[8]`）开启时往 `[dll]` 追加 `seamlesscoop=<绝对路径>\ersc.dll`（不写加载条件），
  状态记在 `_launcher\seamless_enabled.txt`；关闭时这一行完全不出现。
- 独立存档/不写 regulation 标记：`replace_save_filename=.cnv` + `prevent_regulation_save_write=1`。

## 排障

- 日志：`yafsml\log\YAFSML.log`（每次启动重写）。健康的样子应包含
  `INFO: [mod] added mod RNG_Lands_Base ...`（有随机模式还有 `RNG_Lands_Randomizer`）。
- 游戏没启动：**不要用管理员身份运行**；游戏路径可用菜单 `[6]` 重新检测/选择。
- 敌人刷出时崩溃：把 `_launcher\YAFSML.ini.tpl` 里 `randomizer_crashfix=...|early` 改成不带 `|early`。
- 附加 mod 没生效：看 `yafsml\log\YAFSML.log` 里有没有 `Extra_low_*` / `Extra_high_*` 的 `[mod] added mod` 行；
  再确认优先级：低优先级会被 RNG Lands 包同名文件覆盖。
- Seamless 联机没反应 / 没加载：看 `yafsml\log\YAFSML.log` 里有没有 `[extdll] loaded external DLL seamlesscoop`；
  没有就检查 `_mods\SeamlessCoop\ersc.dll` 是否存在、菜单 `[8]` 是否开启；还是不行先 `[8]` 关掉确认单机正常。
- 更多见 [`启动说明_RNG_Lands_整合版.md`](启动说明_RNG_Lands_整合版.md)。

## 授权 / 声明

- 脚本以 **MIT** 发布（见 [LICENSE](LICENSE)）。
- 本仓库不含任何游戏、mod、补丁文件（Seamless Co-op 也一样：只做开关，二进制请自行从其发布页下载）；
  RNG Lands © 其作者，Seamless Co-op © LukeYui，Elden Ring © FromSoftware / Bandai Namco。
- 与 FromSoftware、Bandai Namco、RNG Lands 作者、YAFSML / Randomizer 作者均无隶属关系。
