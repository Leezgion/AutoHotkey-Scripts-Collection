; =================================================
; 🌐 Lib/I18n.ahk - 国际化管理器
; =================================================

#Include ..\Lang\zh-CN.ahk
#Include ..\Lang\en-US.ahk

class I18n {
    static _instance := ""
    static _currentLang := ""
    static _langClass := ""

    ; 支持的语言列表
    static SupportedLanguages := Map(
        "zh-CN", "简体中文",
        "en-US", "English (US)"
    )

    ; -------------------------------------------------
    ; Init - 初始化语言
    ; -------------------------------------------------
    static Init(langCode := "") {
        if (langCode = "") {
            ; 从配置读取或使用系统语言
            langCode := I18n._DetectLanguage()
        }

        I18n.SetLanguage(langCode)
    }

    ; -------------------------------------------------
    ; SetLanguage - 设置语言
    ; -------------------------------------------------
    static SetLanguage(langCode) {
        switch langCode {
            case "zh-CN":
                I18n._langClass := Lang_zh_CN
            case "en-US":
                I18n._langClass := Lang_en_US
            default:
                I18n._langClass := Lang_zh_CN
                langCode := "zh-CN"
        }
        I18n._currentLang := langCode
    }

    ; -------------------------------------------------
    ; GetLanguage - 获取当前语言
    ; -------------------------------------------------
    static GetLanguage() {
        return I18n._currentLang
    }

    ; -------------------------------------------------
    ; T - 翻译文本（简写）
    ; -------------------------------------------------
    static T(category, key, default := "") {
        if (I18n._langClass = "")
            I18n.Init()
        return I18n._langClass.Get(category, key, default)
    }

    ; -------------------------------------------------
    ; Get - 翻译文本
    ; -------------------------------------------------
    static Get(category, key, default := "") {
        return I18n.T(category, key, default)
    }

    ; -------------------------------------------------
    ; GetAll - 获取整个类别的翻译
    ; -------------------------------------------------
    static GetAll(category) {
        if (I18n._langClass = "")
            I18n.Init()

        if I18n._langClass.HasOwnProp(category)
            return I18n._langClass.%category%
        return {}
    }

    ; -------------------------------------------------
    ; Format - 格式化翻译文本
    ; -------------------------------------------------
    static Format(category, key, params*) {
        text := I18n.T(category, key)

        for i, param in params {
            text := StrReplace(text, "{" i "}", param)
        }

        return text
    }

    ; -------------------------------------------------
    ; 私有方法：检测系统语言
    ; -------------------------------------------------
    static _DetectLanguage() {
        ; 尝试从配置读取
        try {
            configPath := A_ScriptDir "\Config\settings.ini"
            if FileExist(configPath) {
                content := FileRead(configPath)
                if RegExMatch(content, "Language\s*=\s*(\S+)", &match)
                    return match[1]
            }
        }

        ; 检测系统语言
        sysLang := A_Language

        ; 中文
        if (sysLang = "0804" || sysLang = "0004")  ; 简体中文
            return "zh-CN"

        ; 默认英语
        return "en-US"
    }
}

; -------------------------------------------------
; T - 全局翻译函数（快捷方式）
; 支持两种调用方式:
;   T("category", "key") - 传统方式
;   T("category.key")    - 点分隔方式
; 支持类别别名:
;   picker -> ColorPicker, screenshot -> Screenshot
;   pin -> PinWindow, error -> Errors, dialog -> Dialog
;   hotkey -> Hotkey
; -------------------------------------------------
T(categoryOrKey, key := "", default := "") {
    ; 类别别名映射
    static categoryMap := Map(
        "picker", "ColorPicker",
        "screenshot", "Screenshot",
        "pin", "PinWindow",
        "error", "Errors",
        "dialog", "Dialog",
        "hotkey", "Hotkey"
    )

    ; 如果只有一个参数且包含点号，自动拆分
    if (key = "" && InStr(categoryOrKey, ".")) {
        parts := StrSplit(categoryOrKey, ".", , 2)
        category := parts[1]
        key := parts.Has(2) ? parts[2] : ""
        if (key = "")
            return default != "" ? default : categoryOrKey

        ; 应用类别别名
        if categoryMap.Has(category)
            category := categoryMap[category]

        return I18n.T(category, key, categoryOrKey)
    }

    ; 应用类别别名
    if categoryMap.Has(categoryOrKey)
        categoryOrKey := categoryMap[categoryOrKey]

    return I18n.T(categoryOrKey, key, default)
}
