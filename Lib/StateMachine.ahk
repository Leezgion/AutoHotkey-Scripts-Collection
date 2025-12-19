; =================================================
; 📦 StateMachine.ahk - 通用状态机实现
; =================================================
; 功能：状态管理、转换验证、生命周期回调、历史记录
; =================================================

; -------------------------------------------------
; 🔄 状态机基类
; -------------------------------------------------
class StateMachine {
    ; -------------------------------------------------
    ; __New - 构造函数
    ; 参数: name - 状态机名称
    ;       initialState - 初始状态
    ; -------------------------------------------------
    __New(name := "FSM", initialState := "IDLE") {
        ; 使用 DefineProp 确保属性可以在子类中正确继承
        this.DefineProp("_currentState", {Value: initialState})
        this.DefineProp("_previousState", {Value: ""})
        this.DefineProp("_initialState", {Value: initialState})
        this.DefineProp("_states", {Value: Map()})
        this.DefineProp("_transitions", {Value: Map()})
        this.DefineProp("_onEnter", {Value: Map()})
        this.DefineProp("_onExit", {Value: Map()})
        this.DefineProp("_onTransition", {Value: Map()})
        this.DefineProp("_history", {Value: []})
        this.DefineProp("_maxHistory", {Value: 20})
        this.DefineProp("_name", {Value: name})
        this.DefineProp("_debug", {Value: false})
    }

    ; -------------------------------------------------
    ; DefineStates - 定义有效状态
    ; 参数: states - 状态数组，如 ["IDLE", "RUNNING", "PAUSED"]
    ; -------------------------------------------------
    DefineStates(states) {
        this._states := Map()
        for state in states {
            this._states[state] := true
        }
        return this
    }

    ; -------------------------------------------------
    ; AddTransition - 添加状态转换规则
    ; 参数: from - 源状态（或数组表示多个源）
    ;       event - 触发事件
    ;       to - 目标状态
    ; -------------------------------------------------
    AddTransition(from, event, to) {
        if from is Array {
            for f in from {
                this._AddSingleTransition(f, event, to)
            }
        } else {
            this._AddSingleTransition(from, event, to)
        }
        return this
    }

    _AddSingleTransition(from, event, to) {
        key := from ":" event
        this._transitions[key] := to
    }

    ; -------------------------------------------------
    ; OnEnter - 注册进入状态回调
    ; -------------------------------------------------
    OnEnter(state, callback) {
        this._onEnter[state] := callback
        return this
    }

    ; -------------------------------------------------
    ; OnExit - 注册退出状态回调
    ; -------------------------------------------------
    OnExit(state, callback) {
        this._onExit[state] := callback
        return this
    }

    ; -------------------------------------------------
    ; OnTransition - 注册转换回调
    ; 参数: from - 源状态 (可选，"*" 表示任意)
    ;       to - 目标状态 (可选，"*" 表示任意)
    ;       callback - 回调函数
    ; -------------------------------------------------
    OnTransition(from, to, callback) {
        key := from ":" to
        this._onTransition[key] := callback
        return this
    }

    ; -------------------------------------------------
    ; Trigger - 触发事件
    ; 参数: event - 事件名称
    ;       data - 可选的附加数据
    ; 返回: true=转换成功, false=转换失败
    ; -------------------------------------------------
    Trigger(event, data := "") {
        key := this._currentState ":" event

        ; 检查是否有有效转换
        if !this._transitions.Has(key) {
            this._Debug("No transition for event '" event "' in state '" this._currentState "'")
            return false
        }

        newState := this._transitions[key]
        return this._ChangeState(newState, event, data)
    }

    ; -------------------------------------------------
    ; CanTrigger - 检查事件是否可触发
    ; -------------------------------------------------
    CanTrigger(event) {
        key := this._currentState ":" event
        return this._transitions.Has(key)
    }

    ; -------------------------------------------------
    ; ForceState - 强制设置状态（跳过转换验证）
    ; -------------------------------------------------
    ForceState(state, skipCallbacks := false) {
        if !skipCallbacks
            this._ChangeState(state, "FORCE", "")
        else {
            this._previousState := this._currentState
            this._currentState := state
            this._AddHistory(state, "FORCE")
        }
    }

    ; -------------------------------------------------
    ; Reset - 重置到初始状态
    ; -------------------------------------------------
    Reset() {
        this._ChangeState(this._initialState, "RESET", "")
        this._history := []
    }

    ; -------------------------------------------------
    ; 属性访问器
    ; -------------------------------------------------
    State {
        get => this._currentState
    }

    PreviousState {
        get => this._previousState
    }

    IsState(state) {
        return this._currentState = state
    }

    History {
        get => this._history.Clone()
    }

    ; -------------------------------------------------
    ; EnableDebug - 启用调试模式
    ; -------------------------------------------------
    EnableDebug(enable := true) {
        this._debug := enable
        return this
    }

