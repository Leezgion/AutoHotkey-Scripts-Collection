; =================================================
; 🎛️ MainWindow.ahk - 脚本管理器主界面
; =================================================
; 功能：
;   - 脚本列表展示与管理
;   - 快捷操作按钮
;   - 状态显示
;   - 设置入口
; =================================================

#Include "%A_ScriptDir%\Lib\Constants.ahk"
#Include "%A_ScriptDir%\Lib\ConfigManager.ahk"
#Include "%A_ScriptDir%\Lib\Hotkeys.ahk"
#Include "%A_ScriptDir%\Lib\i18n.ahk"
#Include "%A_ScriptDir%\Lib\Theme.ahk"

; -------------------------------------------------
; 🖼️ 主窗口类
; -------------------------------------------------
class MainWindow {
    ; GUI 组件
    _gui := ""
    _tabControl := ""
    _scriptListView := ""
    _statusBar := ""

    ; 按钮
    _btnStartAll := ""
    _btnStopAll := ""
    _btnReloadAll := ""
    _btnRefresh := ""
    _btnSettings := ""

    ; 状态
    _visible := false
    _scriptData := []

    ; 回调函数（供外部绑定）
    onRefresh := ""
    onStartAll := ""
    onStopAll := ""
    onReloadAll := ""
    onStartScript := ""
    onStopScript := ""
    onReloadScript := ""
    onToggleAutoStart := ""
    onToggleScript := ""

    ; 窗口尺寸
    static Width := 600
    static Height := 500

    ; -------------------------------------------------
    ; __New - 构造函数
    ; -------------------------------------------------
    __New() {
        this._CreateGui()
    }

    ; -------------------------------------------------
    ; _CreateGui - 创建 GUI
    ; -------------------------------------------------
    _CreateGui() {
        ; 创建主窗口
        this._gui := Gui("+Resize +MinSize500x400", T("app.title") " v" AppInfo.Version)
        ThemeManager.ApplyToGui(this._gui)

        gui := this._gui

        ; ----- 顶部标题区域 -----
        gui.SetFont("s16 Bold c" Theme.FgPrimary, "Segoe UI")
        gui.AddText("x20 y15 w400", "🎛️ " T("app.name"))

        gui.SetFont("s9 c" Theme.FgMuted, "Segoe UI")
        gui.AddText("x20 y45 w400", T("app.version", AppInfo.Version))

        ; ----- 选项卡控件 -----
        gui.SetFont("s10 c" Theme.FgPrimary, "Segoe UI")
        this._tabControl := gui.AddTab3("x15 y75 w570 h340", [
            "📜 " T("menu.scripts"),
            "⌨️ " T("settings.hotkeys"),
            "⚙️ " T("settings.general"),
            "ℹ️ " T("menu.about")
        ])

        ; ===== Tab 1: 脚本控制 =====
        this._tabControl.UseTab(1)
        this._CreateScriptsTab()

        ; ===== Tab 2: 快捷键 =====
        this._tabControl.UseTab(2)
        this._CreateHotkeysTab()

        ; ===== Tab 3: 设置 =====
        this._tabControl.UseTab(3)
        this._CreateSettingsTab()

        ; ===== Tab 4: 关于 =====
        this._tabControl.UseTab(4)
        this._CreateAboutTab()

        ; 切换回第一个选项卡
        this._tabControl.UseTab()

        ; ----- 状态栏 -----
        this._statusBar := gui.AddStatusBar()
        this._statusBar.SetParts(200, 150, 100)
        this._UpdateStatusBar()

        ; ----- 事件绑定 -----
        gui.OnEvent("Close", (*) => this.Hide())
        gui.OnEvent("Size", (*) => this._OnResize())
    }

