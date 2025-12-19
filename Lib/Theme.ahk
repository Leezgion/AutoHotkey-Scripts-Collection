; =================================================
; 📦 Theme.ahk - GUI 主题系统
; =================================================
; 功能：现代深色主题、控件样式、动画效果
; =================================================

#Include "Constants.ahk"

; -------------------------------------------------
; 🎨 主题管理器类
; -------------------------------------------------
class ThemeManager {
    static _current := "dark"

    ; -------------------------------------------------
    ; 颜色值 (从 Constants.ahk 的 Theme 类获取)
    ; -------------------------------------------------
    static Colors {
        get => Theme
    }

    ; -------------------------------------------------
    ; ApplyToGui - 应用主题到 GUI
    ; -------------------------------------------------
    static ApplyToGui(gui, options := "") {
        ; 设置深色背景
        gui.BackColor := Theme.BgPrimary

        ; 设置窗口样式
        gui.SetFont("s10 c" Theme.FgPrimary, "Segoe UI")

        return gui
    }

    ; -------------------------------------------------
    ; CreateStyledButton - 创建样式化按钮
    ; -------------------------------------------------
    static CreateStyledButton(gui, text, options := "", callback := "") {
        ; 计算尺寸
        defaultW := 100
        defaultH := 32

        ; 创建按钮背景（使用 Text 控件模拟）
        btn := gui.AddButton(options " w" defaultW " h" defaultH, text)

        if callback
            btn.OnEvent("Click", callback)

        return btn
    }

    ; -------------------------------------------------
    ; CreateCard - 创建卡片容器
    ; -------------------------------------------------
    static CreateCard(gui, x, y, w, h, title := "") {
        ; 创建卡片背景
        card := gui.AddText("x" x " y" y " w" w " h" h " +Background" Theme.BgSecondary, "")

        ; 如果有标题，添加标题文本
        if title {
            gui.SetFont("s11 Bold c" Theme.FgPrimary)
            gui.AddText("x" (x + 15) " y" (y + 10) " w" (w - 30) " +Background" Theme.BgSecondary, title)
            gui.SetFont("s10 Normal c" Theme.FgPrimary)
        }

        return card
    }

    ; -------------------------------------------------
    ; CreateListView - 创建样式化列表视图
    ; -------------------------------------------------
    static CreateListView(gui, options, columns*) {
        lv := gui.AddListView(options " +Background" Theme.BgSecondary " c" Theme.FgPrimary, columns)

        ; 设置列宽自动调整
        for i, col in columns {
            lv.ModifyCol(i, "AutoHdr")
        }

        return lv
    }

    ; -------------------------------------------------
    ; CreateTab - 创建样式化选项卡
    ; -------------------------------------------------
    static CreateTab(gui, options, tabs*) {
        tab := gui.AddTab3(options, tabs)
        return tab
    }

    ; -------------------------------------------------
    ; CreateGroupBox - 创建分组框
    ; -------------------------------------------------
    static CreateGroupBox(gui, text, options := "") {
        gb := gui.AddGroupBox(options " c" Theme.FgSecondary, text)
        return gb
    }

    ; -------------------------------------------------
    ; CreateStatusBar - 创建状态栏
    ; -------------------------------------------------
    static CreateStatusBar(gui, parts*) {
        sb := gui.AddStatusBar()

        if parts.Length > 0
            sb.SetParts(parts*)

        return sb
    }

    ; -------------------------------------------------
    ; CreateCheckbox - 创建样式化复选框
    ; -------------------------------------------------
    static CreateCheckbox(gui, text, options := "", checked := false) {
        opts := options " c" Theme.FgPrimary
        if checked
            opts .= " Checked"

        cb := gui.AddCheckbox(opts, text)
        return cb
    }

    ; -------------------------------------------------
    ; CreateEdit - 创建样式化编辑框
    ; -------------------------------------------------
    static CreateEdit(gui, options := "", value := "") {
        edit := gui.AddEdit(options " +Background" Theme.BgTertiary " c" Theme.FgPrimary, value)
        return edit
    }

    ; -------------------------------------------------
    ; CreateDropDown - 创建样式化下拉框
    ; -------------------------------------------------
    static CreateDropDown(gui, options, items*) {
        ddl := gui.AddDropDownList(options, items)
        return ddl
    }

    ; -------------------------------------------------
    ; CreateProgress - 创建进度条
    ; -------------------------------------------------
    static CreateProgress(gui, options := "") {
        prog := gui.AddProgress(options " +Background" Theme.BgTertiary " c" Theme.FgAccent)
        return prog
    }

