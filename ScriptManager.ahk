; =================================================
; 🛠️ ScriptManager.ahk - 脚本管理器 (模块化版本)
; =================================================
; 功能说明：
;   - 统一管理所有脚本功能
;   - 托盘菜单快捷操作
;   - 配置管理和国际化
;   - 主控制面板 GUI
; =================================================

#Requires AutoHotkey v2.0
#SingleInstance Force
SetWorkingDir A_ScriptDir

; 性能设置
SetWinDelay(-1)
SetControlDelay(-1)

; ---------- 引入公共库 ----------
#Include Lib\Constants.ahk
#Include Lib\AutoStart.ahk
#Include Lib\ConfigManager.ahk
#Include Lib\GDIPlus.ahk
#Include Lib\Hotkeys.ahk
#Include Lib\I18n.ahk
#Include Lib\Logger.ahk
#Include Lib\Utils.ahk

; ---------- 引入功能模块 ----------
#Include Modules\ColorPicker\Picker.ahk
#Include Modules\Screenshot\Capture.ahk
#Include Modules\PinWindow\Pin.ahk

; ---------- 引入 GUI ----------
#Include GUI\SettingsWindow.ahk
#Include GUI\AboutDialog.ahk

; ---------- 全局实例 ----------
global ColorPickerApp := ""
global ScreenshotApp := ""
global PinWindowApp := ""
global SettingsWin := ""
global AboutDlg := ""
; 模块启用状态
global ModuleEnabled := Map(
    "ColorPicker", true,
    "Screenshot", true,
    "PinWindow", true
)

; ---------- 初始化 ----------
InitApplication()

InitApplication() {
    global ColorPickerApp, ScreenshotApp, PinWindowApp
    global SettingsWin, AboutDlg
    global ModuleEnabled

    ; 初始化 GDI+
    GDIPlus.Startup()

    ; 初始化日志
    Logger.Init("INFO", false)
    Logger.Info("ScriptManager starting...")

    ; 初始化国际化
    I18n.Init()

    ; 应用开机自启设置（管理器）
    ApplyManagerAutoStartFromConfig(false)

    ; 从配置读取模块启用状态
    ModuleEnabled["ColorPicker"] := ConfigManager.Get("Modules", "ColorPicker", "true") = "true"
    ModuleEnabled["Screenshot"] := ConfigManager.Get("Modules", "Screenshot", "true") = "true"
    ModuleEnabled["PinWindow"] := ConfigManager.Get("Modules", "PinWindow", "true") = "true"

    ; 创建取色器（从配置读取）
    pickerConfig := {
        DefaultFormat: ConfigManager.Get("ColorPicker", "DefaultFormat", "HEX"),
        MagnifierZoom: Integer(ConfigManager.Get("ColorPicker", "ZoomLevel", "8")),
        MagnifierSize: Integer(ConfigManager.Get("ColorPicker", "MagnifierSize", "150")),
        MaxHistory: Integer(ConfigManager.Get("ColorPicker", "MaxHistory", "10")),
        ShowGrid: ConfigManager.Get("ColorPicker", "ShowGrid", "true") = "true",
        ShowCrosshair: ConfigManager.Get("ColorPicker", "ShowCrosshair", "true") = "true"
    }
    ColorPickerApp := ColorPicker(pickerConfig)
    ColorPickerApp.OnColorPicked := OnColorPicked
    ColorPickerApp.OnNotify := ShowNotify

    ; 创建截图工具（从配置读取）
    screenshotFolder := ConfigManager.Get("Screenshot", "SavePath", Paths.Screenshots)
    defaultFormat := ConfigManager.Get("Screenshot", "DefaultFormat", "PNG")
    autoCopy := ConfigManager.Get("Screenshot", "AutoCopy", "true") = "true"

    screenshotConfig := {
        ScreenshotFolder: screenshotFolder,
        DefaultFormat: defaultFormat,
        AutoCopy: autoCopy
    }
    ScreenshotApp := ScreenCapture(screenshotConfig)
    ScreenshotApp.OnCapture := OnScreenshotCapture
    ScreenshotApp.OnNotify := ShowNotify

    ; 确保截图目录存在
    if !DirExist(screenshotFolder)
        DirCreate(screenshotFolder)

    ; 创建置顶工具（从配置读取）
    pinConfig := {
        BorderThickness: Integer(ConfigManager.Get("PinWindow", "BorderThickness", String(Defaults.PinBorderThickness))),
        SoundEnabled: ConfigManager.Get("PinWindow", "SoundEnabled", "true") = "true",
        FlashCount: Integer(ConfigManager.Get("PinWindow", "FlashCount", String(Defaults.PinFlashCount))),
        FlashInterval: Integer(ConfigManager.Get("PinWindow", "FlashInterval", String(Defaults.PinFlashInterval))),
        UpdateInterval: Integer(ConfigManager.Get("PinWindow", "UpdateInterval", String(Defaults.PinUpdateInterval)))
    }
    PinWindowApp := WindowPinner(pinConfig)
    PinWindowApp.OnPin := OnWindowPinned
    PinWindowApp.OnUnpin := OnWindowUnpinned
    PinWindowApp.OnNotify := ShowNotify

    ; 创建关于对话框
    AboutDlg := AboutDialog()

    ; 创建设置窗口
    SettingsWin := SettingsWindow()
    SettingsWin.OnSave := OnSettingsSaved
    SettingsWin.OnModuleToggle := OnModuleToggle

    ; 设置托盘菜单
    SetupTrayMenu()

    ; 注册快捷键（统一从 Config/hotkeys.ini 加载）
    RegisterHotkeys()

    Logger.Info("ScriptManager initialized successfully")
}