    ; -------------------------------------------------
    ; _CreateScriptsTab - 创建脚本管理选项卡
    ; -------------------------------------------------
    _CreateScriptsTab() {
        gui := this._gui

        ; 脚本列表
        gui.SetFont("s10 c" Theme.FgPrimary, "Segoe UI")
        this._scriptListView := gui.AddListView(
            "x25 y110 w550 h200 +Grid +NoSortHdr +LV0x10000 +Background" Theme.BgSecondary,
            ["", "脚本名称", "状态", "自启动", "操作"]
        )

        ; 设置列宽
        this._scriptListView.ModifyCol(1, 30)   ; 图标
        this._scriptListView.ModifyCol(2, 200)  ; 名称
        this._scriptListView.ModifyCol(3, 80)   ; 状态
        this._scriptListView.ModifyCol(4, 70)   ; 自启动
        this._scriptListView.ModifyCol(5, 150)  ; 操作

        ; 列表事件
        this._scriptListView.OnEvent("DoubleClick", (*) => this._OnScriptDoubleClick())

        ; 快捷操作按钮
        btnY := 320
        btnW := 100
        btnH := 30

        this._btnStartAll := gui.AddButton("x25 y" btnY " w" btnW " h" btnH, "▶ " T("action.startAll"))
        this._btnStartAll.OnEvent("Click", (*) => this._OnStartAll())

        this._btnStopAll := gui.AddButton("x+10 y" btnY " w" btnW " h" btnH, "⏹ " T("action.stopAll"))
        this._btnStopAll.OnEvent("Click", (*) => this._OnStopAll())

        this._btnReloadAll := gui.AddButton("x+10 y" btnY " w" btnW " h" btnH, "🔄 " T("action.reloadAll"))
        this._btnReloadAll.OnEvent("Click", (*) => this._OnReloadAll())

        this._btnRefresh := gui.AddButton("x+80 y" btnY " w80 h" btnH, "🔄 " T("menu.refresh"))
        this._btnRefresh.OnEvent("Click", (*) => this._RefreshScriptList())

        ; 单脚本操作按钮（在列表下方）
        btnY2 := 360

        gui.AddText("x25 y" btnY2 " w60 h25 +0x200 c" Theme.FgSecondary, "选中脚本:")

        this._btnStart := gui.AddButton("x90 y" btnY2 " w70 h25", "▶ 启动")
        this._btnStart.OnEvent("Click", (*) => this._OnStartSelected())

        this._btnStop := gui.AddButton("x+5 y" btnY2 " w70 h25", "⏹ 停止")
        this._btnStop.OnEvent("Click", (*) => this._OnStopSelected())

        this._btnReload := gui.AddButton("x+5 y" btnY2 " w70 h25", "🔄 重载")
        this._btnReload.OnEvent("Click", (*) => this._OnReloadSelected())

        this._btnAutoStart := gui.AddButton("x+5 y" btnY2 " w90 h25", "🚀 切换自启")
        this._btnAutoStart.OnEvent("Click", (*) => this._OnToggleAutoStart())

        this._btnOpenFolder := gui.AddButton("x+20 y" btnY2 " w90 h25", "📂 打开目录")
        this._btnOpenFolder.OnEvent("Click", (*) => this._OnOpenFolder())
    }

