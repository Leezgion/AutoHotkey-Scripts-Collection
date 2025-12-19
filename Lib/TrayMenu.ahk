; =================================================
; 📦 TrayMenu.ahk - 托盘菜单模块
; =================================================
; 功能：
;   - 脚本控制菜单（点击可开启/关闭脚本）
;   - 开机自启动管理
;   - 动态显示置顶窗口菜单（仅当脚本运行时显示）
;   - 动态显示截图悬浮菜单（仅当脚本运行时显示）
;   - 动态显示屏幕取色菜单（仅当脚本运行时显示）
; =================================================
; 依赖: Utils.ahk (ShowNotification)
;       ScriptCore.ahk (脚本管理函数)
;       AutoStart.ahk (自启动函数)
; 注意: 此文件需要通过主入口文件引入
; =================================================

; ---------- 依赖引入 ----------
; 在单独测试时可取消以下注释
; #Include "%A_ScriptDir%\Lib\Utils.ahk"
; #Include "%A_ScriptDir%\Lib\ScriptCore.ahk"
; #Include "%A_ScriptDir%\Lib\AutoStart.ahk"

; -------------------------------------------------
; SetupTrayMenu - 初始化托盘菜单
; -------------------------------------------------
SetupTrayMenu() {
    global ScriptMenu, StartupMenu, PinnedWindowsMenu, ScreenshotMenu, ColorPickerMenu

    ; 创建子菜单对象
    ScriptMenu := Menu()
    StartupMenu := Menu()
    PinnedWindowsMenu := Menu()
    ScreenshotMenu := Menu()
    ColorPickerMenu := Menu()

    ; 重建完整菜单
    RebuildMainMenu()
}

; -------------------------------------------------
; RebuildMainMenu - 重建主托盘菜单
; -------------------------------------------------
RebuildMainMenu() {
    global ScriptMenu, StartupMenu, PinnedWindowsMenu, ScreenshotMenu, ScriptList

    ; 清空主菜单
    A_TrayMenu.Delete()

    ; 标题
    A_TrayMenu.Add("🎛️ AHK 脚本管理器", MenuDummy)
    A_TrayMenu.Disable("🎛️ AHK 脚本管理器")
    A_TrayMenu.Add()

    ; 脚本控制子菜单
    BuildScriptMenu()
    A_TrayMenu.Add("📜 脚本控制", ScriptMenu)

    ; 开机自启动子菜单
    BuildStartupMenu()
    A_TrayMenu.Add("🚀 开机自启动", StartupMenu)

    A_TrayMenu.Add()

    ; 动态显示置顶窗口菜单（仅当置顶窗口脚本运行时显示）
    if IsPinnedWindowScriptRunning() {
        BuildPinnedWindowsMenu()
        A_TrayMenu.Add("📌 置顶窗口", PinnedWindowsMenu)
    }

    ; 动态显示截图悬浮菜单（仅当截图脚本运行时显示）
    if IsScreenshotScriptRunning() {
        BuildScreenshotMenu()
        A_TrayMenu.Add("📸 截图悬浮", ScreenshotMenu)
    }

    ; 动态显示屏幕取色菜单（仅当取色脚本运行时显示）
    if IsColorPickerScriptRunning() {
        BuildColorPickerMenu()
        A_TrayMenu.Add("🎨 屏幕取色", ColorPickerMenu)
    }

    ; 如果有任一功能菜单显示，添加分隔线
    if (IsPinnedWindowScriptRunning() || IsScreenshotScriptRunning() || IsColorPickerScriptRunning())
        A_TrayMenu.Add()

    ; 其他选项
    A_TrayMenu.Add("📂 打开脚本目录", MenuOpenFolder)
    A_TrayMenu.Add("🔄 刷新状态", MenuRefresh)
    A_TrayMenu.Add()

    ; 脚本管理器自身的开机自启动选项
    managerAutoStart := IsManagerAutoStartEnabled()
    managerAutoStartText := managerAutoStart ? "✅ 管理器开机自启" : "⬜ 管理器开机自启"
    A_TrayMenu.Add(managerAutoStartText, MenuToggleManagerAutoStart)

    A_TrayMenu.Add()
    A_TrayMenu.Add("🔃 重载管理器", MenuReload)
    A_TrayMenu.Add("❌ 退出管理器", MenuExit)
}

