; =================================================
; 📦 ConfigManager.ahk - INI 配置管理器
; =================================================
; 功能：
;   - 读取/写入 INI 配置文件
;   - 支持 settings.ini 和 hotkeys.ini
;   - 提供默认值回退
;   - 配置缓存以提高性能
; =================================================

#Include "Constants.ahk"

; -------------------------------------------------
; ⚙️ ConfigManager 类 - INI 配置管理
; -------------------------------------------------
class ConfigManager {
    static _initialized := false
    static _settingsPath := ""
    static _hotkeysPath := ""
    static _cache := Map()

    ; -------------------------------------------------
    ; Init - 初始化配置管理器
    ; -------------------------------------------------
    static Init() {
        if this._initialized
            return

        ; 设置配置文件路径
        this._settingsPath := A_ScriptDir "\Config\settings.ini"
        this._hotkeysPath := A_ScriptDir "\Config\hotkeys.ini"

        ; 确保配置目录存在
        if !DirExist(A_ScriptDir "\Config")
            DirCreate(A_ScriptDir "\Config")

        ; 如果配置文件不存在，创建默认配置
        if !FileExist(this._settingsPath)
            this._CreateDefaultSettings()

        if !FileExist(this._hotkeysPath)
            this._CreateDefaultHotkeys()

        this._initialized := true
    }

    ; -------------------------------------------------
    ; Get - 获取配置值
    ; 参数: section - INI 节名
    ;       key - 配置键名
    ;       default - 默认值
    ;       file - "settings" 或 "hotkeys"
    ; -------------------------------------------------
    static Get(section, key, default := "", file := "settings") {
        this.Init()

        filePath := (file = "hotkeys") ? this._hotkeysPath : this._settingsPath
        cacheKey := file ":" section ":" key

        ; 检查缓存
        if this._cache.Has(cacheKey)
            return this._cache[cacheKey]

        ; 从 INI 读取
        value := IniRead(filePath, section, key, default)
        this._cache[cacheKey] := value

        return value
    }

    ; -------------------------------------------------
    ; Set - 设置配置值 (点分隔格式)
    ; 参数: dotKey - "section.key" 格式
    ;       value - 要设置的值
    ;       file - "settings" 或 "hotkeys"
    ; -------------------------------------------------
    static Set(dotKey, value, file := "settings") {
        this.Init()

        ; 解析点分隔格式
        if InStr(dotKey, ".") {
            parts := StrSplit(dotKey, ".", , 2)
            section := parts[1]
            key := parts.Has(2) ? parts[2] : ""
        } else {
            ; 如果没有点，整个作为 key，section 默认为 "general"
            section := "general"
            key := dotKey
        }

        filePath := (file = "hotkeys") ? this._hotkeysPath : this._settingsPath
        cacheKey := file ":" section ":" key

        ; 写入 INI
        IniWrite(value, filePath, section, key)

        ; 更新缓存
        this._cache[cacheKey] := value
    }

    ; -------------------------------------------------
    ; GetHotkey - 获取快捷键配置
    ; 参数: key - 配置键路径，如 "picker.start" 或 "Global.ColorPicker"
    ; -------------------------------------------------
    static GetHotkey(key) {
        this.Init()

        ; 解析键路径
        if InStr(key, ".") {
            parts := StrSplit(key, ".")
            section := parts[1]
            keyName := parts[2]

            ; 转换常见的映射
            section := this._MapSection(section)
            keyName := this._MapKey(keyName)
        } else {
            section := "Global"
            keyName := key
        }

        return this.Get(section, keyName, "", "hotkeys")
    }

    ; -------------------------------------------------
    ; SetHotkey - 设置快捷键配置
    ; -------------------------------------------------
    static SetHotkey(key, value) {
        this.Init()

        if InStr(key, ".") {
            parts := StrSplit(key, ".")
            section := this._MapSection(parts[1])
            keyName := this._MapKey(parts[2])
        } else {
            section := "Global"
            keyName := key
        }

        this.Set(section, keyName, value, "hotkeys")
    }