    ; -------------------------------------------------
    ; _CreateHotkeysTab - 创建快捷键选项卡
    ; -------------------------------------------------
    _CreateHotkeysTab() {
        gui := this._gui

        ; 说明文字
        gui.SetFont("s9 c" Theme.FgMuted, "Segoe UI")
        gui.AddText("x25 y110 w530", "点击输入框后按下新的快捷键组合来修改。支持 Ctrl、Alt、Shift、Win 修饰键。")

        gui.SetFont("s10 c" Theme.FgPrimary, "Segoe UI")

        startY := 145
        rowH := 35
        labelW := 150
        editW := 180
        btnW := 60

        ; ----- 屏幕取色 -----
        gui.SetFont("s10 Bold c" Theme.FgAccent, "Segoe UI")
        gui.AddText("x25 y" startY " w" labelW " h25", "🎨 屏幕取色")
        gui.SetFont("s10 Normal c" Theme.FgPrimary, "Segoe UI")
        startY += rowH

        gui.AddText("x35 y" startY " w" labelW " h25 +0x200", "开始取色")
        this._hkPickerStart := gui.AddEdit("x" (35 + labelW) " y" startY " w" editW " h25 ReadOnly", HotkeyManager.GetDisplayText(
            "picker.start"))
        gui.AddButton("x" (35 + labelW + editW + 5) " y" startY " w" btnW " h25", "重置").OnEvent("Click", (*) => this._ResetHotkey(
            "picker.start", this._hkPickerStart))
        startY += rowH

        ; ----- 截图悬浮 -----
        gui.SetFont("s10 Bold c" Theme.FgAccent, "Segoe UI")
        gui.AddText("x25 y" startY " w" labelW " h25", "📸 截图悬浮")
        gui.SetFont("s10 Normal c" Theme.FgPrimary, "Segoe UI")
        startY += rowH

        gui.AddText("x35 y" startY " w" labelW " h25 +0x200", "开始截图")
        this._hkScreenshotStart := gui.AddEdit("x" (35 + labelW) " y" startY " w" editW " h25 ReadOnly", HotkeyManager.GetDisplayText(
            "screenshot.start"))
        gui.AddButton("x" (35 + labelW + editW + 5) " y" startY " w" btnW " h25", "重置").OnEvent("Click", (*) => this._ResetHotkey(
            "screenshot.start", this._hkScreenshotStart))
        startY += rowH

        gui.AddText("x35 y" startY " w" labelW " h25 +0x200", "关闭所有悬浮窗")
        this._hkScreenshotCloseAll := gui.AddEdit("x" (35 + labelW) " y" startY " w" editW " h25 ReadOnly",
        HotkeyManager.GetDisplayText("screenshot.closeAll"))
        gui.AddButton("x" (35 + labelW + editW + 5) " y" startY " w" btnW " h25", "重置").OnEvent("Click", (*) => this._ResetHotkey(
            "screenshot.closeAll", this._hkScreenshotCloseAll))
        startY += rowH

        ; ----- 置顶窗口 -----
        gui.SetFont("s10 Bold c" Theme.FgAccent, "Segoe UI")
        gui.AddText("x25 y" startY " w" labelW " h25", "📌 置顶窗口")
        gui.SetFont("s10 Normal c" Theme.FgPrimary, "Segoe UI")
        startY += rowH

        gui.AddText("x35 y" startY " w" labelW " h25 +0x200", "切换置顶")
        this._hkPinToggle := gui.AddEdit("x" (35 + labelW) " y" startY " w" editW " h25 ReadOnly", HotkeyManager.GetDisplayText(
            "pin.toggle"))
        gui.AddButton("x" (35 + labelW + editW + 5) " y" startY " w" btnW " h25", "重置").OnEvent("Click", (*) => this._ResetHotkey(
            "pin.toggle", this._hkPinToggle))
        startY += rowH

        gui.AddText("x35 y" startY " w" labelW " h25 +0x200", "取消全部置顶")
        this._hkPinUnpinAll := gui.AddEdit("x" (35 + labelW) " y" startY " w" editW " h25 ReadOnly", HotkeyManager.GetDisplayText(
            "pin.unpinAll"))
        gui.AddButton("x" (35 + labelW + editW + 5) " y" startY " w" btnW " h25", "重置").OnEvent("Click", (*) => this._ResetHotkey(
            "pin.unpinAll", this._hkPinUnpinAll))
        startY += rowH

        ; 恢复所有默认按钮
        gui.AddButton("x25 y380 w120 h30", "🔄 全部恢复默认").OnEvent("Click", (*) => this._ResetAllHotkeys())

        ; 绑定录制事件
        this._BindHotkeyRecording()
    }

