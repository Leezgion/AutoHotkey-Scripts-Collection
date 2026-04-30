; =================================================
; 🖥️ GUI/SettingsWindow.ahk - 设置窗口
; =================================================

#Include ..\Lib\I18n.ahk
#Include ..\Lib\ConfigManager.ahk
#Include ..\Lib\Hotkeys.ahk

class SettingsWindow {
    _gui := ""
    _tabs := ""
    _controls := Map()

    _btnSave := ""
    _btnCancel := ""

    ; Hotkeys tab state
    _hkLv := ""
    _hkEdit := ""
    _hkSelectedRow := 0
    _hkSelectedKeyPath := ""

    ; 回调
    OnSave := ""
    OnClose := ""
    OnModuleToggle := ""  ; 模块启用状态改变回调

    ; -------------------------------------------------
    ; Show - 显示设置窗口
    ; -------------------------------------------------
    Show() {
        if this._gui {
            this._RefreshModuleHotkeyLabels()
            this._RefreshHotkeysList()
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
        this._gui.OnEvent("Size", (gui, minMax, w, h) => this._OnResize(w, h, minMax))

        ; 创建标签页
        this._tabs := this._gui.AddTab3("w560 h400", [
            "⚙️ " T("Settings", "General", "常规"),
            "🎨 " T("Settings", "ColorPicker", "取色器"),
            "📷 " T("Settings", "Screenshot", "截图"),
            "📌 " T("Settings", "PinWindow", "置顶窗口"),
            "⌨️ " T("Settings", "Hotkeys", "快捷键")
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

        ; 快捷键
        this._tabs.UseTab(5)
        this._CreateHotkeysTab()

        this._tabs.UseTab()

        ; 底部按钮
        this._btnSave := this._gui.AddButton("x380 y420 w80", T("Common", "Save", "保存"))
        this._btnSave.OnEvent("Click", (*) => this._OnSave())
        this._btnCancel := this._gui.AddButton("x470 y420 w80", T("Common", "Cancel", "取消"))
        this._btnCancel.OnEvent("Click", (*) => this._OnClose())

        ; 初次布局（确保创建后立即适配当前窗口大小）
        try this._OnResize(this._gui.ClientPos.W, this._gui.ClientPos.H, 0)
    }

    ; -------------------------------------------------
    ; 私有方法：响应窗口大小变化
    ; -------------------------------------------------
    _OnResize(w, h, minMax := 0) {
        if (!this._gui || !this._tabs)
            return

        ; 1) Tab 区域填充
        marginX := 10
        marginTop := 10
        bottomAreaH := 55
        tabW := Max(200, w - marginX * 2)
        tabH := Max(120, h - marginTop - bottomAreaH)
        try this._tabs.Move(marginX, marginTop, tabW, tabH)

        ; 2) 底部按钮固定右下
        btnW := 80
        btnY := h - 35
        try this._btnSave.Move(w - (btnW * 2) - 20, btnY)
        try this._btnCancel.Move(w - btnW - 10, btnY)

        ; 3) Screenshot tab: 保存路径 Edit 拉伸，浏览按钮贴右
        if (this._controls.Has("Screenshot.SavePath") && this._controls.Has("Screenshot.BrowseBtn")) {
            editX := 120
            browseW := 60
            browseX := w - marginX - browseW
            editW := Max(120, browseX - 10 - editX)
            try this._controls["Screenshot.SavePath"].Move(editX, , editW)
            try this._controls["Screenshot.BrowseBtn"].Move(browseX)
        }

        ; 4) Hotkeys tab: ListView/编辑区随高度与宽度变化
        if (this._hkLv) {
            lvX := 20
            lvY := 65
            lvW := Max(200, w - lvX * 2)
            lvH := Max(120, h - lvY - 130)
            try this._hkLv.Move(lvX, lvY, lvW, lvH)

            ; 编辑区固定在 ListView 下方
            grpX := 15
            grpY := lvY + lvH + 10
            grpW := Max(200, w - grpX * 2)
            grpH := 60
            if (this.HasProp("_hkGroupEdit") && this._hkGroupEdit)
                try this._hkGroupEdit.Move(grpX, grpY, grpW, grpH)

            if (this._controls.Has("Hotkeys.Selected")) {
                ; 左侧“已选”文本
                try this._controls["Hotkeys.Selected"].Move(90, grpY + 25)
            }

            ; 右侧录制输入框（跟随右侧，宽度自适应）
            if (this._hkEdit && this._hkEdit.Control) {
                editW := 180
                editX := w - marginX - editW - 100
                editX := Max(200, editX)
                try this._hkEdit.Control.Move(editX, grpY + 22, editW)
            }
        }
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
        colorPickerLabel := T("TrayMenu", "ColorPicker", "🎨 屏幕取色")
        colorPickerHk := HotkeyManager.GetDisplayText("picker.start")
        colorPickerChk := this._gui.AddCheckbox("x30 y" y, colorPickerLabel (colorPickerHk != "None" ? " (" colorPickerHk ")" : ""))
        colorPickerChk.Value := ConfigManager.Get("Modules", "ColorPicker", "true") = "true"
        this._controls["Module.ColorPicker"] := colorPickerChk

