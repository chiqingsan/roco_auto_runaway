#Requires AutoHotkey v2.0

class LocalFileLogger {
    static logDir := A_ScriptDir "\logs"
    static filePath := ""
    static splitByDate := true

    static enableDebug := true
    static enabled := true   ; 总开关
    static version := ""  ; 版本号，如果有则自动添加到日志文件名中

    ; 最大 30KB
    static maxSize := 30 * 1024

    static init(dir := "", splitByDate := true) {
        if !this.enabled
            return

        if (dir != "")
            this.logDir := dir

        this.splitByDate := splitByDate

        if !DirExist(this.logDir)
            DirCreate(this.logDir)

        this.updateFilePath()
    }

    static updateFilePath() {
        if !this.enabled
            return

        SplitPath(A_ScriptName, , , , &nameNoExt)

        this.filePath := this.logDir "\" nameNoExt ".log"
    }

    static write(level, msg) {
        if !this.enabled
            return

        if (level = "DEBUG" && !this.enableDebug)
            return

        this.updateFilePath()
        this.truncateIfNeeded()

        time := FormatTime(, "yyyy-MM-dd  HH:mm:ss")

        line := Format(
            "[{}]  [{:-5}]{}  |   {}",
            time,
            level,
            this.version ? Format("  (v{})", this.version) : "",
            msg
        ) "`n"

        FileAppend(line, this.filePath, "UTF-8")
    }

    static truncateIfNeeded() {
        if !this.enabled
            return

        if !FileExist(this.filePath)
            return

        size := FileGetSize(this.filePath)
        if (size < this.maxSize)
            return

        keepSize := this.maxSize // 2  ; 保留后一半

        file := FileOpen(this.filePath, "r")
        file.Seek(-keepSize, 2)
        data := file.Read()
        file.Close()

        ; 保证从完整行开始
        pos := InStr(data, "`n")
        if (pos > 0) {
            data := SubStr(data, pos + 1)
        }

        FileDelete(this.filePath)
        FileAppend(data, this.filePath, "UTF-8")
    }

    static info(msg) {
        this.write("INFO", msg)
    }

    static warn(msg) {
        this.write("WARN", msg)
    }

    static error(msg) {
        this.write("ERROR", msg)
    }

    static debug(msg) {
        this.write("DEBUG", msg)
    }
}