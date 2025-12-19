; =================================================
; 🖥️ GUI/SettingsWindow.ahk - 设置窗口
; =================================================

#Include ..\Lib\I18n.ahk
#Include ..\Lib\ConfigManager.ahk

class SettingsWindow {
    _gui := ""
    _tabs := ""
    _controls := Map()

    ; 回调
    OnSave := ""
    OnClose := ""
    OnModuleToggle := ""  ; 模块启用状态改变回调

    ; -------------------------------------------------
    ; Show - 显示设置窗口
    ; -------------------------------------------------
    Show() {
        if this._gui {
            this._gui.Show()
            return
        }

        this._CreateWindow()
        this._gui.Show()
    }

    ; -------------------------------------------------
    ; Hide - 隐藏窗口
    ; -------------------------------------------------
    Hide() {
        if this._gui
            this._gui.Hide()
    }

    ; -------------------------------------------------
    ; Destroy - 销毁窗口
    ; -------------------------------------------------
    Destroy() {
        if this._gui {
            this._gui.Destroy()
            this._gui := ""
        }
    }

    ; -------------------------------------------------
    ; 私有方法：创建窗口
    ; -------------------------------------------------
    _CreateWindow() {
        title := T("Settings", "Title", "设置")

        this._gui := Gui("+Resize +MinSize400x300", title)
        this._gui.SetFont("s10", "Microsoft YaHei UI")
        this._gui.OnEvent("Close", (*) => this._OnClose())

        ; 创建标签页
        this._tabs := this._gui.AddTab3("w560 h400", [
            "⚙️ " T("Settings", "General", "常规"),
            "🎨 " T("Settings", "ColorPicker", "取色器"),
            "📷 " T("Settings", "Screenshot", "截图"),
            "📌 " T("Settings", "PinWindow", "置顶窗口")
        ])

        ; 常规设置
        this._tabs.UseTab(1)
        this._CreateGeneralTab()

        ; 取色器设置
        this._tabs.UseTab(2)
        this._CreateColorPickerTab()

        ; 截图设置
        this._tabs.UseTab(3)
        this._CreateScreenshotTab()

        ; 置顶窗口设置
        this._tabs.UseTab(4)
        this._CreatePinWindowTab()

        this._tabs.UseTab()

        ; 底部按钮
        this._gui.AddButton("x380 y420 w80", T("Common", "Save", "保存"))
        .OnEvent("Click", (*) => this._OnSave())
        this._gui.AddButton("x470 y420 w80", T("Common", "Cancel", "取消"))
        .OnEvent("Click", (*) => this._OnClose())
    }

    ; -------------------------------------------------
    ; 私有方法：常规设置标签页
    ; -------------------------------------------------
    _CreateGeneralTab() {
        y := 40

        ; === 模块管理区域 ===
        this._gui.AddGroupBox("x15 y" y " w540 h100", T("Settings", "ModuleManagement", "🔧 模块管理"))
        y += 25

        ; 屏幕取色
        colorPickerChk := this._gui.AddCheckbox("x30 y" y, T("TrayMenu", "ColorPicker", "🎨 屏幕取色") " (Alt+C)")
        colorPickerChk.Value := ConfigManager.Get("Modules", "ColorPicker", "true") = "true"
        this._controls["Module.ColorPicker"] := colorPickerChk

        ; 截图悬浮
        screenshotChk := this._gui.AddCheckbox("x200 y" y, T("TrayMenu", "Screenshot", "📷 截图悬浮") " (Alt+S)")
        screenshotChk.Value := ConfigManager.Get("Modules", "Screenshot", "true") = "true"
        this._controls["Module.Screenshot"] := screenshotChk

        ; 置顶窗口
        pinWindowChk := this._gui.AddCheckbox("x370 y" y, T("TrayMenu", "PinWindow", "📌 置顶窗口") " (Alt+T)")
        pinWindowChk.Value := ConfigManager.Get("Modules", "PinWindow", "true") = "true"
        this._controls["Module.PinWindow"] := pinWindowChk

        y += 35
        this._gui.AddText("x30 y" y " w500 cGray", T("Settings", "ModuleHint", "提示：禁用的模块将不会显示在托盘菜单中，快捷键也会失效"))

        y += 45

        ; === 常规设置区域 ===
        this._gui.AddGroupBox("x15 y" y " w540 h180", T("Settings", "GeneralSettings", "⚙️ 常规设置"))
        y += 25

        ; 语言选择
        this._gui.AddText("x30 y" y, T("Settings", "Language", "界面语言") ":")
        langCtrl := this._gui.AddDropDownList("x130 y" y " w200", ["简体中文", "English"])
        this._controls["Language"] := langCtrl

        currentLang := ConfigManager.Get("General", "Language", "zh-CN")
        langCtrl.Value := (currentLang = "zh-CN") ? 1 : 2

        y += 35

        ; 开机自启
        autoStart := this._gui.AddCheckbox("x30 y" y, T("Settings", "AutoStart", "开机自动启动"))
        autoStart.Value := ConfigManager.Get("General", "AutoStart", "false") = "true"
        this._controls["AutoStart"] := autoStart

        y += 30

        ; 显示托盘提示
        trayTip := this._gui.AddCheckbox("x30 y" y, T("Settings", "ShowTrayTip", "显示托盘提示"))
        trayTip.Value := ConfigManager.Get("General", "ShowTrayTip", "true") = "true"
        this._controls["ShowTrayTip"] := trayTip

        y += 30

        ; 启用提示音
        sound := this._gui.AddCheckbox("x30 y" y, T("Settings", "SoundEnabled", "启用提示音"))
        sound.Value := ConfigManager.Get("General", "SoundEnabled", "true") = "true"
        this._controls["SoundEnabled"] := sound

        y += 50

        ; 底部按钮区域
        this._gui.AddButton("x30 y" y " w120", T("Settings", "CheckUpdate", "🔄 检查更新"))
        .OnEvent("Click", (*) => this._CheckUpdate())

        this._gui.AddButton("x160 y" y " w130", T("Settings", "OpenConfigDir", "📂 打开配置目录"))
        .OnEvent("Click", (*) => Run("explorer.exe " A_ScriptDir "\Config"))
    }