    ; -------------------------------------------------
    ; _CreateSettingsTab - 创建设置选项卡
    ; -------------------------------------------------
    _CreateSettingsTab() {
        gui := this._gui

        startY := 110
        rowH := 35

        ; ----- 语言设置 -----
        gui.SetFont("s10 Bold c" Theme.FgAccent, "Segoe UI")
        gui.AddText("x25 y" startY " w200", "🌐 " T("settings.language"))
        gui.SetFont("s10 Normal c" Theme.FgPrimary, "Segoe UI")
        startY += rowH

        gui.AddText("x35 y" startY " w100 h25 +0x200", "界面语言")
        this._ddlLanguage := gui.AddDropDownList("x140 y" startY " w150", ["简体中文", "English"])

        ; 设置当前语言
        currentLang := I18n.GetCurrentLang()
        this._ddlLanguage.Choose(currentLang = "zh-CN" ? 1 : 2)
        this._ddlLanguage.OnEvent("Change", (*) => this._OnLanguageChange())
        startY += rowH + 10

        ; ----- 通知设置 -----
        gui.SetFont("s10 Bold c" Theme.FgAccent, "Segoe UI")
        gui.AddText("x25 y" startY " w200", "🔔 通知设置")
        gui.SetFont("s10 Normal c" Theme.FgPrimary, "Segoe UI")
        startY += rowH

        this._cbShowNotify := gui.AddCheckbox("x35 y" startY " w200 Checked", "显示操作通知")
        startY += 30

        gui.AddText("x35 y" startY " w100 h25 +0x200", "通知时长(ms)")
        this._editNotifyDuration := gui.AddEdit("x140 y" startY " w80 Number", "2000")
        startY += rowH + 10

        ; ----- 开机自启动 -----
        gui.SetFont("s10 Bold c" Theme.FgAccent, "Segoe UI")
        gui.AddText("x25 y" startY " w200", "🚀 自启动设置")
        gui.SetFont("s10 Normal c" Theme.FgPrimary, "Segoe UI")
        startY += rowH

        this._cbManagerAutoStart := gui.AddCheckbox("x35 y" startY " w200", "管理器开机自启动")
        startY += rowH + 10

        ; ----- 日志设置 -----
        gui.SetFont("s10 Bold c" Theme.FgAccent, "Segoe UI")
        gui.AddText("x25 y" startY " w200", "📝 日志设置")
        gui.SetFont("s10 Normal c" Theme.FgPrimary, "Segoe UI")
        startY += rowH

        this._cbLogToFile := gui.AddCheckbox("x35 y" startY " w150", "保存日志到文件")

        gui.AddText("x200 y" startY " w60 h25 +0x200", "日志级别")
        this._ddlLogLevel := gui.AddDropDownList("x265 y" startY " w100", ["DEBUG", "INFO", "WARN", "ERROR"])
        this._ddlLogLevel.Choose(2)  ; 默认 INFO
        startY += rowH

        ; 保存按钮
        gui.AddButton("x25 y380 w100 h30", "💾 " T("settings.save")).OnEvent("Click", (*) => this._SaveSettings())
    }

    ; -------------------------------------------------
    ; _CreateAboutTab - 创建关于选项卡
    ; -------------------------------------------------
    _CreateAboutTab() {
        gui := this._gui

        centerX := 200

        ; Logo/图标
        gui.SetFont("s48", "Segoe UI Emoji")
        gui.AddText("x" centerX " y130 w200 +Center", "🎛️")

        ; 名称
        gui.SetFont("s18 Bold c" Theme.FgPrimary, "Segoe UI")
        gui.AddText("x50 y200 w500 +Center", AppInfo.Name)

        ; 版本
        gui.SetFont("s12 c" Theme.FgSecondary, "Segoe UI")
        gui.AddText("x50 y235 w500 +Center", T("app.version", AppInfo.Version))

        ; 描述
        gui.SetFont("s10 c" Theme.FgMuted, "Segoe UI")
        gui.AddText("x50 y270 w500 +Center", T("about.description"))

        ; 作者
        gui.AddText("x50 y310 w500 +Center", T("about.author") ": " AppInfo.Author)

        ; 链接
        gui.SetFont("s10 c" Theme.FgAccent " Underline", "Segoe UI")
        linkText := gui.AddText("x50 y350 w500 +Center", "GitHub: " AppInfo.Website)
        linkText.OnEvent("Click", (*) => Run(AppInfo.Website))

        ; 版权
        gui.SetFont("s9 c" Theme.FgMuted, "Segoe UI")
        gui.AddText("x50 y390 w500 +Center", "© 2024 AutoHotkey v2")
    }