OnSettingsSaved() {
    ApplyManagerAutoStartFromConfig(true)
}

ApplyManagerAutoStartFromConfig(showNotify) {
    enabled := ConfigManager.Get("General", "AutoStart", "false") = "true"
    current := IsManagerAutoStartEnabled()
    if (enabled = current)
        return

    ok := SetManagerAutoStartEnabled(enabled)
    if showNotify {
        if ok {
            ShowNotify("✅", enabled ? T("Settings", "AutoStartEnabled", "已启用开机自启") : T("Settings", "AutoStartDisabled", "已关闭开机自启"))
        } else {
            ShowNotify("❌", T("Settings", "AutoStartFailed", "设置开机自启失败"))
        }
    }
}

; =================================================
; 快捷键（统一入口）
; =================================================
RegisterHotkeys() {
    _reg := (key, cb, ctx) => (
        ok := HotkeyManager.Register(key, cb, ctx),
        (!ok ? (
            err := HotkeyManager.GetLastBindError(key),
            Logger.Error("Hotkey bind failed: " key " = '" HotkeyManager.GetHotkey(key) "'" (err ? (" (" err ")") : "")),
            ShowNotify("❌", "快捷键注册失败: " ctx (err ? ("\n" err) : ""))
        ) : ""),
        ok
    )

    ; 启动类快捷键（统一从 Config/hotkeys.ini 加载）
    _reg("picker.start", (*) => TrayStartColorPicker(), "Start ColorPicker")
    _reg("screenshot.start", (*) => TrayStartScreenshot(), "Start Screenshot")
    _reg("pin.toggle", (*) => TrayTogglePin(), "Toggle Pin")

    ; 其他功能
    _reg("screenshot.closeAll", (*) => TrayCloseAllFloats(), "Close all floats")
    _reg("pin.unpinAll", (*) => TrayUnpinAll(), "Unpin all")
    _reg("pin.switch", (*) => TraySwitchFocus(), "Switch focus")
    _reg("pin.changeColor", (*) => TrayChangeColor(), "Change border color")

    ; 管理器
    _reg("Global.OpenSettings", (*) => TrayOpenSettings(), "Open settings")
    _reg("Global.Exit", (*) => TrayExit(), "Exit")
}

TrayCloseAllFloats() {
    global ScreenshotApp, ModuleEnabled
    if !ModuleEnabled["Screenshot"]
        return
    if ScreenshotApp
        ScreenshotApp.CloseAllFloats()
}

