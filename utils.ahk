#Requires AutoHotkey v2.0

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