    ; -------------------------------------------------
    ; _BindHotkeyRecording - 绑定快捷键录制事件
    ; -------------------------------------------------
    _BindHotkeyRecording() {
        ; 为每个快捷键输入框绑定点击事件
        hotkeyEdits := [{ edit: this._hkPickerStart, key: "picker.start" }, { edit: this._hkScreenshotStart, key: "screenshot.start" }, { edit: this
            ._hkScreenshotCloseAll, key: "screenshot.closeAll" }, { edit: this._hkPinToggle, key: "pin.toggle" }, { edit: this
                ._hkPinUnpinAll, key: "pin.unpinAll" }
        ]

        for item in hotkeyEdits {
            edit := item.edit
            key := item.key

            ; 使用闭包捕获变量
            edit.OnEvent("Focus", ((e, k) => (*) => this._StartHotkeyRecord(e, k))(edit, key))
        }
    }

    ; -------------------------------------------------
    ; _StartHotkeyRecord - 开始录制快捷键
    ; -------------------------------------------------
    _StartHotkeyRecord(editControl, configKey) {
        editControl.Value := T("hotkey.press")

        HotkeyManager.StartRecording((hk) => this._OnHotkeyRecorded(editControl, configKey, hk), editControl)
    }

    ; -------------------------------------------------
    ; _OnHotkeyRecorded - 快捷键录制完成
    ; -------------------------------------------------
    _OnHotkeyRecorded(editControl, configKey, hotkey) {
        ; 检查冲突
        conflict := HotkeyManager.CheckConflict(hotkey, configKey)
        if conflict {
            editControl.Value := HotkeyManager.GetDisplayText(configKey)
            Notify.Warning(T("hotkey.conflict"), "与 '" conflict "' 冲突")
            return
        }

        ; 更新快捷键
        HotkeyManager.Update(configKey, hotkey)
        editControl.Value := HotkeyManager.FormatHotkey(hotkey)

        Notify.Success(T("notify.success"), "快捷键已更新")
    }

    ; -------------------------------------------------
    ; _ResetHotkey - 重置单个快捷键
    ; -------------------------------------------------
    _ResetHotkey(configKey, editControl) {
        HotkeyManager.ResetToDefault(configKey)
        editControl.Value := HotkeyManager.GetDisplayText(configKey)
        Notify.Info(T("notify.success"), "已恢复默认快捷键")
    }

    ; -------------------------------------------------
    ; _ResetAllHotkeys - 重置所有快捷键
    ; -------------------------------------------------
    _ResetAllHotkeys() {
        result := MsgBox("确定要恢复所有快捷键为默认值吗？", "确认", 0x34)
        if result = "Yes" {
            HotkeyManager.ResetAllToDefault()

            ; 更新所有输入框
            this._hkPickerStart.Value := HotkeyManager.GetDisplayText("picker.start")
            this._hkScreenshotStart.Value := HotkeyManager.GetDisplayText("screenshot.start")
            this._hkScreenshotCloseAll.Value := HotkeyManager.GetDisplayText("screenshot.closeAll")
            this._hkPinToggle.Value := HotkeyManager.GetDisplayText("pin.toggle")
            this._hkPinUnpinAll.Value := HotkeyManager.GetDisplayText("pin.unpinAll")

            Notify.Success(T("notify.success"), "所有快捷键已恢复默认")
        }
    }

    ; -------------------------------------------------
    ; _OnLanguageChange - 语言切换
    ; -------------------------------------------------
    _OnLanguageChange() {
        selected := this._ddlLanguage.Value
        newLang := selected = 1 ? "zh-CN" : "en-US"

        if I18n.Switch(newLang) {
            ConfigManager.Set("general.language", newLang)
            Notify.Info(T("notify.success"), "语言已切换，部分更改需要重启生效")
        }
    }

    ; -------------------------------------------------
    ; _SaveSettings - 保存设置
    ; -------------------------------------------------
    _SaveSettings() {
        ; 保存通知设置
        ConfigManager.Set("general.showNotifications", this._cbShowNotify.Value)
        ConfigManager.Set("general.notificationDuration", Integer(this._editNotifyDuration.Value))

        ; 保存日志设置
        ConfigManager.Set("log.toFile", this._cbLogToFile.Value)
        ConfigManager.Set("log.level", this._ddlLogLevel.Text)

        Notify.Success(T("notify.success"), T("settings.saved"))
    }

