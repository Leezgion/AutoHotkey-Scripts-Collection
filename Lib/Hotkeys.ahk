; =================================================
; 📦 Hotkeys.ahk - 快捷键管理系统
; =================================================
; 功能：
;   - 快捷键注册与管理
;   - 按键录制（直接在输入框按键录制）
;   - 配置持久化
;   - 快捷键冲突检测
; =================================================

#Include "Constants.ahk"
#Include "ConfigManager.ahk"

; -------------------------------------------------
; ⌨️ 快捷键管理器类
; -------------------------------------------------
class HotkeyManager {
    static _callbacks := Map()
    static _active := Map()
    static _lastBindError := Map()
    static _initialized := false
    static _recording := false
    static _recordCallback := ""
    static _recordControl := ""

    ; -------------------------------------------------
    ; Init - 初始化快捷键系统
    ; -------------------------------------------------
    static Init() {
        if this._initialized
            return

        ; 确保配置已加载
        ConfigManager.Init()
        this._initialized := true
    }

    ; -------------------------------------------------
    ; Register - 注册快捷键
    ; 参数: key - 配置键路径，如 "picker.start"
    ;       callback - 回调函数
    ;       context - 上下文描述（用于日志）
    ; -------------------------------------------------
    static Register(key, callback, context := "") {
        this.Init()

        ; 允许传入函数名字符串；统一转换为可调用对象
        cb := callback
        if (Type(cb) = "String")
            cb := Func(cb)

        ; 存储回调
        this._callbacks[key] := {
            callback: cb,
            context: context
        }

        ; 获取快捷键配置
        hotkey := ConfigManager.GetHotkey(key)
        if (!hotkey || hotkey = "" || hotkey = "None")
            return true

        ; 绑定快捷键
        return this._BindHotkey(key, hotkey)
    }

    ; -------------------------------------------------
    ; Unregister - 注销快捷键
    ; -------------------------------------------------
    static Unregister(key) {
        if !this._callbacks.Has(key)
            return

        ; 解除绑定
        if this._active.Has(key) {
            hkStr := this._active[key]
            try Hotkey(hkStr, "Off")
            this._active.Delete(key)
        }

        this._callbacks.Delete(key)
    }

    ; -------------------------------------------------
    ; Update - 更新快捷键
    ; 参数: key - 配置键路径
    ;       newHotkey - 新快捷键字符串
    ; -------------------------------------------------
    static Update(key, newHotkey) {
        ; 解除旧快捷键
        if this._active.Has(key) {
            oldHotkey := this._active[key]
            try Hotkey(oldHotkey, "Off")
            this._active.Delete(key)
        }

        ; 保存新配置
        ConfigManager.SetHotkey(key, newHotkey)

        ; 绑定新快捷键
        if (newHotkey && newHotkey != "" && newHotkey != "None") {
            if this._callbacks.Has(key)
                return this._BindHotkey(key, newHotkey)
        }

        return true
    }

    ; -------------------------------------------------
    ; GetHotkey - 获取当前快捷键
    ; -------------------------------------------------
    static GetHotkey(key) {
        return ConfigManager.GetHotkey(key)
    }

    ; -------------------------------------------------
    ; GetDisplayText - 获取快捷键显示文本
    ; -------------------------------------------------
    static GetDisplayText(key) {
        hotkey := this.GetHotkey(key)
        return this.FormatHotkey(hotkey)
    }

