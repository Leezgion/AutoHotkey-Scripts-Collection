; =================================================
; 📁 ScriptManager.ahk - AutoHotkey 脚本集中管理工具
; =================================================
; 版本: 2.0 (模块化版本)
; 作者: AutoHotkey User
; 描述: 统一管理所有 AHK 脚本的启停、自启动设置
; =================================================
#Requires AutoHotkey v2.0
#SingleInstance Force

; -------------------------------------------------
; 🔧 全局配置
; -------------------------------------------------
global ScriptFolder := A_ScriptDir                    ; 脚本所在目录
global ExcludedScripts := [                           ; 排除列表
    "ScriptManager.ahk",                              ; 排除自身
]
global ScriptList := []                               ; 脚本列表
global ScriptMenu := ""                               ; 脚本控制子菜单
global StartupMenu := ""                              ; 自启动子菜单
global PinnedWindowsMenu := ""                        ; 置顶窗口子菜单
global ScreenshotMenu := ""                           ; 截图悬浮子菜单

; -------------------------------------------------
; 📦 加载模块
; -------------------------------------------------
#Include "%A_ScriptDir%\Lib\Utils.ahk"
#Include "%A_ScriptDir%\Lib\ScriptCore.ahk"
#Include "%A_ScriptDir%\Lib\AutoStart.ahk"
#Include "%A_ScriptDir%\Lib\TrayMenu.ahk"

; -------------------------------------------------
; 🚀 初始化
; -------------------------------------------------
Initialize()

Initialize() {
    ; 设置托盘图标
    TraySetIcon("shell32.dll", 13)  ; 齿轮图标
    ; 其他可选图标:
    ;   shell32.dll, 13  - 齿轮
    ;   shell32.dll, 44  - 图钉
    ;   shell32.dll, 167 - 控制面板
    ;   shell32.dll, 319 - 小程序
    ;   imageres.dll, 109 - 设置齿轮
    ;   imageres.dll, 150 - 文件夹齿轮

    ; 设置托盘图标提示
    A_IconTip := "📜 AHK 脚本管理器"

    ; 扫描脚本
    ScanScripts()

    ; 初始化托盘菜单
    SetupTrayMenu()

    ; 设置定时刷新 (每 5 秒)
    SetTimer(RefreshStatus, 5000)

    ; 显示启动通知
    ShowNotification("🚀 脚本管理器", "已启动，共发现 " ScriptList.Length " 个脚本")
}

; -------------------------------------------------
; ⌨️ 全局热键
; -------------------------------------------------

; Win + Alt + R: 重载所有脚本
#!r:: {
    ReloadAllScripts()
}

; Win + Alt + S: 停止所有脚本
#!s:: {
    StopAllScripts()
}

; Win + Alt + A: 启动所有脚本
#!a:: {
    StartAllScripts()
}