    ; -------------------------------------------------
    ; 私有方法：取色器设置标签页
    ; -------------------------------------------------
    _CreateColorPickerTab() {
        y := 40

        ; 默认格式
        this._gui.AddText("x20 y" y, T("Settings", "DefaultFormat", "默认格式") ":")
        formatCtrl := this._gui.AddDropDownList("x150 y" y " w150", ["HEX", "RGB", "HSL"])
        currentFormat := ConfigManager.Get("ColorPicker", "DefaultFormat", "HEX")
        formatCtrl.Value := (currentFormat = "HEX") ? 1 : (currentFormat = "RGB") ? 2 : 3
        this._controls["ColorPicker.DefaultFormat"] := formatCtrl

        y += 40

        ; 缩放级别
        this._gui.AddText("x20 y" y, T("Settings", "ZoomLevel", "放大倍数") ":")
        zoomCtrl := this._gui.AddSlider("x150 y" y " w200 Range2-16 TickInterval2",
            Integer(ConfigManager.Get("ColorPicker", "ZoomLevel", "8")))
        this._gui.AddText("x360 y" y " w50", "x" zoomCtrl.Value)
        zoomCtrl.OnEvent("Change", (ctrl, *) => ctrl.Gui[""].Value := "x" ctrl.Value)
        this._controls["ColorPicker.ZoomLevel"] := zoomCtrl

        y += 50

        ; 放大镜尺寸
        this._gui.AddText("x20 y" y, T("Settings", "MagnifierSize", "放大镜尺寸") ":")
        sizeCtrl := this._gui.AddEdit("x150 y" y " w80 Number",
            ConfigManager.Get("ColorPicker", "MagnifierSize", "150"))
        this._gui.AddText("x240 y" y, T("Settings", "Pixels", "像素"))
        this._controls["ColorPicker.MagnifierSize"] := sizeCtrl

        y += 40

        ; 显示网格
        gridCtrl := this._gui.AddCheckbox("x20 y" y, T("Settings", "ShowGrid", "显示网格线"))
        gridCtrl.Value := ConfigManager.Get("ColorPicker", "ShowGrid", "true") = "true"
        this._controls["ColorPicker.ShowGrid"] := gridCtrl

        y += 30

        ; 显示十字线
        crossCtrl := this._gui.AddCheckbox("x20 y" y, T("Settings", "ShowCrosshair", "显示十字线"))
        crossCtrl.Value := ConfigManager.Get("ColorPicker", "ShowCrosshair", "true") = "true"
        this._controls["ColorPicker.ShowCrosshair"] := crossCtrl
    }