    ; -------------------------------------------------
    ; CreateSeparator - 创建分隔线
    ; -------------------------------------------------
    static CreateSeparator(gui, x, y, w) {
        sep := gui.AddText("x" x " y" y " w" w " h1 +Background" Theme.Border, "")
        return sep
    }

    ; -------------------------------------------------
    ; CreateLabel - 创建标签
    ; -------------------------------------------------
    static CreateLabel(gui, text, options := "", style := "normal") {
        switch style {
            case "title":
                gui.SetFont("s14 Bold c" Theme.FgPrimary)
            case "subtitle":
                gui.SetFont("s12 c" Theme.FgPrimary)
            case "muted":
                gui.SetFont("s10 c" Theme.FgMuted)
            case "accent":
                gui.SetFont("s10 c" Theme.FgAccent)
            case "success":
                gui.SetFont("s10 c" Theme.Success)
            case "error":
                gui.SetFont("s10 c" Theme.Error)
            default:
                gui.SetFont("s10 c" Theme.FgPrimary)
        }

        label := gui.AddText(options, text)

        ; 恢复默认字体
        gui.SetFont("s10 c" Theme.FgPrimary, "Segoe UI")

        return label
    }

    ; -------------------------------------------------
    ; CreateIcon - 创建图标文本
    ; -------------------------------------------------
    static CreateIcon(gui, icon, options := "") {
        gui.SetFont("s16", "Segoe UI Emoji")
        txt := gui.AddText(options, icon)
        gui.SetFont("s10", "Segoe UI")
        return txt
    }

    ; -------------------------------------------------
    ; GetStatusColor - 获取状态颜色
    ; -------------------------------------------------
    static GetStatusColor(status) {
        switch status {
            case "running", "success", "active":
                return Theme.Success
            case "stopped", "inactive":
                return Theme.FgMuted
            case "error", "failed":
                return Theme.Error
            case "warning":
                return Theme.Warning
            default:
                return Theme.FgSecondary
        }
    }

    ; -------------------------------------------------
    ; GetStatusIcon - 获取状态图标
    ; -------------------------------------------------
    static GetStatusIcon(status) {
        switch status {
            case "running", "active":
                return "🟢"
            case "stopped", "inactive":
                return "⚪"
            case "error", "failed":
                return "🔴"
            case "warning":
                return "🟡"
            case "starting":
                return "🔵"
            default:
                return "⚪"
        }
    }
}

; -------------------------------------------------
; 🖼️ 现代窗口类 - 带自定义标题栏
; -------------------------------------------------
class ModernWindow {
    _gui := ""
    _title := ""
    _titleBar := ""
    _closeBtn := ""
    _minBtn := ""
    _isDragging := false
    _dragStartX := 0
    _dragStartY := 0

    ; -------------------------------------------------
    ; __New - 构造函数
    ; -------------------------------------------------
    __New(title, options := "") {
        this._title := title

        ; 创建无边框窗口
        this._gui := Gui("+AlwaysOnTop -Caption +Border " options)
        ThemeManager.ApplyToGui(this._gui)

        ; 创建自定义标题栏
        this._CreateTitleBar()
    }

    ; -------------------------------------------------
    ; Gui 属性访问器
    ; -------------------------------------------------
    Gui {
        get => this._gui
    }

    ; -------------------------------------------------
    ; 私有方法：创建标题栏
    ; -------------------------------------------------
    _CreateTitleBar() {
        gui := this._gui

        ; 标题栏背景
        this._titleBar := gui.AddText("x0 y0 w+0 h35 +Background" Theme.BgSecondary, "")

        ; 标题文字
        gui.SetFont("s11 c" Theme.FgPrimary, "Segoe UI")
        gui.AddText("x15 y8 +Background" Theme.BgSecondary, this._title)

        ; 关闭按钮
        gui.SetFont("s12 c" Theme.FgPrimary, "Segoe UI")
        this._closeBtn := gui.AddText("x+0 yp w35 h35 +Center +Background" Theme.BgSecondary, "✕")
        this._closeBtn.OnEvent("Click", (*) => this._gui.Destroy())

        ; 最小化按钮
        this._minBtn := gui.AddText("x+0 yp w35 h35 +Center +Background" Theme.BgSecondary, "─")
        this._minBtn.OnEvent("Click", (*) => WinMinimize(this._gui.Hwnd))

        ; 恢复默认字体
        gui.SetFont("s10 c" Theme.FgPrimary, "Segoe UI")

        ; 绑定拖动事件
        this._titleBar.OnEvent("Click", (*) => this._StartDrag())
    }

