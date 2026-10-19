; =====================================================================
;  RNG Lands（随机暗黑）整合启动器 · YAFSML 配置模板
;  ---------------------------------------------------------------------
;  这个文件是模板，启动器每次启动前会把 [dll] / [mod] 两段分别填进去，
;  生成真正的 yafsml\YAFSML.ini。要改通用设置请改本模板（不要改生成的 ini）。
;
;  [mod] 规则：后声明的 mod 覆盖先声明的 mod 的同名文件
;             （所以“随机器输出”永远放在最后）
; =====================================================================
game=eldenring


; 各游戏通用补丁
[patch]
skip_intro=1

; 阻止 mod 里的 regulation.bin 往存档写“已修改”标记
prevent_regulation_save_write=1

patch_mem=1
patch_mem_dedicated_heap=0
patch_mem_heap_size=0
boot_boost=1
disable_arxan=0

; 独立存档：ER0000.sl2 -> ER0000.cnv（原版存档完全隔离）
replace_save_filename=.cnv
replace_seamless_coop_save_filename=.cnv.co2

enable_ime=0


; 通用优化
[tweak]
cpu_affinity=0


; 日志（每次启动重写 yafsml\log\YAFSML.log）
[log]
console=0
log_file=1
log_level=info


; 游戏启动时加载的外部 DLL
; 条件：early / data_ready / delay,毫秒 / after,名字（互斥）；不写 = SteamAPI_Init 之后
[dll]
@DLL_LINES@
; Seamless Co-op（无缝联机）：主菜单 [8] 开关；开启时启动器会在这里写
;   seamlesscoop=<paly>\_mods\SeamlessCoop\ersc.dll
; 独立存档 dll（可选，默认不用）：本机 alt-saves.log 显示它在游戏 1.17 上 panic，
; 且独立存档已由上面的 replace_save_filename=.cnv 实现。要试就删掉行首分号：
;eldenring_alt_saves=dll\eldenring_alt_saves.dll


; 扫描并覆盖游戏数据的 mod 目录（后声明覆盖先声明）
[mod]
@MOD_LINES@