    ; -------------------------------------------------
    ; FormatHotkey - 格式化快捷键为可读文本
    ; -------------------------------------------------
    static FormatHotkey(hotkey) {
        if (!hotkey || hotkey = "" || hotkey = "None")
            return "None"

        hk := Trim(hotkey, " `t`r`n")
        if (hk = "")
            return "None"

        ; 处理组合键：例如 "CapsLock & Space"
        if InStr(hk, " & ") {
            parts := StrSplit(hk, " & ")
            left := parts.Length >= 1 ? Trim(parts[1]) : ""
            right := parts.Length >= 2 ? Trim(parts[2]) : ""
            return (left != "" && right != "") ? (left "+" right) : hk
        }

        ; 解析前缀修饰符（支持 *, ~ 等前缀时忽略显示）
        i := 1
        while (i <= StrLen(hk)) {
            ch := SubStr(hk, i, 1)
            if (ch = "*" || ch = "~" || ch = "$") {
                i += 1
                continue
            }
            break
        }

        win := false, ctrl := false, alt := false, shift := false
        while (i <= StrLen(hk)) {
            ch := SubStr(hk, i, 1)
            if (ch = "#") {
                win := true
            } else if (ch = "^") {
                ctrl := true
            } else if (ch = "!") {
                alt := true
            } else if (ch = "+") {
                shift := true
            } else {
                break
            }
            i += 1
        }

        key := Trim(SubStr(hk, i))
        if (key = "")
            return "None"

        ; 常见按键名友好化（仅用于展示）
        lowerKey := StrLower(key)
        switch lowerKey {
            case "escape": key := "Esc"
            case "lbutton": key := "Left Click"
            case "rbutton": key := "Right Click"
            case "mbutton": key := "Middle Click"
            case "xbutton1": key := "Mouse 4"
            case "xbutton2": key := "Mouse 5"
            case "wheelup": key := "Wheel Up"
            case "wheeldown": key := "Wheel Down"
            case "wheelleft": key := "Wheel Left"
            case "wheelright": key := "Wheel Right"
            case "up": key := "Up"
            case "down": key := "Down"
            case "left": key := "Left"
            case "right": key := "Right"
            case "pgup": key := "Page Up"
            case "pgdn": key := "Page Down"
            case "del": key := "Delete"
            case "ins": key := "Insert"
        }

        ; 单字符按键统一大写
        if (StrLen(key) = 1)
            key := StrUpper(key)

        partsOut := []
        if ctrl
            partsOut.Push("Ctrl")
        if alt
            partsOut.Push("Alt")
        if shift
            partsOut.Push("Shift")
        if win
            partsOut.Push("Win")
        partsOut.Push(key)

        out := ""
        for idx, part in partsOut {
            out .= (idx = 1 ? part : "+" part)
        }
        return out
    }

    ; -------------------------------------------------
    ; ParseHotkey - 解析可读文本为快捷键格式
    ; -------------------------------------------------
    static ParseHotkey(text) {
        result := Trim(text, " `t`r`n")
        ; 支持用户手动写入的可读形式，例如 "Alt+S" / "Ctrl+Shift+S"
        result := StrReplace(result, "Win+", "#")
        result := StrReplace(result, "Alt+", "!")
        result := StrReplace(result, "Ctrl+", "^")
        result := StrReplace(result, "Shift+", "+")
        return result
    }

    ; -------------------------------------------------
    ; _NormalizeHotkey - 规范化快捷键字符串（用于绑定）
    ; 目标：容忍用户手动编辑 hotkeys.ini 时写成 "Alt+S" 这种可读形式
    ; -------------------------------------------------
    static _NormalizeHotkey(hotkey) {
        hk := Trim(hotkey, " `t`r`n")
        if (!hk || hk = "" || hk = "None")
            return ""

        ; 如果是可读形式（以 Ctrl+/Alt+/Shift+/Win+ 开头），转换为 AHK 形式
        ; 例如 "Alt+S" -> "!S"（AHK 不区分大小写）
        if RegExMatch(hk, "i)^(?:Win\+|Ctrl\+|Alt\+|Shift\+)")
            hk := this.ParseHotkey(hk)

        return Trim(hk, " `t`r`n")
    }

    ; -------------------------------------------------
    ; GetLastBindError - 获取最近一次绑定失败原因
    ; -------------------------------------------------
    static GetLastBindError(key) {
        return this._lastBindError.Has(key) ? this._lastBindError[key] : ""
    }

    ; -------------------------------------------------
    ; ResetToDefault - 重置为默认快捷键
    ; -------------------------------------------------
    static ResetToDefault(key) {
        defaultHotkey := this._GetDefaultHotkey(key)
        if defaultHotkey
            this.Update(key, defaultHotkey)
    }

    ; -------------------------------------------------
    ; ResetAllToDefault - 重置所有快捷键为默认
    ; -------------------------------------------------
    static ResetAllToDefault() {
        ConfigManager.Reset("hotkeys")

        ; 重新绑定所有已注册的快捷键
        for key, info in this._callbacks {
            hotkey := ConfigManager.GetHotkey(key)
            if hotkey && hotkey != ""
                this._BindHotkey(key, hotkey)
        }
    }

    ; -------------------------------------------------
    ; CheckConflict - 检查快捷键冲突
    ; 返回: 冲突的键名，无冲突返回空字符串
    ; -------------------------------------------------
    static CheckConflict(newHotkey, excludeKey := "") {
        for key, activeHotkey in this._active {
            if (key != excludeKey && activeHotkey = newHotkey)
                return key
        }
        return ""
    }

