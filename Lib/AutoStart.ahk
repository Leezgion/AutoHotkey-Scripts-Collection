; =================================================
; 📦 AutoStart.ahk - 开机自启动（管理器）
; =================================================
; 说明：
;   - 仅负责 ScriptManager 自身的开机自启快捷方式
;   - 不再包含旧版“脚本扫描/批量自启”等逻辑
; =================================================

_GetManagerShortcutPath() {
    linkName := RegExReplace(A_ScriptName, "\.(ahk|exe)$", ".lnk")
    return A_Startup "\\" linkName
}

IsManagerAutoStartEnabled() {
    return FileExist(_GetManagerShortcutPath()) ? true : false
}

EnableManagerAutoStart() {
    shortcutPath := _GetManagerShortcutPath()

    try {
        shell := ComObject("WScript.Shell")
        shortcut := shell.CreateShortcut(shortcutPath)
        shortcut.TargetPath := A_ScriptFullPath
        shortcut.WorkingDirectory := A_ScriptDir
        shortcut.Description := "AutoHotkey Manager: " A_ScriptName
        shortcut.Save()
        return true
    } catch {
        return false
    }
}

DisableManagerAutoStart() {
    shortcutPath := _GetManagerShortcutPath()
    try {
        if FileExist(shortcutPath) {
            FileDelete(shortcutPath)
            return true
        }
        return true
    } catch {
        return false
    }
}

SetManagerAutoStartEnabled(enabled) {
    return enabled ? EnableManagerAutoStart() : DisableManagerAutoStart()
}
