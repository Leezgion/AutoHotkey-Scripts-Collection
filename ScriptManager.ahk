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
#Include Lib\ConfigManager.ahk
#Include Lib\GDIPlus.ahk
#Include Lib\I18n.ahk
#Include Lib\Logger.ahk
#Include Lib\Utils.ahk

; ---------- 引入功能模块 ----------
#Include Modules\ColorPicker\Picker.ahk
#Include Modules\Screenshot\Capture.ahk
#Include Modules\PinWindow\Pin.ahk

; ---------- 引入 GUI ----------
#Include GUI\MainWindow.ahk
#Include GUI\SettingsWindow.ahk
#Include GUI\AboutDialog.ahk

; ---------- 全局实例 ----------
global ColorPickerApp := ""
global ScreenshotApp := ""
global PinWindowApp := ""
global MainWin := ""
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
    global MainWin, SettingsWin, AboutDlg
    global ModuleEnabled

    ; 初始化 GDI+
    GDIPlus.Startup()

    ; 初始化日志
    Logger.Init("INFO", false)
    Logger.Info("ScriptManager starting...")

    ; 初始化国际化
    I18n.Init()

    ; 从配置读取模块启用状态
    ModuleEnabled["ColorPicker"] := ConfigManager.Get("Modules", "ColorPicker", "true") = "true"
    ModuleEnabled["Screenshot"] := ConfigManager.Get("Modules", "Screenshot", "true") = "true"
    ModuleEnabled["PinWindow"] := ConfigManager.Get("Modules", "PinWindow", "true") = "true"

    ; 创建取色器
    ColorPickerApp := ColorPicker()
    ColorPickerApp.OnColorPicked := OnColorPicked
    ColorPickerApp.OnNotify := ShowNotify

    ; 创建截图工具
    screenshotConfig := {
        ScreenshotFolder: Paths.Screenshots,
        DefaultFormat: "PNG",
        AutoCopy: true
    }
    ScreenshotApp := ScreenCapture(screenshotConfig)
    ScreenshotApp.OnCapture := OnScreenshotCapture
    ScreenshotApp.OnNotify := ShowNotify

    ; 确保截图目录存在
    if !DirExist(Paths.Screenshots)
        DirCreate(Paths.Screenshots)

    ; 创建置顶工具（使用 Constants.ahk 的默认值）
    PinWindowApp := WindowPinner()
    PinWindowApp.OnPin := OnWindowPinned
    PinWindowApp.OnUnpin := OnWindowUnpinned
    PinWindowApp.OnNotify := ShowNotify

    ; 创建关于对话框
    AboutDlg := AboutDialog()

    ; 创建设置窗口
    SettingsWin := SettingsWindow()
    SettingsWin.OnModuleToggle := OnModuleToggle

    ; 设置托盘菜单
    SetupTrayMenu()

    Logger.Info("ScriptManager initialized successfully")
}