    ; -------------------------------------------------
    ; StartRecording - 开始录制快捷键
    ; 参数: callback - 录制完成回调 (hotkeyStr) => {}
    ;       guiControl - 用于显示录制状态的控件（可选）
    ; -------------------------------------------------
    static StartRecording(callback, guiControl := "") {
        if this._recording
            return false

        this._recording := true
        this._recordCallback := callback
        this._recordControl := guiControl

        ; 显示提示
        if guiControl && guiControl.HasProp("Value")
            guiControl.Value := "请按下快捷键..."

        ; 安装键盘钩子
        this._InstallRecordHook()

        return true
    }

    ; -------------------------------------------------
    ; StopRecording - 停止录制
    ; -------------------------------------------------
    static StopRecording() {
        if !this._recording
            return

        this._recording := false
        this._UninstallRecordHook()
        this._recordCallback := ""
        this._recordControl := ""
    }

    ; -------------------------------------------------
    ; IsRecording - 检查是否正在录制
    ; -------------------------------------------------
    static IsRecording() {
        return this._recording
    }

    ; -------------------------------------------------
    ; 私有方法：绑定快捷键
    ; -------------------------------------------------
    static _BindHotkey(key, hotkeyStr) {
        if !this._callbacks.Has(key)
            return false

        info := this._callbacks[key]

        cb := info.callback
        if (Type(cb) = "String") {
            cb := Func(cb)
            info.callback := cb
        }

        ; 确保回调可调用
        if !(IsObject(cb) && cb.HasMethod("Call")) {
            this._lastBindError[key] := "callback not callable (CallbackType=" Type(cb) ")"
            return false
        }

        hk := this._NormalizeHotkey(hotkeyStr)
        if (!hk || hk = "" || hk = "None")
            return true

        cbType := ""
        hkFuncType := ""
        try cbType := Type(cb)
        catch
            cbType := "<TypeError>"
        try hkFuncType := Type(Hotkey)
        catch
            hkFuncType := "<TypeError>"

        try {
            Hotkey(hk, cb, "On")
            this._active[key] := hk
            if this._lastBindError.Has(key)
                this._lastBindError.Delete(key)
            return true
        } catch as e {
            err := e.Message
            this._lastBindError[key] := "'" hk "' - " err " (HotkeyType=" hkFuncType ", CallbackType=" cbType ")"
            OutputDebug("Hotkey bind failed: " key " = " hk " - " err)
            return false
        }
    }

    ; -------------------------------------------------
    ; 私有方法：获取默认快捷键
    ; -------------------------------------------------
    static _GetDefaultHotkey(key) {
        ; 从 Constants.ahk 中的 DefaultHotkeys 获取
        parts := StrSplit(key, ".")
        if parts.Length < 2
            return ""

        category := parts[1]
        action := parts[2]

        switch category {
            case "picker":
                switch action {
                    case "start": return DefaultHotkeys.PickerStart
                    case "cancel": return DefaultHotkeys.PickerCancel
                }
            case "screenshot":
                switch action {
                    case "start": return DefaultHotkeys.ScreenshotStart
                    case "closeAll": return DefaultHotkeys.ScreenshotCloseAll
                }
            case "pin":
                switch action {
                    case "toggle": return DefaultHotkeys.PinToggle
                    case "unpinAll": return DefaultHotkeys.PinUnpinAll
                    case "switch": return DefaultHotkeys.PinSwitch
                    case "changeColor": return DefaultHotkeys.PinChangeColor
                }
            case "manager":
                switch action {
                    case "reloadAll": return DefaultHotkeys.ManagerReloadAll
                    case "stopAll": return DefaultHotkeys.ManagerStopAll
                    case "startAll": return DefaultHotkeys.ManagerStartAll
                    case "showGUI": return DefaultHotkeys.ManagerShowGUI
                }
        }

        return ""
    }

    ; -------------------------------------------------
    ; 私有方法：安装录制钩子
    ; -------------------------------------------------
    static _InstallRecordHook() {
        ; 使用 InputHook 捕获按键
        static ih := ""

        ih := InputHook("L0 I")
        ih.KeyOpt("{All}", "+N")  ; 通知所有按键
        ih.OnKeyDown := ObjBindMethod(this, "_OnRecordKeyDown")
        ih.Start()

        this._recordHook := ih
    }

    ; -------------------------------------------------
    ; 私有方法：卸载录制钩子
    ; -------------------------------------------------
    static _UninstallRecordHook() {
        if this.HasOwnProp("_recordHook") && this._recordHook {
            this._recordHook.Stop()
            this._recordHook := ""
        }
    }

