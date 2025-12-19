; =================================================
; 📦 ScriptCore.ahk - 脚本扫描与控制核心
; =================================================

; -------------------------------------------------
; ScanScripts - 扫描目录下的所有 AHK 脚本
; -------------------------------------------------
ScanScripts() {
    global ScriptList, ScriptFolder, ExcludedScripts

    ScriptList := []

    ; 扫描当前目录（不递归）
    loop files ScriptFolder "\*.ahk" {
        fileName := A_LoopFileName

        ; 检查是否在排除列表中
        isExcluded := false
        for excluded in ExcludedScripts {
            if (fileName = excluded) {
                isExcluded := true
                break
            }
        }

        if (!isExcluded) {
            ScriptList.Push({
                Name: fileName,
                Path: A_LoopFileFullPath,
                Running: IsScriptRunning(A_LoopFileFullPath),
                AutoStart: IsAutoStartEnabled(A_LoopFileFullPath)
            })
        }
    }
}

; -------------------------------------------------
; IsScriptRunning - 检查脚本是否正在运行
; -------------------------------------------------
IsScriptRunning(scriptPath) {
    scriptName := ""
    SplitPath(scriptPath, &scriptName)

    ; 通过窗口标题检测 AHK 脚本是否运行
    DetectHiddenWindows(true)

    ; 遍历所有 AutoHotkey 窗口查找匹配
    for hwnd in WinGetList("ahk_class AutoHotkey") {
        title := WinGetTitle(hwnd)
        ; 检查窗口标题是否包含脚本路径或文件名
        if InStr(title, scriptPath) || InStr(title, scriptName)
            return true
    }

    return false
}

; -------------------------------------------------
; ToggleScript - 切换脚本运行状态
; -------------------------------------------------
ToggleScript(scriptPath) {
    wasRunning := IsScriptRunning(scriptPath)

    if wasRunning {
        StopScript(scriptPath)
    } else {
        StartScript(scriptPath)
    }

    ; 使用定时器延迟刷新，避免菜单操作冲突
    SetTimer(RefreshStatus, -500)
}

; -------------------------------------------------
; StartScript - 启动脚本
; 参数: scriptPath - 脚本路径
;       showNotify - 是否显示通知 (默认 true)
; -------------------------------------------------
StartScript(scriptPath, showNotify := true) {
    if !IsScriptRunning(scriptPath) {
        try {
            Run('"' scriptPath '"')
            if showNotify
                ShowNotification("▶️ 已启动", GetFileName(scriptPath))
            return true
        } catch as e {
            if showNotify
                ShowNotification("❌ 启动失败", e.Message)
            return false
        }
    }
    return false
}

; -------------------------------------------------
; StopScript - 停止脚本
; 参数: scriptPath - 脚本路径
;       showNotify - 是否显示通知 (默认 true)
; -------------------------------------------------
StopScript(scriptPath, showNotify := true) {
    scriptName := ""
    SplitPath(scriptPath, &scriptName)

    DetectHiddenWindows(true)

    try {
        closed := false

        ; 遍历所有 AutoHotkey 窗口查找匹配的脚本
        for hwnd in WinGetList("ahk_class AutoHotkey") {
            title := WinGetTitle(hwnd)
            ; 检查窗口标题是否包含脚本路径或文件名
            if InStr(title, scriptPath) || InStr(title, scriptName) {
                WinClose(hwnd)
                closed := true
                break
            }
        }

        if closed && showNotify
            ShowNotification("⏹️ 已停止", scriptName)
        return closed
    }
    return false
}

; -------------------------------------------------
; ReloadScript - 重载单个脚本
; -------------------------------------------------
ReloadScript(scriptPath) {
    StopScript(scriptPath)
    Sleep(300)
    StartScript(scriptPath)
}

; -------------------------------------------------
; StartAllScripts - 启动所有脚本
; -------------------------------------------------
StartAllScripts() {
    global ScriptList

    count := 0
    for script in ScriptList {
        if !script.Running {
            if StartScript(script.Path, false) {
                script.Running := true
                count++
            }
            Sleep(200)
        }
    }

    ShowNotification("▶️ 批量启动", "已启动 " count " 个脚本")
    SetTimer(RefreshStatus, -500)
}

; -------------------------------------------------
; StopAllScripts - 停止所有脚本
; -------------------------------------------------
StopAllScripts() {
    global ScriptList

    count := 0
    for script in ScriptList {
        if script.Running {
            if StopScript(script.Path, false) {
                script.Running := false
                count++
            }
            Sleep(100)
        }
    }

    ShowNotification("⏹️ 批量停止", "已停止 " count " 个脚本")
    SetTimer(RefreshStatus, -500)
}

; -------------------------------------------------
; ReloadAllScripts - 重载所有正在运行的脚本
; -------------------------------------------------
ReloadAllScripts() {
    global ScriptList

    ; 先记录哪些在运行
    runningScripts := []
    for script in ScriptList {
        if script.Running
            runningScripts.Push(script.Path)
    }

    ; 停止所有（不显示单独通知）
    for scriptPath in runningScripts {
        StopScript(scriptPath, false)
    }

    Sleep(500)

    ; 重新启动（不显示单独通知）
    for scriptPath in runningScripts {
        StartScript(scriptPath, false)
        Sleep(200)
    }

    ShowNotification("🔄 重载完成", "已重载 " runningScripts.Length " 个脚本")
    SetTimer(RefreshStatus, -500)
}

; -------------------------------------------------
; RefreshStatus - 刷新所有脚本状态
; -------------------------------------------------
RefreshStatus() {
    global ScriptList

    for script in ScriptList {
        script.Running := IsScriptRunning(script.Path)
        script.AutoStart := IsAutoStartEnabled(script.Path)
    }

    UpdateTrayMenu()
}