    ; -------------------------------------------------
    ; 私有方法：开始拖动
    ; -------------------------------------------------
    _StartDrag() {
        ; 使用 Windows 消息实现拖动
        PostMessage(0xA1, 2, 0, , this._gui.Hwnd)  ; WM_NCLBUTTONDOWN, HTCAPTION
    }

    ; -------------------------------------------------
    ; Show - 显示窗口
    ; -------------------------------------------------
    Show(options := "") {
        this._gui.Show(options)
    }

    ; -------------------------------------------------
    ; Hide - 隐藏窗口
    ; -------------------------------------------------
    Hide() {
        this._gui.Hide()
    }

    ; -------------------------------------------------
    ; Destroy - 销毁窗口
    ; -------------------------------------------------
    Destroy() {
        this._gui.Destroy()
    }

    ; -------------------------------------------------
    ; AddControl - 添加控件（便捷方法）
    ; -------------------------------------------------
    AddControl(type, options, params*) {
        switch type {
            case "Button":
                return ThemeManager.CreateStyledButton(this._gui, params[1], options, params.Length > 1 ? params[2] :
                    "")
            case "Label":
                return ThemeManager.CreateLabel(this._gui, params[1], options, params.Length > 1 ? params[2] : "normal"
                )
            case "Edit":
                return ThemeManager.CreateEdit(this._gui, options, params.Length > 0 ? params[1] : "")
            case "Checkbox":
                return ThemeManager.CreateCheckbox(this._gui, params[1], options, params.Length > 1 ? params[2] : false
                )
            default:
                return this._gui.Add(type, options, params*)
        }
    }
}

; -------------------------------------------------
; 💫 动画效果类
; -------------------------------------------------
class Animation {
    ; -------------------------------------------------
    ; FadeIn - 淡入动画
    ; -------------------------------------------------
    static FadeIn(hwnd, duration := 200, finalOpacity := 255) {
        WinSetTransparent(0, hwnd)

        steps := 10
        stepDelay := duration // steps
        stepOpacity := finalOpacity // steps

        currentOpacity := 0
        loop steps {
            currentOpacity += stepOpacity
            WinSetTransparent(currentOpacity, hwnd)
            Sleep(stepDelay)
        }

        WinSetTransparent(finalOpacity, hwnd)
    }

    ; -------------------------------------------------
    ; FadeOut - 淡出动画
    ; -------------------------------------------------
    static FadeOut(hwnd, duration := 200) {
        try {
            currentOpacity := 255

            steps := 10
            stepDelay := duration // steps
            stepOpacity := 255 // steps

            loop steps {
                currentOpacity -= stepOpacity
                if currentOpacity < 0
                    currentOpacity := 0
                WinSetTransparent(currentOpacity, hwnd)
                Sleep(stepDelay)
            }
        }
    }

    ; -------------------------------------------------
    ; Pulse - 脉冲动画（边框闪烁）
    ; -------------------------------------------------
    static Pulse(hwnd, color1, color2, count := 3, interval := 100) {
        loop count {
            ; 由于 AHK 原生控件限制，这里只能通过改变透明度模拟
            WinSetTransparent(200, hwnd)
            Sleep(interval)
            WinSetTransparent(255, hwnd)
            Sleep(interval)
        }
    }
}

; -------------------------------------------------
; 🔔 通知类
; -------------------------------------------------
class Notify {
    static _queue := []
    static _current := ""
    static _timer := ""

    ; -------------------------------------------------
    ; Show - 显示通知
    ; -------------------------------------------------
    static Show(title, message, type := "info", duration := 2000) {
        ; 获取图标和颜色
        switch type {
            case "success":
                icon := "✅"
                color := Theme.Success
            case "error":
                icon := "❌"
                color := Theme.Error
            case "warning":
                icon := "⚠️"
                color := Theme.Warning
            default:
                icon := "ℹ️"
                color := Theme.Info
        }

        ; 使用 ToolTip 显示
        ToolTip(icon " " title "`n" message)
        SetTimer(() => ToolTip(), -duration)
    }

    ; -------------------------------------------------
    ; Success - 成功通知
    ; -------------------------------------------------
    static Success(title, message, duration := 2000) {
        this.Show(title, message, "success", duration)
    }

    ; -------------------------------------------------
    ; Error - 错误通知
    ; -------------------------------------------------
    static Error(title, message, duration := 3000) {
        this.Show(title, message, "error", duration)
    }

    ; -------------------------------------------------
    ; Warning - 警告通知
    ; -------------------------------------------------
    static Warning(title, message, duration := 2500) {
        this.Show(title, message, "warning", duration)
    }

    ; -------------------------------------------------
    ; Info - 信息通知
    ; -------------------------------------------------
    static Info(title, message, duration := 2000) {
        this.Show(title, message, "info", duration)
    }
}