    ; -------------------------------------------------
    ; 私有方法：状态切换
    ; -------------------------------------------------
    _ChangeState(newState, event, data) {
        oldState := this._currentState

        ; 验证状态有效性
        if this._states.Count > 0 && !this._states.Has(newState) {
            this._Debug("Invalid state: " newState)
            return false
        }

        ; 执行退出回调
        if this._onExit.Has(oldState) {
            try {
                this._onExit[oldState](oldState, newState, data)
            } catch as e {
                this._Debug("OnExit callback error: " e.Message)
            }
        }

        ; 切换状态
        this._previousState := oldState
        this._currentState := newState

        ; 记录历史
        this._AddHistory(newState, event)

        ; 执行转换回调
        this._ExecuteTransitionCallbacks(oldState, newState, data)

        ; 执行进入回调
        if this._onEnter.Has(newState) {
            try {
                this._onEnter[newState](newState, oldState, data)
            } catch as e {
                this._Debug("OnEnter callback error: " e.Message)
            }
        }

        this._Debug(oldState " --[" event "]--> " newState)
        return true
    }

    ; -------------------------------------------------
    ; 私有方法：执行转换回调
    ; -------------------------------------------------
    _ExecuteTransitionCallbacks(from, to, data) {
        ; 精确匹配
        key := from ":" to
        if this._onTransition.Has(key) {
            try {
                this._onTransition[key](from, to, data)
            }
        }

        ; 通配符匹配: *:to
        key := "*:" to
        if this._onTransition.Has(key) {
            try {
                this._onTransition[key](from, to, data)
            }
        }

        ; 通配符匹配: from:*
        key := from ":*"
        if this._onTransition.Has(key) {
            try {
                this._onTransition[key](from, to, data)
            }
        }

        ; 通配符匹配: *:*
        key := "*:*"
        if this._onTransition.Has(key) {
            try {
                this._onTransition[key](from, to, data)
            }
        }
    }

    ; -------------------------------------------------
    ; 私有方法：添加历史记录
    ; -------------------------------------------------
    _AddHistory(state, event) {
        timestamp := A_TickCount
        this._history.Push({
            state: state,
            event: event,
            time: timestamp
        })

        ; 限制历史长度
        while this._history.Length > this._maxHistory {
            this._history.RemoveAt(1)
        }
    }

    ; -------------------------------------------------
    ; 私有方法：调试输出
    ; -------------------------------------------------
    _Debug(msg) {
        if this._debug
            OutputDebug("[" this._name "] " msg)
    }

    ; -------------------------------------------------
    ; ToString - 调试字符串
    ; -------------------------------------------------
    ToString() {
        return this._name ": " this._currentState
    }
}

; -------------------------------------------------
; 🎨 屏幕取色专用状态机
; -------------------------------------------------
class ColorPickerFSM extends StateMachine {
    __New() {
        super.__New("ColorPicker", "IDLE")

        this.DefineStates(["IDLE", "INIT", "PICKING", "COPYING", "CLEANUP"])

        ; 定义转换规则
        this.AddTransition("IDLE", "START", "INIT")
        this.AddTransition("INIT", "READY", "PICKING")
        this.AddTransition("INIT", "ERROR", "IDLE")
        this.AddTransition("PICKING", "CLICK", "COPYING")
        this.AddTransition("PICKING", "CANCEL", "CLEANUP")
        this.AddTransition("COPYING", "DONE", "CLEANUP")
        this.AddTransition("CLEANUP", "DONE", "IDLE")
    }
}

; -------------------------------------------------
; 📸 截图悬浮专用状态机
; -------------------------------------------------
class ScreenshotFSM extends StateMachine {
    __New() {
        super.__New("Screenshot", "IDLE")

        this.DefineStates(["IDLE", "OVERLAY", "SELECTING", "CAPTURING", "FLOATING"])

        ; 定义转换规则
        this.AddTransition("IDLE", "START", "OVERLAY")
        this.AddTransition("OVERLAY", "MOUSEDOWN", "SELECTING")
        this.AddTransition("OVERLAY", "CANCEL", "IDLE")
        this.AddTransition("SELECTING", "MOUSEUP", "CAPTURING")
        this.AddTransition("SELECTING", "CANCEL", "IDLE")
        this.AddTransition("CAPTURING", "DONE", "FLOATING")
        this.AddTransition("CAPTURING", "ERROR", "IDLE")
        this.AddTransition("FLOATING", "CLOSE", "IDLE")
    }
}

; -------------------------------------------------
; 📌 置顶窗口状态（窗口级别，非全局状态机）
; -------------------------------------------------
class PinWindowState {
    static Normal := "NORMAL"
    static Pinned := "PINNED"
    static Flashing := "FLASHING"
    static Dragging := "DRAGGING"
}