        ; 截图悬浮
        screenshotLabel := T("TrayMenu", "Screenshot", "📷 截图悬浮")
        screenshotHk := HotkeyManager.GetDisplayText("screenshot.start")
        screenshotChk := this._gui.AddCheckbox("x200 y" y, screenshotLabel (screenshotHk != "None" ? " (" screenshotHk ")" : ""))
        screenshotChk.Value := ConfigManager.Get("Modules", "Screenshot", "true") = "true"
        this._controls["Module.Screenshot"] := screenshotChk

        ; 置顶窗口
        pinWindowLabel := T("TrayMenu", "PinWindow", "📌 置顶窗口")
        pinWindowHk := HotkeyManager.GetDisplayText("pin.toggle")
        pinWindowChk := this._gui.AddCheckbox("x370 y" y, pinWindowLabel (pinWindowHk != "None" ? " (" pinWindowHk ")" : ""))
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
        browseBtn := this._gui.AddButton("x480 y" y " w60", T("Settings", "Browse", "浏览..."))
        browseBtn.OnEvent("Click", (*) => this._BrowseFolder(pathCtrl))
        this._controls["Screenshot.SavePath"] := pathCtrl
        this._controls["Screenshot.BrowseBtn"] := browseBtn

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
    ; 私有方法：快捷键标签页
    ; -------------------------------------------------
    _CreateHotkeysTab() {
        y := 40

        this._gui.AddText(
            "x20 y" y " w520 cGray",
            T("Settings", "HotkeyHint", "提示：选择一项后点击输入框录制新的快捷键；部分功能内快捷键需要重新打开功能后生效")
        )
        y += 25

        this._hkLv := this._gui.AddListView(
            "x20 y" y " w520 h280 -Multi",
            [
                T("Settings", "HotkeyAction", "功能"),
                T("Settings", "HotkeyBinding", "快捷键"),
                T("Settings", "HotkeyKey", "键名")
            ]
        )
        this._hkLv.OnEvent("ItemSelect", (lv, row, selected) => this._OnHotkeyRowSelected(lv, row, selected))
        this._hkLv.ModifyCol(1, 220)
        this._hkLv.ModifyCol(2, 120)
        this._hkLv.ModifyCol(3, 160)

        y += 295

        this._hkGroupEdit := this._gui.AddGroupBox("x15 y" y " w540 h60", T("Settings", "HotkeyEdit", "编辑"))
        this._gui.AddText(
            "x30 y" (y + 25) " w100",
            T("Settings", "Selected", "已选") ":"
        )
        this._controls["Hotkeys.Selected"] := this._gui.AddText("x90 y" (y + 25) " w190", "-")

        ; 录制输入框（按当前选中项创建）
        this._CreateOrReplaceHotkeyEditor("")

        ; 填充列表并默认选中第一项
        this._RefreshHotkeysList(true)
    }

    _OnHotkeyRowSelected(lv, row, selected) {
        if (!selected || row <= 0)
            return

        keyPath := lv.GetText(row, 3)
        if (!keyPath) {
            this._hkSelectedRow := 0
            this._hkSelectedKeyPath := ""
            this._controls["Hotkeys.Selected"].Value := "-"
            this._CreateOrReplaceHotkeyEditor("")
            return
        }

        this._hkSelectedRow := row
        this._hkSelectedKeyPath := keyPath

        ; 更新“已选”文本
        this._controls["Hotkeys.Selected"].Value := keyPath

        this._CreateOrReplaceHotkeyEditor(keyPath)
    }

    _CreateOrReplaceHotkeyEditor(keyPath) {
        ; 销毁旧控件
        if (this._hkEdit && this._hkEdit.Control) {
            try this._hkEdit.Control.Destroy()
        }

        ; 未选中时也创建一个禁用占位控件，保持布局稳定
        editOptions := "x290 y" 360 " w160"
        if (!keyPath) {
            placeholder := this._gui.AddEdit(editOptions " ReadOnly", "-")
            placeholder.Enabled := false
            this._hkEdit := { Control: placeholder }
            return
        }

        this._hkEdit := HotkeyEdit(this._gui, keyPath, editOptions)
        this._hkEdit.OnChange((k, hk) => this._OnHotkeyChanged(k, hk))
    }

    _OnHotkeyChanged(keyPath, hotkey) {
        ; 更新列表中当前行显示
        if (this._hkLv && this._hkSelectedRow > 0) {
            display := HotkeyManager.FormatHotkey(hotkey)
            actionText := this._hkLv.GetText(this._hkSelectedRow, 1)
            this._hkLv.Modify(this._hkSelectedRow, , actionText, display, keyPath)
        }

        ; 同步更新常规页里模块勾选框旁的热键文本
        this._RefreshModuleHotkeyLabels()
    }

