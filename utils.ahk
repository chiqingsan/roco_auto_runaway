#Requires AutoHotkey v2.0


; if !A_IsAdmin {
;     Run '*RunAs "' A_ScriptFullPath '"'
;     ExitApp
; }

class TaskQueue {
    __New(interval := 100) {
        this.queue := []
        this.running := false
        this.interval := interval
        this._currentTimer := ""
    }

    ; Add a wait task. actionFn runs when condFn returns true.
    AddWait(condFn, actionFn) {
        this.queue.Push({
            type: "wait",
            cond: condFn,
            action: actionFn
        })
    }

    ; Add a one-shot delay task.
    AddDelay(delay, actionFn) {
        this.queue.Push({
            type: "delay",
            delay: delay,
            action: actionFn
        })
    }

    ; Start processing queued tasks.
    Start() {
        if this.running
            return

        this.running := true
        this._runNext()
    }

    ; Stop processing without clearing the queue.
    Stop() {
        this._stopCurrentTimer()
        this.running := false
    }

    ; Clear queued tasks and stop the active timer.
    Clear() {
        this.Stop()
        this.queue := []
    }

    ; Return queued task count.
    Size() {
        return this.queue.Length
    }

    ; Return whether the queue is active.
    IsRunning() {
        return this.running
    }

    _runNext() {
        this._stopCurrentTimer()

        if !this.running
            return

        if (this.queue.Length = 0) {
            this.running := false
            return
        }

        task := this.queue.RemoveAt(1)

        if (task.type = "wait") {
            this._runWaitTask(task)
        } else if (task.type = "delay") {
            this._runDelayTask(task)
        }
    }

    _runWaitTask(task) {
        this._currentTimer := ObjBindMethod(this, "_checkWaitTask", task)
        SetTimer(this._currentTimer, this.interval)
    }

    _checkWaitTask(task) {
        if !this.running {
            this._stopCurrentTimer()
            return
        }

        if task.cond.Call() {
            this._stopCurrentTimer()
            task.action.Call()
            this._runNext()
        }
    }

    _runDelayTask(task) {
        this._currentTimer := ObjBindMethod(this, "_runDelayTaskNow", task)
        SetTimer(this._currentTimer, -task.delay)
    }

    _runDelayTaskNow(task) {
        this._stopCurrentTimer()

        if !this.running
            return

        task.action.Call()
        this._runNext()
    }

    _stopCurrentTimer() {
        if this._currentTimer {
            SetTimer(this._currentTimer, 0)
            this._currentTimer := ""
        }
    }
}


class DD {
    static isInit := false


    ; =========================
    ; 初始化 DLL
    ; =========================
    static dll := ""

    static Init() {
        if !DllCall("LoadLibrary", "Str", A_ScriptDir "\dd63330.dll", "Ptr")
            throw Error("DD DLL 加载失败")

        ; 初始化检测（mouse test）
        r := this.Btn(0)
        if (r != 1)
            throw Error("DD 初始化失败，返回：" r)
        this.isInit := true
        return true
    }

    ; =========================
    ; 内部调用封装
    ; =========================
    static Call1(fn, p1) {
        return DllCall("dd63330.dll\" fn, "Int", p1)
    }

    static Call2(fn, p1, p2) {
        return DllCall("dd63330.dll\" fn, "Int", p1, "Int", p2)
    }

    static CallStr(fn, p1) {
        return DllCall("dd63330.dll\" fn, "Str", p1)
    }

    ; =========================
    ; 鼠标
    ; =========================
    ; 鼠标操作码 code：1 =左键按下 ，2 =左键放开4 = 右键按下 ，8 = 右键放开16 = 中键按下 ，32 = 中键放开 64 = 4键按下 ，128 = 4键放开256 = 5键按下 ，512 = 5键放开
    static Btn(code) {
        return DllCall("dd63330.dll\DD_btn", "Int", code)
    }

    ; 鼠标移动 绝对坐标
    static Move(x, y) {
        return DllCall("dd63330.dll\DD_mov", "Int", x, "Int", y)
    }

    ; 鼠标移动 相对坐标
    static MoveR(dx, dy) {
        return DllCall("dd63330.dll\DD_movR", "Int", dx, "Int", dy)
    }

    ; 鼠标滚轮 dir: 1=前 , 2 = 后
    static Wheel(dir) {
        return DllCall("dd63330.dll\DD_whl", "Int", dir)
    }

    ; =========================
    ; 键盘
    ; =========================
    static Key(code, down := true) {
        return DllCall("dd63330.dll\DD_key", "Int", code, "Int", down ? 1 : 2)
    }

    static KeyDown(code) {
        return this.Key(code, true)
    }

    static KeyUp(code) {
        return this.Key(code, false)
    }

    ; =========================
    ; 字符输入
    ; =========================
    static Str(text) {
        return DllCall("dd63330.dll\DD_str", "Str", text)
    }

    ; 高级方法 key 按键, time 按下的时间
    static SendKey(key, time := 50) {
        if !this.isInit
            return -1

        code := this.getKeyCode(key)
        if (code != -1) {
            this.KeyDown(code)
            if (time > 0)
                Sleep(time)
            return this.KeyUp(code)
        }
    }

    ; 高级方法, 鼠标点击xy坐标, btn: left right middle
    static Click_xy(x, y, btn := "left") {
        if !this.isInit
            return -1

        this.Move(x, y)
        Sleep(20)

        code := 0
        if (btn = "left")
            code := 1
        else if (btn = "right")
            code := 4
        else if (btn = "middle")
            code := 16
        else
            return -1

        this.Btn(code) ; down
        Sleep(50)
        return this.Btn(code * 2) ; up
    }

    ; 鼠标点击当前位置
    static Click(btn := "left") {
        if !this.isInit
            return -1

        code := 0
        if (btn = "left")
            code := 1
        else if (btn = "right")
            code := 4
        else if (btn = "middle")
            code := 16
        else
            return -1

        this.Btn(code) ; down
        Sleep(50)
        return this.Btn(code * 2) ; up
    }


    ; 键位码
    static KeyMap := Map(
        ; 数字
        "1", 201, "2", 202, "3", 203, "4", 204, "5", 205, "6", 206, "7", 207, "8", 208, "9", 209, "0", 210,
        ; QWER
        "q", 301, "w", 302, "e", 303, "r", 304, "t", 305, "y", 306, "u", 307, "i", 308, "o", 309, "p", 310,
        ; ASDF
        "a", 401, "s", 402, "d", 403, "f", 404, "g", 405, "h", 406, "j", 407, "k", 408, "l", 409,
        ; ZXCV
        "z", 501, "x", 502, "c", 503, "v", 504, "b", 505, "n", 506, "m", 507,
        ; 功能键
        "f1", 101, "f2", 102, "f3", 103, "f4", 104, "f5", 105, "f6", 106, "f7", 107, "f8", 108, "f9", 109, "f10", 110, "f11", 111, "f12", 112,
        ; 控制键
        "shift", 500, "ctrl", 600, "alt", 602, "space", 603, "tab", 300, "enter", 313, "esc", 100,
        ; 方向键
        "up", 709, "down", 711, "left", 710, "right", 712)


    ; 获取键位码，返回 -1 表示未找到
    static getKeyCode(key) {
        ; 统一转小写
        key := StrLower(key)
        code := this.KeyMap.Get(key, -1)

        if !code
            return -1

        return code
    }
}