    ; -------------------------------------------------
    ; _RefreshScriptList - 刷新脚本列表
    ; -------------------------------------------------
    _RefreshScriptList() {
        ; 这里需要调用 ScriptCore 的功能
        ; 由于模块化设计，将在 ScriptManager.ahk 中实现回调
        if this.HasOwnProp("onRefresh") && this.onRefresh
            this.onRefresh()

        this._UpdateStatusBar()
    }

    ; -------------------------------------------------
    ; UpdateScriptList - 更新脚本列表（供外部调用）
    ; -------------------------------------------------
    UpdateScriptList(scripts) {
        this._scriptData := scripts
        this._scriptListView.Delete()

        for script in scripts {
            icon := script.Running ? "🟢" : "⚪"
            status := script.Running ? T("status.running") : T("status.stopped")
            autoStart := script.AutoStart ? "✅" : "❌"

            this._scriptListView.Add("", icon, script.Name, status, autoStart, "")
        }

        this._UpdateStatusBar()
    }

    ; -------------------------------------------------
    ; _UpdateStatusBar - 更新状态栏
    ; -------------------------------------------------
    _UpdateStatusBar() {
        total := this._scriptData.Length
        running := 0

        for script in this._scriptData {
            if script.Running
                running++
        }

        this._statusBar.SetText("共 " total " 个脚本", 1)
        this._statusBar.SetText(running " 个运行中", 2)
        this._statusBar.SetText("🟢 正常", 3)
    }

    ; -------------------------------------------------
    ; 脚本操作回调（供外部绑定）
    ; -------------------------------------------------
    _OnStartAll() {
        if this.HasOwnProp("onStartAll") && this.onStartAll
            this.onStartAll()
    }

    _OnStopAll() {
        if this.HasOwnProp("onStopAll") && this.onStopAll
            this.onStopAll()
    }

    _OnReloadAll() {
        if this.HasOwnProp("onReloadAll") && this.onReloadAll
            this.onReloadAll()
    }

    _GetSelectedScript() {
        row := this._scriptListView.GetNext(0)
        if row && row <= this._scriptData.Length
            return this._scriptData[row]
        return ""
    }

    _OnStartSelected() {
        script := this._GetSelectedScript()
        if script && this.HasOwnProp("onStartScript") && this.onStartScript
            this.onStartScript(script.Path)
    }

    _OnStopSelected() {
        script := this._GetSelectedScript()
        if script && this.HasOwnProp("onStopScript") && this.onStopScript
            this.onStopScript(script.Path)
    }

    _OnReloadSelected() {
        script := this._GetSelectedScript()
        if script && this.HasOwnProp("onReloadScript") && this.onReloadScript
            this.onReloadScript(script.Path)
    }

    _OnToggleAutoStart() {
        script := this._GetSelectedScript()
        if script && this.HasOwnProp("onToggleAutoStart") && this.onToggleAutoStart
            this.onToggleAutoStart(script.Path)
    }

    _OnOpenFolder() {
        Run("explorer.exe `"" A_ScriptDir "`"")
    }

    _OnScriptDoubleClick() {
        script := this._GetSelectedScript()
        if script && this.HasOwnProp("onToggleScript") && this.onToggleScript
            this.onToggleScript(script.Path)
    }

    ; -------------------------------------------------
    ; _OnResize - 窗口大小改变
    ; -------------------------------------------------
    _OnResize() {
        ; 可以在这里实现响应式布局
    }

    ; -------------------------------------------------
    ; Show - 显示窗口
    ; -------------------------------------------------
    Show() {
        this._RefreshScriptList()
        this._gui.Show("w" MainWindow.Width " h" MainWindow.Height)
        this._visible := true
    }

    ; -------------------------------------------------
    ; Hide - 隐藏窗口
    ; -------------------------------------------------
    Hide() {
        this._gui.Hide()
        this._visible := false
    }

    ; -------------------------------------------------
    ; Toggle - 切换显示状态
    ; -------------------------------------------------
    Toggle() {
        if this._visible
            this.Hide()
        else
            this.Show()
    }

    ; -------------------------------------------------
    ; IsVisible - 检查是否可见
    ; -------------------------------------------------
    IsVisible() {
        return this._visible
    }

    ; -------------------------------------------------
    ; Destroy - 销毁窗口
    ; -------------------------------------------------
    Destroy() {
        this._gui.Destroy()
    }
}