    ; -------------------------------------------------
    ; 私有方法：截图设置标签页
    ; -------------------------------------------------
    _CreateScreenshotTab() {
        y := 40

        ; 保存路径
        this._gui.AddText("x20 y" y, T("Settings", "SavePath", "保存路径") ":")
        pathCtrl := this._gui.AddEdit("x120 y" y " w350 ReadOnly",
            ConfigManager.Get("Screenshot", "SavePath", A_ScriptDir "\Screenshots"))
        this._gui.AddButton("x480 y" y " w60", T("Settings", "Browse", "浏览..."))
        .OnEvent("Click", (*) => this._BrowseFolder(pathCtrl))
        this._controls["Screenshot.SavePath"] := pathCtrl

        y += 40

        ; 默认格式
        this._gui.AddText("x20 y" y, T("Settings", "DefaultFormat", "图片格式") ":")
        imgFormatCtrl := this._gui.AddDropDownList("x120 y" y " w100", ["PNG", "JPG", "BMP"])
        currentImgFormat := ConfigManager.Get("Screenshot", "DefaultFormat", "PNG")
        imgFormatCtrl.Value := (currentImgFormat = "PNG") ? 1 : (currentImgFormat = "JPG") ? 2 : 3
        this._controls["Screenshot.DefaultFormat"] := imgFormatCtrl

        y += 40

        ; 最大悬浮窗数量
        this._gui.AddText("x20 y" y, T("Settings", "MaxFloats", "最大悬浮窗数量") ":")
        maxFloatsCtrl := this._gui.AddEdit("x150 y" y " w60 Number",
            ConfigManager.Get("Screenshot", "MaxFloats", "20"))
        this._controls["Screenshot.MaxFloats"] := maxFloatsCtrl

        y += 40

        ; 自动复制
        copyCtrl := this._gui.AddCheckbox("x20 y" y, T("Settings", "AutoCopyToClipboard", "截图后自动复制到剪贴板"))
        copyCtrl.Value := ConfigManager.Get("Screenshot", "AutoCopy", "true") = "true"
        this._controls["Screenshot.AutoCopy"] := copyCtrl
    }

    ; -------------------------------------------------
    ; 私有方法：置顶窗口设置标签页
    ; -------------------------------------------------
    _CreatePinWindowTab() {
        y := 40

        ; 边框颜色
        this._gui.AddText("x20 y" y, T("Settings", "BorderThickness", "默认边框颜色") ":")
        colorBtn := this._gui.AddButton("x150 y" y " w100", T("Settings", "SelectColor", "选择颜色..."))
        colorBtn.OnEvent("Click", (*) => this._PickBorderColor())
        this._controls["PinWindow.BorderColor"] := ConfigManager.Get("PinWindow", "BorderColor", "FF0000")

        ; 颜色预览
        this._colorPreview := this._gui.AddText("x260 y" y " w30 h23 Border Background" this._controls[
            "PinWindow.BorderColor"])

        y += 40

        ; 边框粗细
        this._gui.AddText("x20 y" y, T("Settings", "BorderThickness", "边框粗细") ":")
        thicknessCtrl := this._gui.AddSlider("x150 y" y " w200 Range1-10 TickInterval1",
            Integer(ConfigManager.Get("PinWindow", "BorderThickness", "4")))
        pixelsText := T("Settings", "Pixels", "像素")
        this._gui.AddText("x360 y" y " w50 vThicknessLabel", thicknessCtrl.Value " " pixelsText)
        thicknessCtrl.OnEvent("Change", ((p) => (ctrl, *) => ctrl.Gui["ThicknessLabel"].Value := ctrl.Value " " p)(
            pixelsText))
        this._controls["PinWindow.BorderThickness"] := thicknessCtrl

        y += 50

        ; 闪烁次数
        this._gui.AddText("x20 y" y, T("Settings", "FlashCount", "置顶时闪烁次数") ":")
        flashCountCtrl := this._gui.AddEdit("x150 y" y " w60 Number",
            ConfigManager.Get("PinWindow", "FlashCount", "3"))
        this._gui.AddText("x215 y" y, T("Settings", "Times", "次"))
        this._controls["PinWindow.FlashCount"] := flashCountCtrl

        y += 40

        ; 启用提示音
        soundCtrl := this._gui.AddCheckbox("x20 y" y, T("Settings", "EnablePinSound", "置顶/取消置顶时播放提示音"))
        soundCtrl.Value := ConfigManager.Get("PinWindow", "SoundEnabled", "true") = "true"
        this._controls["PinWindow.SoundEnabled"] := soundCtrl
    }

    ; -------------------------------------------------
    ; 私有方法：浏览文件夹
    ; -------------------------------------------------
    _BrowseFolder(pathCtrl) {
        folder := DirSelect(, , T("Settings", "SavePath", "选择截图保存路径"))
        if (folder != "")
            pathCtrl.Value := folder
    }

    ; -------------------------------------------------
    ; 私有方法：选择边框颜色
    ; -------------------------------------------------
    _PickBorderColor() {
        ; 简单的颜色选择（使用预设颜色）
        colors := ["FF0000", "00FF00", "0000FF", "FFFF00", "FF00FF", "00FFFF", "FFA500", "800080"]
        colorMenu := Menu()

        for color in colors {
            colorMenu.Add("██ #" color, ((c) => (*) => this._SetBorderColor(c))(color))
        }

        colorMenu.Show()
    }

    _SetBorderColor(color) {
        this._controls["PinWindow.BorderColor"] := color
        this._colorPreview.Opt("Background" color)
    }