; -------------------------------------------------
; IsPinnedWindowScriptRunning - 检查置顶窗口脚本是否运行
; -------------------------------------------------
IsPinnedWindowScriptRunning() {
    global ScriptList

    for script in ScriptList {
        if InStr(script.Name, "置顶窗口") && script.Running
            return true
    }
    return false
}

; -------------------------------------------------
; IsScreenshotScriptRunning - 检查截图悬浮脚本是否运行
; -------------------------------------------------
IsScreenshotScriptRunning() {
    global ScriptList

    for script in ScriptList {
        if InStr(script.Name, "截图悬浮") && script.Running
            return true
    }
    return false
}

; -------------------------------------------------
; IsColorPickerScriptRunning - 检查屏幕取色脚本是否运行
; -------------------------------------------------
IsColorPickerScriptRunning() {
    global ScriptList

    for script in ScriptList {
        if InStr(script.Name, "屏幕取色") && script.Running
            return true
    }
    return false
}

; -------------------------------------------------
; UpdateTrayMenu - 更新托盘菜单内容
; -------------------------------------------------
UpdateTrayMenu() {
    ; 完全重建菜单以支持动态显示/隐藏
    RebuildMainMenu()
}

; -------------------------------------------------
; 脚本管理器自身的开机自启动功能
; -------------------------------------------------

; 检查管理器是否设置了开机自启动
IsManagerAutoStartEnabled() {
    shortcutPath := A_Startup "\ScriptManager.lnk"
    return FileExist(shortcutPath) ? true : false
}

; 切换管理器开机自启动状态
MenuToggleManagerAutoStart(ItemName, ItemPos, MyMenu) {
    if IsManagerAutoStartEnabled() {
        DisableManagerAutoStart()
    } else {
        EnableManagerAutoStart()
    }
    ; 刷新菜单以更新显示
    RebuildMainMenu()
}

; 启用管理器开机自启动
EnableManagerAutoStart() {
    global ScriptFolder

    shortcutPath := A_Startup "\ScriptManager.lnk"

    ; 使用 ScriptFolder 构建正确的路径
    managerPath := ScriptFolder "\ScriptManager.ahk"
    managerDir := ScriptFolder

    ; 检查脚本管理器文件是否存在
    if !FileExist(managerPath) {
        ShowNotification("❌ 错误", "找不到脚本: " managerPath)
        return false
    }

    try {
        shell := ComObject("WScript.Shell")
        shortcut := shell.CreateShortcut(shortcutPath)
        shortcut.TargetPath := managerPath
        shortcut.WorkingDirectory := managerDir
        ; 使用纯 ASCII 描述避免编码问题
        shortcut.Description := "AHK Script Manager - Auto Start"
        shortcut.Save()

        ShowNotification("✅ 已启用", "脚本管理器将在开机时自动启动")
        return true
    } catch as e {
        ShowNotification("❌ 创建失败", e.Message)
        return false
    }
}

; 禁用管理器开机自启动
DisableManagerAutoStart() {
    shortcutPath := A_Startup "\ScriptManager.lnk"

    try {
        if FileExist(shortcutPath) {
            FileDelete(shortcutPath)
            ShowNotification("❎ 已禁用", "脚本管理器不再开机自启")
            return true
        }
        return false
    } catch as e {
        ShowNotification("❌ 删除快捷方式失败", e.Message)
        return false
    }
}