    ; -------------------------------------------------
    ; GetSetting - 获取设置配置
    ; 参数: key - 配置键路径，如 "General.Language"
    ; -------------------------------------------------
    static GetSetting(key, default := "") {
        this.Init()

        if InStr(key, ".") {
            parts := StrSplit(key, ".")
            section := parts[1]
            keyName := parts[2]
        } else {
            section := "General"
            keyName := key
        }

        return this.Get(section, keyName, default, "settings")
    }

    ; -------------------------------------------------
    ; SetSetting - 设置设置配置
    ; -------------------------------------------------
    static SetSetting(key, value) {
        this.Init()

        if InStr(key, ".") {
            parts := StrSplit(key, ".")
            section := parts[1]
            keyName := parts[2]
        } else {
            section := "General"
            keyName := key
        }

        this.Set(section, keyName, value, "settings")
    }

    ; -------------------------------------------------
    ; Reset - 重置配置
    ; 参数: which - "settings", "hotkeys", 或 "all"
    ; -------------------------------------------------
    static Reset(which := "all") {
        this._cache.Clear()

        if (which = "settings" || which = "all") {
            if FileExist(this._settingsPath)
                FileDelete(this._settingsPath)
            this._CreateDefaultSettings()
        }

        if (which = "hotkeys" || which = "all") {
            if FileExist(this._hotkeysPath)
                FileDelete(this._hotkeysPath)
            this._CreateDefaultHotkeys()
        }
    }

    ; -------------------------------------------------
    ; ClearCache - 清除缓存
    ; -------------------------------------------------
    static ClearCache() {
        this._cache.Clear()
    }

    ; -------------------------------------------------
    ; 私有方法：映射节名
    ; -------------------------------------------------
    static _MapSection(section) {
        switch StrLower(section) {
            case "picker": return "ColorPicker"
            case "screenshot": return "Screenshot"
            case "pin": return "PinWindow"
            case "manager": return "Global"
            default: return section
        }
    }

    ; -------------------------------------------------
    ; 私有方法：映射键名
    ; -------------------------------------------------
    static _MapKey(key) {
        switch StrLower(key) {
            case "start": return "Start"
            case "cancel": return "Cancel"
            case "toggle": return "Toggle"
            case "unpinall": return "UnpinAll"
            case "switch": return "SwitchFocus"
            case "changecolor": return "ChangeColor"
            case "closeall": return "CloseAllFloats"
            case "reloadall": return "ReloadAll"
            case "stopall": return "StopAll"
            case "startall": return "StartAll"
            case "showgui": return "OpenSettings"
            default: return key
        }
    }

    ; -------------------------------------------------
    ; 私有方法：创建默认设置文件
    ; -------------------------------------------------
    static _CreateDefaultSettings() {
        content := "
(
; =================================================
; ⚙️ Config/settings.ini - 设置配置文件
; =================================================

[General]
Language=zh-CN
AutoStart=false
ShowTrayTip=true
Theme=auto
SoundEnabled=true

[ColorPicker]
DefaultFormat=HEX
ZoomLevel=8
MagnifierSize=150
ShowGrid=true
ShowCrosshair=true
MaxHistory=50

[Screenshot]
SavePath=Screenshots
DefaultFormat=PNG
JpegQuality=90

[PinWindow]
BorderThickness=3
SoundEnabled=true
)"
        FileAppend(content, this._settingsPath, "UTF-8")
    }

    ; -------------------------------------------------
    ; 私有方法：创建默认快捷键文件
    ; -------------------------------------------------
    static _CreateDefaultHotkeys() {
        content := "
(
; =================================================
; ⌨️ Config/hotkeys.ini - 快捷键配置文件
; =================================================

[Global]
ColorPicker=#+c
Screenshot=#+s
PinWindow=CapsLock & Space
OpenSettings=#+,
Exit=#+q

[ColorPicker]
Cancel=Escape
Copy=LButton
ZoomIn=WheelUp
ZoomOut=WheelDown
SwitchFormat=Tab

[Screenshot]
Cancel=Escape
Confirm=LButton
CopyToClipboard=^c
SaveToFile=^s
CloseFloat=Escape
CloseAllFloats=^a

[PinWindow]
UnpinAll=CapsLock & Escape
SwitchFocus=CapsLock & Tab
ChangeColor=CapsLock & c
)"
        FileAppend(content, this._hotkeysPath, "UTF-8")
    }
}