    ; -------------------------------------------------
    ; 私有方法：检查更新
    ; -------------------------------------------------
    _CheckUpdate() {
        ; 调用 AboutDialog 的检查更新（如果有）
        MsgBox("正在检查更新...", "检查更新")
        Run("https://github.com/Leezgion/AutoHotkey-Scripts-Collection/releases")
    }

    ; -------------------------------------------------
    ; 私有方法：保存设置
    ; -------------------------------------------------
    _OnSave() {
        ; 模块启用设置
        moduleColorPicker := this._controls["Module.ColorPicker"].Value ? "true" : "false"
        moduleScreenshot := this._controls["Module.Screenshot"].Value ? "true" : "false"
        modulePinWindow := this._controls["Module.PinWindow"].Value ? "true" : "false"

        ConfigManager.Set("Modules.ColorPicker", moduleColorPicker)
        ConfigManager.Set("Modules.Screenshot", moduleScreenshot)
        ConfigManager.Set("Modules.PinWindow", modulePinWindow)

        ; 触发模块状态回调
        if this.OnModuleToggle {
            callback := this.OnModuleToggle
            callback(Map(
                "ColorPicker", moduleColorPicker = "true",
                "Screenshot", moduleScreenshot = "true",
                "PinWindow", modulePinWindow = "true"
            ))
        }

        ; 常规设置
        langCtrl := this._controls["Language"]
        newLang := langCtrl.Value = 1 ? "zh-CN" : "en-US"
        ConfigManager.Set("General.Language", newLang)
        ConfigManager.Set("General.AutoStart", this._controls["AutoStart"].Value ? "true" : "false")
        ConfigManager.Set("General.ShowTrayTip", this._controls["ShowTrayTip"].Value ? "true" : "false")
        ConfigManager.Set("General.SoundEnabled", this._controls["SoundEnabled"].Value ? "true" : "false")

        ; 取色器设置
        formats := ["HEX", "RGB", "HSL"]
        ConfigManager.Set("ColorPicker.DefaultFormat", formats[this._controls["ColorPicker.DefaultFormat"].Value])
        ConfigManager.Set("ColorPicker.ZoomLevel", String(this._controls["ColorPicker.ZoomLevel"].Value))
        ConfigManager.Set("ColorPicker.MagnifierSize", this._controls["ColorPicker.MagnifierSize"].Value)
        ConfigManager.Set("ColorPicker.ShowGrid", this._controls["ColorPicker.ShowGrid"].Value ? "true" : "false")
        ConfigManager.Set("ColorPicker.ShowCrosshair", this._controls["ColorPicker.ShowCrosshair"].Value ? "true" :
            "false")

        ; 截图设置
        ConfigManager.Set("Screenshot.SavePath", this._controls["Screenshot.SavePath"].Value)
        imgFormats := ["PNG", "JPG", "BMP"]
        ConfigManager.Set("Screenshot.DefaultFormat", imgFormats[this._controls["Screenshot.DefaultFormat"].Value])
        ConfigManager.Set("Screenshot.MaxFloats", this._controls["Screenshot.MaxFloats"].Value)
        ConfigManager.Set("Screenshot.AutoCopy", this._controls["Screenshot.AutoCopy"].Value ? "true" : "false")

        ; 置顶窗口设置
        ConfigManager.Set("PinWindow.BorderColor", this._controls["PinWindow.BorderColor"])
        ConfigManager.Set("PinWindow.BorderThickness", String(this._controls["PinWindow.BorderThickness"].Value))
        ConfigManager.Set("PinWindow.FlashCount", this._controls["PinWindow.FlashCount"].Value)
        ConfigManager.Set("PinWindow.SoundEnabled", this._controls["PinWindow.SoundEnabled"].Value ? "true" : "false")

        ; 切换语言
        langChanged := false
        if (newLang != I18n.GetLanguage()) {
            I18n.SetLanguage(newLang)
            langChanged := true
        }

        ; 触发回调
        if this.OnSave {
            callback := this.OnSave
            callback()
        }

        ; 如果语言改变了，提示重启
        if langChanged {
            this.Hide()
            result := MsgBox(
                T("Settings", "LanguageChangeRestart", "语言已更改。是否立即重启应用以应用新语言？"),
                T("Settings", "Title", "设置"),
                "YesNo Icon?"
            )
            if (result = "Yes")
                Reload()
        } else {
            ShowNotification("✅", T("Settings", "SaveSuccess", "设置已保存"))
            this.Hide()
        }
    }

    ; -------------------------------------------------
    ; 私有方法：关闭窗口
    ; -------------------------------------------------
    _OnClose() {
        if this.OnClose {
            callback := this.OnClose
            callback()
        }
        this.Hide()
    }
}
