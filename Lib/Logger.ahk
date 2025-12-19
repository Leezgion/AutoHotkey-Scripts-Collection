; =================================================
; 📦 Logger.ahk - 日志系统
; =================================================
; 功能：分级日志、文件输出、调试支持
; =================================================

; -------------------------------------------------
; 📊 日志级别枚举
; -------------------------------------------------
class LogLevel {
    static DEBUG := 0
    static INFO := 1
    static WARN := 2
    static ERROR := 3
    static NONE := 99

    static FromString(str) {
        switch StrUpper(str) {
            case "DEBUG": return this.DEBUG
            case "INFO": return this.INFO
            case "WARN", "WARNING": return this.WARN
            case "ERROR": return this.ERROR
            default: return this.INFO
        }
    }

    static ToString(level) {
        switch level {
            case this.DEBUG: return "DEBUG"
            case this.INFO: return "INFO"
            case this.WARN: return "WARN"
            case this.ERROR: return "ERROR"
            default: return "UNKNOWN"
        }
    }
}

; -------------------------------------------------
; 📝 日志管理器类
; -------------------------------------------------
class Logger {
    static _level := LogLevel.INFO
    static _toFile := false
    static _filePath := ""
    static _maxSize := 1048576  ; 1MB
    static _initialized := false
    static _buffer := []
    static _bufferSize := 10

    ; -------------------------------------------------
    ; Init - 初始化日志系统
    ; -------------------------------------------------
    static Init(level := "INFO", toFile := false, filePath := "") {
        this._level := LogLevel.FromString(level)
        this._toFile := toFile
        this._filePath := filePath != "" ? filePath : A_ScriptDir "\Config\app.log"
        this._initialized := true

        ; 确保日志目录存在
        if this._toFile {
            SplitPath(this._filePath, , &dir)
            if !DirExist(dir)
                DirCreate(dir)

            ; 检查日志文件大小，必要时轮转
            this._RotateIfNeeded()
        }

        this.Info("Logger initialized - Level: " LogLevel.ToString(this._level))
    }

    ; -------------------------------------------------
    ; SetLevel - 动态设置日志级别
    ; -------------------------------------------------
    static SetLevel(level) {
        this._level := LogLevel.FromString(level)
    }

    ; -------------------------------------------------
    ; Debug - 调试日志
    ; -------------------------------------------------
    static Debug(message, context := "") {
        this._Log(LogLevel.DEBUG, message, context)
    }

    ; -------------------------------------------------
    ; Info - 信息日志
    ; -------------------------------------------------
    static Info(message, context := "") {
        this._Log(LogLevel.INFO, message, context)
    }

    ; -------------------------------------------------
    ; Warn - 警告日志
    ; -------------------------------------------------
    static Warn(message, context := "") {
        this._Log(LogLevel.WARN, message, context)
    }

    ; -------------------------------------------------
    ; Error - 错误日志
    ; -------------------------------------------------
    static Error(message, context := "") {
        this._Log(LogLevel.ERROR, message, context)
    }

    ; -------------------------------------------------
    ; 私有方法：核心日志函数
    ; -------------------------------------------------
    static _Log(level, message, context) {
        if level < this._level
            return

        ; 格式化时间戳
        timestamp := FormatTime(, "yyyy-MM-dd HH:mm:ss")
        levelStr := LogLevel.ToString(level)

        ; 构建日志行
        logLine := "[" timestamp "] [" levelStr "]"
        if context != ""
            logLine .= " [" context "]"
        logLine .= " " message

        ; 输出到调试器
        OutputDebug(logLine)

        ; 输出到文件
        if this._toFile {
            this._buffer.Push(logLine)
            if this._buffer.Length >= this._bufferSize
                this._Flush()
        }

        ; 错误级别额外显示 ToolTip
        if level >= LogLevel.ERROR {
            ToolTip("❌ " message)
            SetTimer(() => ToolTip(), -3000)
        }
    }

    ; -------------------------------------------------
    ; Flush - 刷新缓冲区到文件
    ; -------------------------------------------------
    static Flush() {
        this._Flush()
    }

    static _Flush() {
        if this._buffer.Length = 0
            return

        try {
            content := ""
            for line in this._buffer
                content .= line "`n"

            FileAppend(content, this._filePath, "UTF-8")
            this._buffer := []
        } catch as e {
            OutputDebug("Logger flush failed: " e.Message)
        }
    }

    ; -------------------------------------------------
    ; 私有方法：日志轮转
    ; -------------------------------------------------
    static _RotateIfNeeded() {
        if !FileExist(this._filePath)
            return

        try {
            fileSize := FileGetSize(this._filePath)
            if fileSize > this._maxSize {
                ; 备份旧日志
                backupPath := this._filePath ".bak"
                if FileExist(backupPath)
                    FileDelete(backupPath)
                FileMove(this._filePath, backupPath)
            }
        }
    }

    ; -------------------------------------------------
    ; Clear - 清空日志文件
    ; -------------------------------------------------
    static Clear() {
        if FileExist(this._filePath) {
            try FileDelete(this._filePath)
        }
        this._buffer := []
    }

    ; -------------------------------------------------
    ; GetRecent - 获取最近的日志行
    ; -------------------------------------------------
    static GetRecent(count := 50) {
        if !FileExist(this._filePath)
            return []

        try {
            content := FileRead(this._filePath, "UTF-8")
            lines := StrSplit(content, "`n")

            ; 返回最后 N 行
            result := []
            startIdx := Max(1, lines.Length - count + 1)
            loop lines.Length - startIdx + 1 {
                line := lines[startIdx + A_Index - 1]
                if Trim(line) != ""
                    result.Push(line)
            }
            return result
        } catch {
            return []
        }
    }
}

; -------------------------------------------------
; 🔧 便捷函数
; -------------------------------------------------

LogD(msg, ctx := "") => Logger.Debug(msg, ctx)
LogI(msg, ctx := "") => Logger.Info(msg, ctx)
LogW(msg, ctx := "") => Logger.Warn(msg, ctx)
LogE(msg, ctx := "") => Logger.Error(msg, ctx)