; =================================================
; 托盘菜单
; =================================================
SetupTrayMenu() {
    global ModuleEnabled

    ; 设置托盘图标和提示
    A_IconTip := AppInfo.Name " v" AppInfo.Version

    ; 创建托盘菜单
    tray := A_TrayMenu
    tray.Delete()  ; 清除默认菜单

    ; 功能菜单 - 根据启用状态显示
    if ModuleEnabled["ColorPicker"]
        tray.Add(T("TrayMenu", "ColorPicker", "🎨 屏幕取色") " (Alt+C)", TrayStartColorPicker)
    if ModuleEnabled["Screenshot"]
        tray.Add(T("TrayMenu", "Screenshot", "📷 截图悬浮") " (Alt+S)", TrayStartScreenshot)
    if ModuleEnabled["PinWindow"]
        tray.Add(T("TrayMenu", "PinWindow", "📌 置顶窗口") " (Alt+T)", TrayTogglePin)

    ; 只有当有启用的模块时才添加分隔线
    if (ModuleEnabled["ColorPicker"] || ModuleEnabled["Screenshot"] || ModuleEnabled["PinWindow"])
        tray.Add()  ; 分隔线

    ; 取色器子菜单 - 只在启用时显示
    if ModuleEnabled["ColorPicker"] {
        colorSubMenu := Menu()
        colorSubMenu.Add(T("TrayMenu", "StartPicking", "🎨 开始取色 (Alt+C)"), TrayStartColorPicker)
        colorSubMenu.Add(T("TrayMenu", "ColorHistory", "📋 颜色历史记录"), TrayShowColorHistory)
        tray.Add(T("TrayMenu", "ColorPickerMenu", "取色器"), colorSubMenu)
    }

    ; 置顶窗口子菜单 - 只在启用时显示
    if ModuleEnabled["PinWindow"] {
        pinSubMenu := Menu()
        pinSubMenu.Add(T("TrayMenu", "UnpinAll", "取消所有置顶 (Alt+Shift+T)"), TrayUnpinAll)
        pinSubMenu.Add(T("TrayMenu", "SwitchFocus", "切换焦点"), TraySwitchFocus)
        pinSubMenu.Add(T("TrayMenu", "ChangeBorderColor", "更改边框颜色 (Alt+Shift+C)"), TrayChangeColor)
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
        tray.Default := T("TrayMenu", "ColorPicker", "🎨 屏幕取色") " (Alt+C)"
    else if ModuleEnabled["Screenshot"]
        tray.Default := T("TrayMenu", "Screenshot", "📷 截图悬浮") " (Alt+S)"
    else if ModuleEnabled["PinWindow"]
        tray.Default := T("TrayMenu", "PinWindow", "📌 置顶窗口") " (Alt+T)"
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
; 快捷键定义
; =================================================

; Alt + C: 屏幕取色
!c:: {
    global ColorPickerApp, ModuleEnabled
    if !ModuleEnabled["ColorPicker"]
        return
    if ColorPickerApp
        ColorPickerApp.Start()
}

; Alt + S: 截图
!s:: {
    global ScreenshotApp, ModuleEnabled
    if !ModuleEnabled["Screenshot"]
        return
    if ScreenshotApp
        ScreenshotApp.Start()
}

; Alt + T: 切换当前窗口置顶
!t:: {
    global PinWindowApp, ModuleEnabled
    if !ModuleEnabled["PinWindow"]
        return
    if PinWindowApp
        PinWindowApp.ToggleCurrent()
}

; Alt + Shift + T: 取消所有置顶
!+t:: {
    global PinWindowApp, ModuleEnabled
    if !ModuleEnabled["PinWindow"]
        return
    if PinWindowApp {
        count := PinWindowApp.UnpinAll()
        if (count > 0)
            ShowNotify("已取消 " count " 个窗口的置顶")
        else
            ShowNotify("没有置顶的窗口")
    }
}

; Alt + Shift + C: 更改边框颜色
!+c:: {
    global PinWindowApp, ModuleEnabled
    if !ModuleEnabled["PinWindow"]
        return
    if PinWindowApp
        PinWindowApp.ChangeColor()
}

; Ctrl + Alt + A: 关闭所有悬浮窗
^!a:: {
    global ScreenshotApp, ModuleEnabled
    if !ModuleEnabled["Screenshot"]
        return
    if ScreenshotApp
        ScreenshotApp.CloseAllFloats()
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

ShowNotify(text) {
    ShowNotification("", text)
}

; =================================================
; 清理
; =================================================
OnExit(ExitCleanup)

ExitCleanup(reason, code) {
    global ColorPickerApp, ScreenshotApp, PinWindowApp
    global MainWin, SettingsWin, AboutDlg

    Logger.Info("ScriptManager shutting down...")

    ; 销毁实例
    if ColorPickerApp
        ColorPickerApp.Stop()

    if ScreenshotApp
        ScreenshotApp.CloseAllFloats()

    if PinWindowApp
        PinWindowApp.Destroy()

    if MainWin
        MainWin.Destroy()

    if SettingsWin
        SettingsWin.Destroy()

    if AboutDlg
        AboutDlg.Destroy()

    ; 关闭 GDI+
    GDIPlus.Shutdown()

    Logger.Info("ScriptManager exited")
    return 0
}