; =================================================
; 托盘菜单
; =================================================
SetupTrayMenu() {
    global ModuleEnabled

    hkPicker := HotkeyManager.GetDisplayText("picker.start")
    hkScreenshot := HotkeyManager.GetDisplayText("screenshot.start")
    hkPin := HotkeyManager.GetDisplayText("pin.toggle")

    ; 设置托盘图标和提示
    A_IconTip := AppInfo.Name " v" AppInfo.Version

    ; 创建托盘菜单
    tray := A_TrayMenu
    tray.Delete()  ; 清除默认菜单

    ; 功能菜单 - 根据启用状态显示
    if ModuleEnabled["ColorPicker"]
        tray.Add(T("TrayMenu", "ColorPicker", "🎨 屏幕取色") (hkPicker != "None" ? " (" hkPicker ")" : ""), TrayStartColorPicker)
    if ModuleEnabled["Screenshot"]
        tray.Add(T("TrayMenu", "Screenshot", "📷 截图悬浮") (hkScreenshot != "None" ? " (" hkScreenshot ")" : ""), TrayStartScreenshot)
    if ModuleEnabled["PinWindow"]
        tray.Add(T("TrayMenu", "PinWindow", "📌 置顶窗口") (hkPin != "None" ? " (" hkPin ")" : ""), TrayTogglePin)

    ; 只有当有启用的模块时才添加分隔线
    if (ModuleEnabled["ColorPicker"] || ModuleEnabled["Screenshot"] || ModuleEnabled["PinWindow"])
        tray.Add()  ; 分隔线

    ; 取色器子菜单 - 只在启用时显示
    if ModuleEnabled["ColorPicker"] {
        colorSubMenu := Menu()
        colorSubMenu.Add(T("TrayMenu", "StartPicking", "🎨 开始取色") (hkPicker != "None" ? " (" hkPicker ")" : ""), TrayStartColorPicker)
        colorSubMenu.Add(T("TrayMenu", "ColorHistory", "📋 颜色历史记录"), TrayShowColorHistory)
        tray.Add(T("TrayMenu", "ColorPickerMenu", "取色器"), colorSubMenu)
    }

    ; 置顶窗口子菜单 - 只在启用时显示
    if ModuleEnabled["PinWindow"] {
        hkUnpinAll := HotkeyManager.GetDisplayText("pin.unpinAll")
        hkChangeColor := HotkeyManager.GetDisplayText("pin.changeColor")
        pinSubMenu := Menu()
        pinSubMenu.Add(T("TrayMenu", "UnpinAll", "取消所有置顶") (hkUnpinAll != "None" ? " (" hkUnpinAll ")" : ""), TrayUnpinAll)
        pinSubMenu.Add(T("TrayMenu", "SwitchFocus", "切换焦点"), TraySwitchFocus)
        pinSubMenu.Add(T("TrayMenu", "ChangeBorderColor", "更改边框颜色") (hkChangeColor != "None" ? " (" hkChangeColor ")" : ""), TrayChangeColor)
        tray.Add(T("TrayMenu", "PinWindowMenu", "置顶窗口操作"), pinSubMenu)
    }

    ; 只有当有子菜单时才添加分隔线
    if (ModuleEnabled["ColorPicker"] || ModuleEnabled["PinWindow"])
        tray.Add()  ; 分隔线

    ; 模块启用/禁用子菜单
    moduleMenu := Menu()
    colorPickerLabel := T("TrayMenu", "ColorPicker", "🎨 屏幕取色")
    screenshotLabel := T("TrayMenu", "Screenshot", "📷 截图悬浮")
    pinWindowLabel := T("TrayMenu", "PinWindow", "📌 置顶窗口")

    moduleMenu.Add(colorPickerLabel, (*) => ToggleModule("ColorPicker"))
    moduleMenu.Add(screenshotLabel, (*) => ToggleModule("Screenshot"))
    moduleMenu.Add(pinWindowLabel, (*) => ToggleModule("PinWindow"))

    ; 根据状态设置勾选
    if ModuleEnabled["ColorPicker"]
        moduleMenu.Check(colorPickerLabel)
    if ModuleEnabled["Screenshot"]
        moduleMenu.Check(screenshotLabel)
    if ModuleEnabled["PinWindow"]
        moduleMenu.Check(pinWindowLabel)

    tray.Add(T("TrayMenu", "ModuleManagement", "🔧 模块管理"), moduleMenu)

    tray.Add()  ; 分隔线

    ; 设置和关于
    tray.Add(T("TrayMenu", "Settings", "⚙️ 设置"), TrayOpenSettings)
    tray.Add(T("TrayMenu", "About", "💡 关于"), TrayOpenAbout)

    tray.Add()  ; 分隔线

    ; 重载和退出
    tray.Add(T("TrayMenu", "Reload", "🔄 重新加载"), TrayReload)
    tray.Add(T("TrayMenu", "Exit", "❌ 退出"), TrayExit)

    ; 设置默认动作（双击托盘图标）- 根据启用状态选择
    if ModuleEnabled["ColorPicker"]
        tray.Default := T("TrayMenu", "ColorPicker", "🎨 屏幕取色") (hkPicker != "None" ? " (" hkPicker ")" : "")
    else if ModuleEnabled["Screenshot"]
        tray.Default := T("TrayMenu", "Screenshot", "📷 截图悬浮") (hkScreenshot != "None" ? " (" hkScreenshot ")" : "")
    else if ModuleEnabled["PinWindow"]
        tray.Default := T("TrayMenu", "PinWindow", "📌 置顶窗口") (hkPin != "None" ? " (" hkPin ")" : "")
}

; 切换模块启用状态（从托盘菜单调用）
ToggleModule(key) {
    global ModuleEnabled

    ModuleEnabled[key] := !ModuleEnabled[key]

    ; 保存到配置
    ConfigManager.Set("Modules." key, ModuleEnabled[key] ? "true" : "false")

    moduleName := GetModuleName(key)
    if ModuleEnabled[key]
        ShowNotify("✅ 已启用: " moduleName)
    else
        ShowNotify("⛔ 已禁用: " moduleName)

    ; 重建菜单以更新状态
    SetupTrayMenu()
}

