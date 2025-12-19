; =================================================
; ℹ️ GUI/AboutDialog.ahk - 关于对话框
; =================================================

#Include ..\Lib\I18n.ahk

class AboutDialog {
    static Version := "1.0.0"
    static Author := "Leezgion"
    static Website := "https://github.com/Leezgion/AutoHotkey-Scripts-Collection"
    static RepoOwner := "Leezgion"
    static RepoName := "AutoHotkey-Scripts-Collection"

    _gui := ""
    _checkingUpdate := false

    ; -------------------------------------------------
    ; Show - 显示关于对话框
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
    ; Hide - 隐藏对话框
    ; -------------------------------------------------
    Hide() {
        if this._gui
            this._gui.Hide()
    }

    ; -------------------------------------------------
    ; Destroy - 销毁对话框
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
        title := T("About", "Title", "关于")

        this._gui := Gui("+AlwaysOnTop", title)
        this._gui.SetFont("s10", "Microsoft YaHei UI")
        this._gui.OnEvent("Close", (*) => this.Hide())

        ; 应用图标/标题
        this._gui.SetFont("s16 bold")
        this._gui.AddText("x20 y20 w300 Center", "🛠️ " T("Common", "AppName", "脚本管理器"))

        this._gui.SetFont("s10 norm")

        ; 版本信息
        this._gui.AddText("x20 y60 w300 Center", T("About", "Version", "版本") ": v" AboutDialog.Version)

        ; 分隔线
        this._gui.AddText("x20 y90 w300 h1 0x10")  ; SS_ETCHEDHORZ

        ; 描述
        this._gui.AddText("x20 y100 w300 Wrap", T("About", "Description",
            "一个实用的 AutoHotkey 脚本管理工具，包含屏幕取色、截图悬浮和窗口置顶功能。"))

        ; 功能列表
        this._gui.AddText("x20 y160 w300", "
        (
主要功能：
  🎨 屏幕取色 - 快速获取任意像素颜色
  📷 截图悬浮 - 截取区域并创建悬浮窗
  📌 置顶窗口 - 将任意窗口保持在最前
        )")

        ; 分隔线
        this._gui.AddText("x20 y260 w300 h1 0x10")

        ; 作者信息
        this._gui.AddText("x20 y270", T("About", "Author", "作者") ": " AboutDialog.Author)

        ; 网站链接
        this._gui.AddLink("x20 y295", T("About", "Website", "网站") ': <a href="' AboutDialog.Website '">' AboutDialog.Website '</a>'
        )

        ; 许可证
        this._gui.AddText("x20 y320", T("About", "License", "许可证") ": MIT")

        ; 分隔线
        this._gui.AddText("x20 y350 w300 h1 0x10")

        ; 底部按钮
        this._gui.AddButton("x130 y365 w80 Default", T("Common", "Close", "关闭"))
        .OnEvent("Click", (*) => this.Hide())

        ; 检查更新按钮
        this._btnUpdate := this._gui.AddButton("x220 y365 w100", T("About", "CheckUpdate", "检查更新"))
        this._btnUpdate.OnEvent("Click", (*) => this._CheckUpdate())
    }

    ; -------------------------------------------------
    ; 私有方法：检查更新
    ; -------------------------------------------------
    _CheckUpdate() {
        if this._checkingUpdate
            return

        this._checkingUpdate := true
        this._btnUpdate.Text := "检查中..."
        this._btnUpdate.Enabled := false

        ; 异步检查更新
        SetTimer(() => this._DoCheckUpdate(), -1)
    }