; -------------------------------------------------
; 主菜单回调函数
; -------------------------------------------------
MenuDummy(ItemName, ItemPos, MyMenu) {
    ; 空操作，用于标题
}

MenuOpenFolder(ItemName, ItemPos, MyMenu) {
    global ScriptFolder
    Run("explorer.exe `"" ScriptFolder "`"")
}

MenuRefresh(ItemName, ItemPos, MyMenu) {
    RefreshStatus()
    ShowNotification("🔄 已刷新", "脚本状态已更新")
}

MenuReload(ItemName, ItemPos, MyMenu) {
    Reload()
}

MenuExit(ItemName, ItemPos, MyMenu) {
    ExitApp()
}

; -------------------------------------------------
; BuildScriptMenu - 构建脚本控制子菜单
; -------------------------------------------------
BuildScriptMenu() {
    global ScriptList, ScriptMenu

    ; 清空现有菜单项（不重新创建对象，保持引用）
    try ScriptMenu.Delete()

    ; 统计信息
    runningCount := 0
    for script in ScriptList {
        if script.Running
            runningCount++
    }
    ScriptMenu.Add("📊 运行中: " runningCount "/" ScriptList.Length, MenuDummy)
    ScriptMenu.Disable("📊 运行中: " runningCount "/" ScriptList.Length)
    ScriptMenu.Add()

    ; 批量操作
    ScriptMenu.Add("▶️ 启动全部", MenuStartAll)
    ScriptMenu.Add("⏹️ 停止全部", MenuStopAll)
    ScriptMenu.Add("🔄 重载全部", MenuReloadAll)
    ScriptMenu.Add()

    ; 单个脚本控制 - 使用索引绑定
    for index, script in ScriptList {
        statusIcon := script.Running ? "✅" : "⬜"
        menuText := statusIcon " " script.Name

        ; 使用索引作为绑定参数，避免闭包问题
        ScriptMenu.Add(menuText, ToggleScriptByIndex.Bind(index))
    }
}

; -------------------------------------------------
; BuildStartupMenu - 构建自启动子菜单
; -------------------------------------------------
BuildStartupMenu() {
    global ScriptList, StartupMenu

    ; 清空现有菜单项（不重新创建对象，保持引用）
    try StartupMenu.Delete()

    ; 统计信息
    autoStartCount := 0
    for script in ScriptList {
        if script.AutoStart
            autoStartCount++
    }
    StartupMenu.Add("📊 已设置: " autoStartCount "/" ScriptList.Length, MenuDummy)
    StartupMenu.Disable("📊 已设置: " autoStartCount "/" ScriptList.Length)
    StartupMenu.Add()

    ; 批量操作
    StartupMenu.Add("✅ 全部启用", MenuEnableAllAutoStart)
    StartupMenu.Add("❎ 全部禁用", MenuDisableAllAutoStart)
    StartupMenu.Add()

    ; 单个脚本自启动设置 - 使用索引绑定
    for index, script in ScriptList {
        statusIcon := script.AutoStart ? "🚀" : "⬜"
        menuText := statusIcon " " script.Name

        StartupMenu.Add(menuText, ToggleAutoStartByIndex.Bind(index))
    }
}

; -------------------------------------------------
; BuildPinnedWindowsMenu - 构建置顶窗口子菜单
; -------------------------------------------------
BuildPinnedWindowsMenu() {
    global PinnedWindowsMenu

    ; 清空现有菜单项（不重新创建对象，保持引用）
    try PinnedWindowsMenu.Delete()

    PinnedWindowsMenu.Add("📌 置顶当前窗口", MenuSendPin)
    PinnedWindowsMenu.Add("❌ 取消所有置顶", MenuSendUnpinAll)
    PinnedWindowsMenu.Add("🔄 切换置顶窗口", MenuSendSwitch)
    PinnedWindowsMenu.Add("🎨 更换边框颜色", MenuSendChangeColor)
    PinnedWindowsMenu.Add()
    PinnedWindowsMenu.Add("⌨️ 快捷键说明", MenuDummy)
    PinnedWindowsMenu.Disable("⌨️ 快捷键说明")
    PinnedWindowsMenu.Add("    CapsLock+Space 置顶/取消", MenuDummy)
    PinnedWindowsMenu.Disable("    CapsLock+Space 置顶/取消")
    PinnedWindowsMenu.Add("    CapsLock+Esc 取消全部", MenuDummy)
    PinnedWindowsMenu.Disable("    CapsLock+Esc 取消全部")
    PinnedWindowsMenu.Add("    CapsLock+Tab 切换窗口", MenuDummy)
    PinnedWindowsMenu.Disable("    CapsLock+Tab 切换窗口")
    PinnedWindowsMenu.Add("    CapsLock+C 换颜色", MenuDummy)
    PinnedWindowsMenu.Disable("    CapsLock+C 换颜色")
}

; -------------------------------------------------
; BuildScreenshotMenu - 构建截图悬浮子菜单
; -------------------------------------------------
BuildScreenshotMenu() {
    global ScreenshotMenu

    ; 清空现有菜单项（不重新创建对象，保持引用）
    try ScreenshotMenu.Delete()

    ScreenshotMenu.Add("📷 开始截图", MenuSendStartScreenshot)
    ScreenshotMenu.Add("❌ 关闭所有悬浮窗", MenuSendCloseAllScreenshots)
    ScreenshotMenu.Add()
    ScreenshotMenu.Add("⌨️ 快捷键说明", MenuDummy)
    ScreenshotMenu.Disable("⌨️ 快捷键说明")
    ScreenshotMenu.Add("    Win+Shift+S 开始截图", MenuDummy)
    ScreenshotMenu.Disable("    Win+Shift+S 开始截图")
    ScreenshotMenu.Add("    Esc 取消/关闭悬浮窗", MenuDummy)
    ScreenshotMenu.Disable("    Esc 取消/关闭悬浮窗")
    ScreenshotMenu.Add("    Ctrl+A 关闭所有悬浮窗", MenuDummy)
    ScreenshotMenu.Disable("    Ctrl+A 关闭所有悬浮窗")
    ScreenshotMenu.Add()
    ScreenshotMenu.Add("🖱️ 悬浮窗操作", MenuDummy)
    ScreenshotMenu.Disable("🖱️ 悬浮窗操作")
    ScreenshotMenu.Add("    滚轮 缩放大小", MenuDummy)
    ScreenshotMenu.Disable("    滚轮 缩放大小")
    ScreenshotMenu.Add("    Ctrl+滚轮 透明度(对比用)", MenuDummy)
    ScreenshotMenu.Disable("    Ctrl+滚轮 透明度(对比用)")
    ScreenshotMenu.Add("    Ctrl+C 复制到剪贴板", MenuDummy)
    ScreenshotMenu.Disable("    Ctrl+C 复制到剪贴板")
    ScreenshotMenu.Add("    Ctrl+S 保存到文件", MenuDummy)
    ScreenshotMenu.Disable("    Ctrl+S 保存到文件")
}

; =================================================
; 脚本控制回调函数
; =================================================

MenuStartAll(ItemName, ItemPos, MyMenu) {
    StartAllScripts()
}

MenuStopAll(ItemName, ItemPos, MyMenu) {
    StopAllScripts()
}

MenuReloadAll(ItemName, ItemPos, MyMenu) {
    ReloadAllScripts()
}

; 通过索引切换脚本状态
ToggleScriptByIndex(index, ItemName, ItemPos, MyMenu) {
    global ScriptList

    if (index >= 1 && index <= ScriptList.Length) {
        script := ScriptList[index]
        ToggleScript(script.Path)
    }
}

; =================================================
; 自启动回调函数
; =================================================

MenuEnableAllAutoStart(ItemName, ItemPos, MyMenu) {
    EnableAllAutoStart()
}

MenuDisableAllAutoStart(ItemName, ItemPos, MyMenu) {
    DisableAllAutoStart()
}

; 通过索引切换自启动状态
ToggleAutoStartByIndex(index, ItemName, ItemPos, MyMenu) {
    global ScriptList

    if (index >= 1 && index <= ScriptList.Length) {
        script := ScriptList[index]
        ToggleAutoStart(script.Path)
    }
}

; =================================================
; 置顶窗口回调函数
; =================================================

MenuSendPin(ItemName, ItemPos, MyMenu) {
    SendPinCommand()
}

MenuSendUnpinAll(ItemName, ItemPos, MyMenu) {
    SendUnpinAllCommand()
}

MenuSendSwitch(ItemName, ItemPos, MyMenu) {
    SendSwitchCommand()
}

MenuSendChangeColor(ItemName, ItemPos, MyMenu) {
    SendChangeColorCommand()
}

; -------------------------------------------------
; 发送命令到置顶窗口脚本 (使用 PostMessage)
; 消息编号: 0x1001=置顶, 0x1002=取消全部, 0x1003=切换, 0x1004=换色
; -------------------------------------------------
GetPinnedWindowScriptHwnd() {
    DetectHiddenWindows(true)

    ; 遍历所有 AutoHotkey 窗口查找置顶窗口脚本
    for hwnd in WinGetList("ahk_class AutoHotkey") {
        title := WinGetTitle(hwnd)
        if InStr(title, "置顶窗口")
            return hwnd
    }

    return 0
}

SendPinCommand() {
    hwnd := GetPinnedWindowScriptHwnd()
    if (hwnd) {
        PostMessage(0x1001, 0, 0, , "ahk_id " hwnd)
    } else {
        ShowNotification("⚠️ 提示", "置顶窗口脚本未运行")
    }
}

SendUnpinAllCommand() {
    hwnd := GetPinnedWindowScriptHwnd()
    if (hwnd) {
        PostMessage(0x1002, 0, 0, , "ahk_id " hwnd)
    } else {
        ShowNotification("⚠️ 提示", "置顶窗口脚本未运行")
    }
}

SendSwitchCommand() {
    hwnd := GetPinnedWindowScriptHwnd()
    if (hwnd) {
        PostMessage(0x1003, 0, 0, , "ahk_id " hwnd)
    } else {
        ShowNotification("⚠️ 提示", "置顶窗口脚本未运行")
    }
}

SendChangeColorCommand() {
    hwnd := GetPinnedWindowScriptHwnd()
    if (hwnd) {
        PostMessage(0x1004, 0, 0, , "ahk_id " hwnd)
    } else {
        ShowNotification("⚠️ 提示", "置顶窗口脚本未运行")
    }
}

; =================================================
; 截图悬浮回调函数
; =================================================

MenuSendStartScreenshot(ItemName, ItemPos, MyMenu) {
    SendStartScreenshotCommand()
}

MenuSendCloseAllScreenshots(ItemName, ItemPos, MyMenu) {
    SendCloseAllScreenshotsCommand()
}

; -------------------------------------------------
; 发送命令到截图悬浮脚本 (使用 PostMessage)
; 消息编号: 0x2001=开始截图, 0x2002=关闭所有悬浮窗
; -------------------------------------------------
GetScreenshotScriptHwnd() {
    DetectHiddenWindows(true)

    ; 遍历所有 AutoHotkey 窗口查找截图悬浮脚本
    for hwnd in WinGetList("ahk_class AutoHotkey") {
        title := WinGetTitle(hwnd)
        if InStr(title, "截图悬浮")
            return hwnd
    }

    return 0
}

SendStartScreenshotCommand() {
    hwnd := GetScreenshotScriptHwnd()
    if (hwnd) {
        ; 使用 SendMessage 而不是 PostMessage，确保消息被处理
        ; 但使用较短的超时时间
        try {
            result := SendMessage(0x2001, 0, 0, , "ahk_id " hwnd, , , 1000)
            if (result = 0)
                ShowNotification("📸 截图", "正在启动...")
        } catch {
            ; 如果 SendMessage 超时，尝试 PostMessage
            PostMessage(0x2001, 0, 0, , "ahk_id " hwnd)
        }
    } else {
        ShowNotification("⚠️ 提示", "截图悬浮脚本未运行")
    }
}

SendCloseAllScreenshotsCommand() {
    hwnd := GetScreenshotScriptHwnd()
    if (hwnd) {
        try {
            SendMessage(0x2002, 0, 0, , "ahk_id " hwnd, , , 1000)
        } catch {
            PostMessage(0x2002, 0, 0, , "ahk_id " hwnd)
        }
    } else {
        ShowNotification("⚠️ 提示", "截图悬浮脚本未运行")
    }
}

; =================================================
; 屏幕取色回调函数
; =================================================

MenuSendStartColorPicker(ItemName, ItemPos, MyMenu) {
    SendStartColorPickerCommand()
}

MenuSendShowColorHistory(ItemName, ItemPos, MyMenu) {
    SendShowColorHistoryCommand()
}

; -------------------------------------------------
; 构建屏幕取色子菜单
; -------------------------------------------------
BuildColorPickerMenu() {
    global ColorPickerMenu

    try ColorPickerMenu.Delete()

    ColorPickerMenu.Add("🎨 开始取色", MenuSendStartColorPicker)
    ColorPickerMenu.Add("📋 颜色历史", MenuSendShowColorHistory)
    ColorPickerMenu.Add()
    ColorPickerMenu.Add("⌨️ 快捷键说明", MenuDummy)
    ColorPickerMenu.Disable("⌨️ 快捷键说明")
    ColorPickerMenu.Add("    Win+Shift+C 开始取色", MenuDummy)
    ColorPickerMenu.Disable("    Win+Shift+C 开始取色")
    ColorPickerMenu.Add("    左键点击 复制颜色", MenuDummy)
    ColorPickerMenu.Disable("    左键点击 复制颜色")
    ColorPickerMenu.Add("    右键点击 切换格式", MenuDummy)
    ColorPickerMenu.Disable("    右键点击 切换格式")
    ColorPickerMenu.Add("    滚轮 调整放大倍数", MenuDummy)
    ColorPickerMenu.Disable("    滚轮 调整放大倍数")
}

; -------------------------------------------------
; 发送命令到屏幕取色脚本 (使用 PostMessage)
; 消息编号: 0x3001=开始取色, 0x3002=显示历史
; -------------------------------------------------
GetColorPickerScriptHwnd() {
    DetectHiddenWindows(true)

    ; 遍历所有 AutoHotkey 窗口查找屏幕取色脚本
    for hwnd in WinGetList("ahk_class AutoHotkey") {
        title := WinGetTitle(hwnd)
        if InStr(title, "屏幕取色")
            return hwnd
    }

    return 0
}

SendStartColorPickerCommand() {
    hwnd := GetColorPickerScriptHwnd()
    if (hwnd) {
        try {
            SendMessage(0x3001, 0, 0, , "ahk_id " hwnd, , , 1000)
        } catch {
            PostMessage(0x3001, 0, 0, , "ahk_id " hwnd)
        }
    } else {
        ShowNotification("⚠️ 提示", "屏幕取色脚本未运行")
    }
}

SendShowColorHistoryCommand() {
    hwnd := GetColorPickerScriptHwnd()
    if (hwnd) {
        try {
            SendMessage(0x3002, 0, 0, , "ahk_id " hwnd, , , 1000)
        } catch {
            PostMessage(0x3002, 0, 0, , "ahk_id " hwnd)
        }
    } else {
        ShowNotification("⚠️ 提示", "屏幕取色脚本未运行")
    }
}