    _RefreshHotkeysList(selectFirst := false) {
        if (!this._hkLv)
            return

        this._hkLv.Delete()
        this._hkSelectedRow := 0
        this._hkSelectedKeyPath := ""
        if this._controls.Has("Hotkeys.Selected")
            this._controls["Hotkeys.Selected"].Value := "-"

        ; 1) Global/registered hotkeys (editable, immediate)
        this._hkLv.Add("", "— " T("Settings", "HotkeysGlobal", "全局快捷键（可修改）") " —", "", "")

        allHotkeys := HotkeyManager.GetAllHotkeys()
        for keyPath, info in allHotkeys {
            actionText := info.HasProp("context") && info.context != "" ? (info.context ": " keyPath) : keyPath
            this._hkLv.Add("", actionText, info.displayText, keyPath)
        }

        ; 2) In-feature hotkeys (config-driven, may require reopening feature)
        this._hkLv.Add("", "— " T("Settings", "HotkeysFeature", "功能内快捷键（可修改）") " —", "", "")

        featureKeys := [
            { keyPath: "ColorPicker.Copy", action: "ColorPicker: " T("Settings", "Hotkey_CopyColor", "复制颜色") },
            { keyPath: "ColorPicker.SwitchFormat", action: "ColorPicker: " T("Settings", "Hotkey_SwitchFormat", "切换格式") },
            { keyPath: "ColorPicker.ZoomIn", action: "ColorPicker: " T("Settings", "Hotkey_ZoomIn", "放大") },
            { keyPath: "ColorPicker.ZoomOut", action: "ColorPicker: " T("Settings", "Hotkey_ZoomOut", "缩小") },
            { keyPath: "ColorPicker.Cancel", action: "ColorPicker: " T("Settings", "Hotkey_Cancel", "取消") },

            { keyPath: "Screenshot.Cancel", action: "Screenshot: " T("Settings", "Hotkey_Cancel", "取消选区") },
            { keyPath: "Screenshot.CopyToClipboard", action: "Float: " T("Settings", "Hotkey_Copy", "复制到剪贴板") },
            { keyPath: "Screenshot.SaveToFile", action: "Float: " T("Settings", "Hotkey_Save", "保存到文件") },
            { keyPath: "Screenshot.FloatZoomIn", action: "Float: " T("Settings", "Hotkey_FloatZoomIn", "放大") },
            { keyPath: "Screenshot.FloatZoomOut", action: "Float: " T("Settings", "Hotkey_FloatZoomOut", "缩小") },
            { keyPath: "Screenshot.IncreaseOpacity", action: "Float: " T("Settings", "Hotkey_OpacityUp", "增加透明度") },
            { keyPath: "Screenshot.DecreaseOpacity", action: "Float: " T("Settings", "Hotkey_OpacityDown", "减少透明度") },
            { keyPath: "Screenshot.CloseFloat", action: "Float: " T("Settings", "Hotkey_Close", "关闭悬浮窗") }
        ]

        for item in featureKeys {
            hk := ConfigManager.GetHotkey(item.keyPath)
            this._hkLv.Add("", item.action, HotkeyManager.FormatHotkey(hk), item.keyPath)
        }

        ; 3) Fixed in-feature actions (read-only)
        this._hkLv.Add("", "— " T("Settings", "HotkeysFixed", "功能内快捷键（固定）") " —", "", "")
        this._hkLv.Add("", "Screenshot: " T("Settings", "Hotkey_Confirm", "左键确认选区"), HotkeyManager.FormatHotkey("LButton"), "")
        this._hkLv.Add("", "Float: " T("Settings", "Hotkey_Close", "右键关闭悬浮窗"), HotkeyManager.FormatHotkey("RButton"), "")

        if (selectFirst && this._hkLv.GetCount() > 1) {
            this._hkLv.Modify(2, "Select Focus Vis")
            this._OnHotkeyRowSelected(this._hkLv, 2, true)
        } else {
            this._CreateOrReplaceHotkeyEditor("")
        }
    }

    _RefreshModuleHotkeyLabels() {
        ; These labels appear on the General tab next to module toggles
        if (!this._controls.Has("Module.ColorPicker") || !this._controls.Has("Module.Screenshot") || !this._controls.Has("Module.PinWindow"))
            return

        colorPickerLabel := T("TrayMenu", "ColorPicker", "🎨 屏幕取色")
        screenshotLabel := T("TrayMenu", "Screenshot", "📷 截图悬浮")
        pinWindowLabel := T("TrayMenu", "PinWindow", "📌 置顶窗口")

        colorPickerHk := HotkeyManager.GetDisplayText("picker.start")
        screenshotHk := HotkeyManager.GetDisplayText("screenshot.start")
        pinWindowHk := HotkeyManager.GetDisplayText("pin.toggle")

        try this._controls["Module.ColorPicker"].Text := colorPickerLabel (colorPickerHk != "None" ? " (" colorPickerHk ")" : "")
        try this._controls["Module.Screenshot"].Text := screenshotLabel (screenshotHk != "None" ? " (" screenshotHk ")" : "")
        try this._controls["Module.PinWindow"].Text := pinWindowLabel (pinWindowHk != "None" ? " (" pinWindowHk ")" : "")
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