    ; -------------------------------------------------
    ; 私有方法：执行更新检查
    ; -------------------------------------------------
    _DoCheckUpdate() {
        try {
            ; 调用 GitHub API 获取最新 release
            apiUrl := "https://api.github.com/repos/" AboutDialog.RepoOwner "/" AboutDialog.RepoName "/releases/latest"

            ; 使用 WinHTTP 发送请求
            http := ComObject("WinHttp.WinHttpRequest.5.1")
            http.Open("GET", apiUrl, false)
            http.SetRequestHeader("User-Agent", "AutoHotkey-ScriptManager/" AboutDialog.Version)
            http.SetRequestHeader("Accept", "application/vnd.github.v3+json")
            http.Send()

            if (http.Status = 404) {
                ; 404 表示仓库不存在或没有发布任何 release
                this._ShowUpdateResult("no_release", "")
                return
            }

            if (http.Status != 200) {
                this._ShowUpdateResult("error", "无法连接到 GitHub (HTTP " http.Status ")")
                return
            }

            responseText := http.ResponseText

            ; 解析 JSON 获取版本号
            latestVersion := this._ParseLatestVersion(responseText)

            if !latestVersion {
                this._ShowUpdateResult("error", "无法解析版本信息")
                return
            }

            ; 比较版本号
            comparison := this._CompareVersions(AboutDialog.Version, latestVersion.version)

            if (comparison < 0) {
                ; 有新版本
                this._ShowUpdateResult("update", latestVersion)
            } else {
                ; 已是最新
                this._ShowUpdateResult("latest", latestVersion)
            }

        } catch as e {
            this._ShowUpdateResult("error", "检查更新失败: " e.Message)
        } finally {
            this._checkingUpdate := false
            this._btnUpdate.Text := T("About", "CheckUpdate", "检查更新")
            this._btnUpdate.Enabled := true
        }
    }

    ; -------------------------------------------------
    ; 私有方法：解析最新版本信息
    ; -------------------------------------------------
    _ParseLatestVersion(json) {
        ; 简单的 JSON 解析（提取 tag_name 和 html_url）
        version := ""
        url := ""
        body := ""

        ; 提取 tag_name
        if RegExMatch(json, '"tag_name"\s*:\s*"v?([^"]+)"', &match)
            version := match[1]

        ; 提取 html_url
        if RegExMatch(json, '"html_url"\s*:\s*"([^"]+)"', &match)
            url := match[1]

        ; 提取 body (发布说明)
        if RegExMatch(json, '"body"\s*:\s*"([^"]*)"', &match)
            body := StrReplace(match[1], "\n", "`n")

        if !version
            return ""

        return {
            version: version,
            url: url,
            body: body
        }
    }

    ; -------------------------------------------------
    ; 私有方法：比较版本号
    ; 返回: -1 (当前版本较旧), 0 (相同), 1 (当前版本较新)
    ; -------------------------------------------------
    _CompareVersions(current, latest) {
        ; 移除 'v' 前缀
        current := RegExReplace(current, "^v", "")
        latest := RegExReplace(latest, "^v", "")

        ; 分割版本号
        currentParts := StrSplit(current, ".")
        latestParts := StrSplit(latest, ".")

        ; 确保至少有 3 个部分
        while currentParts.Length < 3
            currentParts.Push("0")
        while latestParts.Length < 3
            latestParts.Push("0")

        ; 逐部分比较
        Loop 3 {
            c := Integer(currentParts[A_Index])
            l := Integer(latestParts[A_Index])

            if (c < l)
                return -1
            if (c > l)
                return 1
        }

        return 0
    }

    ; -------------------------------------------------
    ; 私有方法：显示更新结果
    ; -------------------------------------------------
    _ShowUpdateResult(type, info) {
        switch type {
            case "update":
                result := MsgBox(
                    "发现新版本！`n`n"
                    "当前版本: v" AboutDialog.Version "`n"
                    "最新版本: v" info.version "`n`n"
                    (info.body ? "更新说明:`n" SubStr(info.body, 1, 200) "`n`n" : "")
                    "是否打开下载页面？",
                    "发现更新",
                    "YesNo Iconx"
                )

                if (result = "Yes" && info.url)
                    Run(info.url)

            case "latest":
                MsgBox(
                    "当前已是最新版本！`n`n"
                    "当前版本: v" AboutDialog.Version "`n"
                    "最新版本: v" info.version,
                    "检查更新",
                    "64"
                )

            case "no_release":
                result := MsgBox(
                    "GitHub 仓库尚未发布任何版本。`n`n"
                    "当前本地版本: v" AboutDialog.Version "`n`n"
                    "是否打开 GitHub 仓库页面？",
                    "检查更新",
                    "YesNo Icon!"
                )

                if (result = "Yes")
                    Run(AboutDialog.Website)

            case "error":
                MsgBox(info, "检查更新失败", "48")
        }
    }
}