    ; -------------------------------------------------
    ; 私有方法：录制按键回调
    ; -------------------------------------------------
    static _OnRecordKeyDown(ih, vk, sc) {
        if !this._recording
            return

        ; 获取按键名
        keyName := GetKeyName(Format("vk{:X}sc{:X}", vk, sc))

        ; 忽略单独的修饰键
        if (keyName = "LControl" || keyName = "RControl"
            || keyName = "LAlt" || keyName = "RAlt"
            || keyName = "LShift" || keyName = "RShift"
            || keyName = "LWin" || keyName = "RWin")
            return

        ; 构建快捷键字符串
        hotkey := ""

        ; 检查修饰键
        if GetKeyState("LWin") || GetKeyState("RWin")
            hotkey .= "#"
        if GetKeyState("Ctrl")
            hotkey .= "^"
        if GetKeyState("Alt")
            hotkey .= "!"
        if GetKeyState("Shift")
            hotkey .= "+"

        ; 添加主键
        hotkey .= keyName

        ; 停止录制
        this.StopRecording()

        ; 更新控件显示
        if this._recordControl && this._recordControl.HasProp("Value")
            this._recordControl.Value := this.FormatHotkey(hotkey)

        ; 调用回调
        if this._recordCallback
            this._recordCallback(hotkey)
    }

    ; -------------------------------------------------
    ; GetAllHotkeys - 获取所有已注册的快捷键
    ; 返回: Map {key -> {hotkey, displayText, context}}
    ; -------------------------------------------------
    static GetAllHotkeys() {
        result := Map()

        for key, info in this._callbacks {
            hotkey := ConfigManager.GetHotkey(key)
            result[key] := {
                hotkey: hotkey,
                displayText: this.FormatHotkey(hotkey),
                context: info.context
            }
        }

        return result
    }
}

; -------------------------------------------------
; 🎯 快捷键录制控件类
; -------------------------------------------------
; 用于 GUI 中的快捷键输入控件
class HotkeyEdit {
    _gui := ""
    _edit := ""
    _key := ""
    _button := ""
    _onChange := ""

    ; -------------------------------------------------
    ; __New - 构造函数
    ; 参数: gui - 父 GUI
    ;       key - 配置键路径
    ;       options - Edit 控件选项
    ; -------------------------------------------------
    __New(gui, key, options := "") {
        this._gui := gui
        this._key := key

        ; 创建 Edit 控件
        this._edit := gui.AddEdit(options " ReadOnly", HotkeyManager.GetDisplayText(key))
        this._edit.OnEvent("Focus", (*) => this._StartRecord())

        ; 存储引用到控件
        this._edit.HotkeyEditInstance := this
    }

    ; -------------------------------------------------
    ; 属性访问器
    ; -------------------------------------------------
    Control {
        get => this._edit
    }

    Value {
        get => HotkeyManager.GetHotkey(this._key)
        set => this._SetValue(value)
    }

    DisplayText {
        get => this._edit.Value
    }

    ; -------------------------------------------------
    ; OnChange - 设置变更回调
    ; -------------------------------------------------
    OnChange(callback) {
        this._onChange := callback
        return this
    }

    ; -------------------------------------------------
    ; Reset - 重置为默认值
    ; -------------------------------------------------
    Reset() {
        HotkeyManager.ResetToDefault(this._key)
        this._edit.Value := HotkeyManager.GetDisplayText(this._key)

        if this._onChange
            this._onChange(this._key, this.Value)
    }

    ; -------------------------------------------------
    ; Clear - 清除快捷键
    ; -------------------------------------------------
    Clear() {
        HotkeyManager.Update(this._key, "None")
        this._edit.Value := "None"

        if this._onChange
            this._onChange(this._key, "None")
    }

    ; -------------------------------------------------
    ; 私有方法：开始录制
    ; -------------------------------------------------
    _StartRecord() {
        HotkeyManager.StartRecording(
            (hk) => this._OnRecordComplete(hk),
            this._edit
        )
    }

    ; -------------------------------------------------
    ; 私有方法：录制完成
    ; -------------------------------------------------
    _OnRecordComplete(hotkey) {
        ; 检查冲突
        conflict := HotkeyManager.CheckConflict(hotkey, this._key)
        if conflict {
            this._edit.Value := HotkeyManager.GetDisplayText(this._key)
            MsgBox("快捷键与 '" conflict "' 冲突，请选择其他快捷键。", "快捷键冲突", 48)
            return
        }

        ; 更新快捷键
        HotkeyManager.Update(this._key, hotkey)
        this._edit.Value := HotkeyManager.FormatHotkey(hotkey)

        if this._onChange
            this._onChange(this._key, hotkey)
    }

    ; -------------------------------------------------
    ; 私有方法：设置值
    ; -------------------------------------------------
    _SetValue(value) {
        HotkeyManager.Update(this._key, value)
        this._edit.Value := HotkeyManager.FormatHotkey(value)
    }
}
