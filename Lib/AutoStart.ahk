; =================================================
; 📦 AutoStart.ahk - 开机自启动管理模块
; =================================================
; 依赖: Utils.ahk (ShowNotification)
;       ScriptCore.ahk (RefreshStatus) - 双向依赖
; 注意: 此文件需要通过主入口文件引入
; =================================================

; ---------- 依赖引入 ----------
; 在单独测试时可取消以下注释
; #Include "%A_ScriptDir%\Lib\Utils.ahk"

; -------------------------------------------------
; IsAutoStartEnabled - 检查脚本是否设置了自启动
; -------------------------------------------------
IsAutoStartEnabled(scriptPath) {
    scriptName := ""
    SplitPath(scriptPath, &scriptName)

    shortcutPath := A_Startup "\" RegExReplace(scriptName, "\.ahk$", ".lnk")
    return FileExist(shortcutPath) ? true : false
}

; -------------------------------------------------
; ToggleAutoStart - 切换脚本自启动状态
; -------------------------------------------------
ToggleAutoStart(scriptPath) {
    if IsAutoStartEnabled(scriptPath) {
        DisableAutoStart(scriptPath)
    } else {
        EnableAutoStart(scriptPath)
    }

    RefreshStatus()
}

; -------------------------------------------------
; EnableAutoStart - 启用脚本自启动
; 参数: scriptPath - 脚本路径
;       showNotify - 是否显示通知 (默认 true)
; -------------------------------------------------
EnableAutoStart(scriptPath, showNotify := true) {
    scriptName := ""
    SplitPath(scriptPath, &scriptName)

    shortcutPath := A_Startup "\" RegExReplace(scriptName, "\.ahk$", ".lnk")

    try {
        shell := ComObject("WScript.Shell")
        shortcut := shell.CreateShortcut(shortcutPath)
        shortcut.TargetPath := scriptPath
        shortcut.WorkingDirectory := A_WorkingDir
        shortcut.Description := "AutoHotkey Script: " scriptName
        shortcut.Save()

        if showNotify
            ShowNotification("✅ 自启动已启用", scriptName)
        return true
    } catch as e {
        if showNotify
            ShowNotification("❌ 创建快捷方式失败", e.Message)
        return false
    }
}

; -------------------------------------------------
; DisableAutoStart - 禁用脚本自启动
; 参数: scriptPath - 脚本路径
;       showNotify - 是否显示通知 (默认 true)
; -------------------------------------------------
DisableAutoStart(scriptPath, showNotify := true) {
    scriptName := ""
    SplitPath(scriptPath, &scriptName)

    shortcutPath := A_Startup "\" RegExReplace(scriptName, "\.ahk$", ".lnk")

    try {
        if FileExist(shortcutPath) {
            FileDelete(shortcutPath)
            if showNotify
                ShowNotification("❎ 自启动已禁用", scriptName)
            return true
        }
        return false
    } catch as e {
        if showNotify
            ShowNotification("❌ 删除快捷方式失败", e.Message)
        return false
    }
}

; -------------------------------------------------
; EnableAllAutoStart - 启用所有脚本自启动
; -------------------------------------------------
EnableAllAutoStart() {
    global ScriptList

    ; 统计需要设置的数量
    needSet := 0
    for script in ScriptList {
        ; 实时检测文件是否存在
        if !IsAutoStartEnabled(script.Path)
            needSet++
    }

    if (needSet = 0) {
        ShowNotification("ℹ️ 提示", "所有脚本已设置自启动")
        return
    }

    count := 0
    for script in ScriptList {
        ; 实时检测，而不是依赖缓存的 script.AutoStart
        if !IsAutoStartEnabled(script.Path) {
            if EnableAutoStart(script.Path, false) {
                script.AutoStart := true
                count++
            }
            Sleep(50)
        }
    }

    ShowNotification("✅ 批量启用", "已设置 " count " 个自启动")
    SetTimer(RefreshStatus, -300)
}

; -------------------------------------------------
; DisableAllAutoStart - 禁用所有脚本自启动
; -------------------------------------------------
DisableAllAutoStart() {
    global ScriptList

    ; 统计需要禁用的数量
    needDisable := 0
    for script in ScriptList {
        if IsAutoStartEnabled(script.Path)
            needDisable++
    }

    if (needDisable = 0) {
        ShowNotification("ℹ️ 提示", "没有脚本设置了自启动")
        return
    }

    count := 0
    for script in ScriptList {
        ; 实时检测，而不是依赖缓存
        if IsAutoStartEnabled(script.Path) {
            if DisableAutoStart(script.Path, false) {
                script.AutoStart := false
                count++
            }
            Sleep(50)
        }
    }

    ShowNotification("❎ 批量禁用", "已禁用 " count " 个自启动")
    SetTimer(RefreshStatus, -300)
}