; 模块状态改变回调（从设置面板调用）
OnModuleToggle(states) {
    global ModuleEnabled

    ModuleEnabled["ColorPicker"] := states["ColorPicker"]
    ModuleEnabled["Screenshot"] := states["Screenshot"]
    ModuleEnabled["PinWindow"] := states["PinWindow"]

    ; 重建菜单
    SetupTrayMenu()
}

; 获取模块名称
GetModuleName(key) {
    switch key {
        case "ColorPicker": return "屏幕取色"
        case "Screenshot": return "截图悬浮"
        case "PinWindow": return "置顶窗口"
        default: return key
    }
}

; ---------- 托盘菜单回调 ----------
TrayStartColorPicker(*) {
    global ColorPickerApp, ModuleEnabled
    if !ModuleEnabled["ColorPicker"] {
        ShowNotify("⛔ 屏幕取色已禁用")
        return
    }
    if ColorPickerApp
        ColorPickerApp.Start()
}

TrayShowColorHistory(*) {
    global ColorPickerApp, ModuleEnabled
    if !ModuleEnabled["ColorPicker"] {
        ShowNotify("⛔ 屏幕取色已禁用")
        return
    }
    if ColorPickerApp {
        if !ColorPickerApp.ShowHistory()
            ShowNotify("📋 暂无颜色历史记录")
    }
}

TrayStartScreenshot(*) {
    global ScreenshotApp, ModuleEnabled
    if !ModuleEnabled["Screenshot"] {
        ShowNotify("⛔ 截图悬浮已禁用")
        return
    }
    if ScreenshotApp
        ScreenshotApp.Start()
}

TrayTogglePin(*) {
    global PinWindowApp, ModuleEnabled
    if !ModuleEnabled["PinWindow"] {
        ShowNotify("⛔ 置顶窗口已禁用")
        return
    }
    if PinWindowApp
        PinWindowApp.ToggleCurrent()
}

TrayUnpinAll(*) {
    global PinWindowApp, ModuleEnabled
    if !ModuleEnabled["PinWindow"] {
        ShowNotify("⛔ 置顶窗口已禁用")
        return
    }
    if PinWindowApp {
        count := PinWindowApp.UnpinAll()
        if (count > 0)
            ShowNotify("已取消 " count " 个窗口的置顶")
    }
}

TraySwitchFocus(*) {
    global PinWindowApp, ModuleEnabled
    if !ModuleEnabled["PinWindow"] {
        ShowNotify("⛔ 置顶窗口已禁用")
        return
    }
    if PinWindowApp
        PinWindowApp.SwitchFocus()
}

TrayChangeColor(*) {
    global PinWindowApp, ModuleEnabled
    if !ModuleEnabled["PinWindow"] {
        ShowNotify("⛔ 置顶窗口已禁用")
        return
    }
    if PinWindowApp
        PinWindowApp.ChangeColor()
}

TrayOpenSettings(*) {
    global SettingsWin
    if SettingsWin
        SettingsWin.Show()
}

TrayOpenAbout(*) {
    global AboutDlg
    if AboutDlg
        AboutDlg.Show()
}

TrayReload(*) {
    Reload()
}

TrayExit(*) {
    ExitApp()
}

; =================================================
; 回调函数
; =================================================

OnColorPicked(color, format) {
    A_Clipboard := color
    ShowNotify("已复制: " color)
    Logger.Info("Color picked: " color)
}

OnScreenshotCapture(floatWindow) {
    ShowNotify("截图已创建")
    Logger.Info("Screenshot captured")
}

OnWindowPinned(hwnd, title) {
    ShowNotify("已置顶: " title)
    Logger.Info("Window pinned: " title)
}

OnWindowUnpinned(hwnd, title) {
    ShowNotify("已取消置顶: " title)
    Logger.Info("Window unpinned: " title)
}

ShowNotify(titleOrText, text := "") {
    if (text = "")
        ShowNotification("", titleOrText)
    else
        ShowNotification(titleOrText, text)
}

; =================================================
; 清理
; =================================================
OnExit(ExitCleanup)

ExitCleanup(reason, code) {
    global ColorPickerApp, ScreenshotApp, PinWindowApp
    global SettingsWin, AboutDlg

    Logger.Info("ScriptManager shutting down...")

    ; 销毁实例
    if ColorPickerApp
        ColorPickerApp.Stop()

    if ScreenshotApp
        ScreenshotApp.CloseAllFloats()

    if PinWindowApp
        PinWindowApp.Destroy()

    if SettingsWin
        SettingsWin.Destroy()

    if AboutDlg
        AboutDlg.Destroy()

    ; 关闭 GDI+
    GDIPlus.Shutdown()

    ; 刷新日志缓冲（如果启用了文件日志）
    try Logger.Flush()

    Logger.Info("ScriptManager exited")
    return 0
}
