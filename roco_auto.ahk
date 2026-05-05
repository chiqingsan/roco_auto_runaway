#Requires AutoHotkey v2.0
#SingleInstance Force
CoordMode "Pixel", "Screen"

#Include localFileLogger.ahk
; #Include utils.ahk


VERSION := "1.5"
DEBUG_LOCALLOG := true  ; 是否开启本地调试日志

class Config {
    static width := A_ScreenWidth
    static height := A_ScreenHeight

    static scaleX := A_ScreenWidth / 2560
    static scaleY := A_ScreenHeight / 1440
}


; 当前运行状态
class RunningStatus {
    ; 是否启动自动聚气/逃跑 0: 关闭 1:自动聚气 2:自动逃跑
    static avoidWarState := 0

    ; 是否启用自动牵手功能
    static isHoldHandsAutomatically := false

    ; 是否启动自动战斗技能
    static automaticallyUseSkills := false

    ; 当前ui状态, 0: 隐藏, 1: 显示
    static uiState := 1
}


; ui实例类
class UIClass {
    static ui := ""  ;main gui
    static gatherEnergyBtn := ""  ; 自动聚气按钮
    static useSkills := "" ; 自动使用技能1
    static runAwayBtn := ""  ; 自动逃跑按钮
    static HoldHandsAutomaticallyBtn := ""  ; 自动牵手按钮
    static automaticallyUseSkillsBtn := ""  ; 自动使用技能按钮
    static logBox := ""  ; 日志显示框
}


; 特征区域特征
class IdentifyingFeatureInformation {
    ; 获取转换后的特征区域对象
    static getConvertedIdentifyingFeatureRegion(region) {
        return {
            left: Round(region.left * Config.scaleX),
            top: Round(region.top * Config.scaleY),
            right: Round(region.right * Config.scaleX),
            bottom: Round(region.bottom * Config.scaleY),
            colors: region.colors.Clone()
        }
    }


    ; 左上角的大世界徽标区域 420x180
    static starLogo := {
        left: 0,
        top: 0,
        right: 420,
        bottom: 180,
        ; 特征色值
        colors: [0x2469ba, 0x64d1fd, 0x266ebd, 0x73c615, 0x5ca011]
    }


    ; 进入战斗后, 左上角的精灵血条信息区域 420x180
    static hpInformation := {
        left: 0,
        top: 0,
        right: 420,
        bottom: 180,
        ; 特征色值
        colors: [0xffc65f, 0x3d3d3d, 0x79786f, 0xf4eee1, 0xffffff]
    }


    ; 换人界面左下角的绿色心区域
    static greenLove := {
        left: 88,
        top: 1156,
        right: 322 + 88,
        bottom: 201 + 1156,
        colors: [0x85c13c, 0x65a617, 0x3d3d3d, 0x66a619, 0xffffff]
    }

    ; 左下角的聚能图标区域
    static gatherEnergy := {
        left: 0,
        top: 1150,
        right: 250,
        bottom: 1440,
        colors: [0xffc65f, 0x272727, 0xf4eee1]
    }


    ; 牵手的图标区域
    static holdHands := {
        left: 1343,
        top: 628,
        right: 638 + 1343,
        bottom: 337 + 628,
        colors: [0xdc9827, 0xfaf3e4, 0xf4eee1, 0x272727, 0x3d3d3d, 0xffffff] ;0x2a2928, 0xf4ba53
    }


    ; 敌方污染精灵血条的图标区域
    static enemyHpBarRegion := {
        left: 2096,
        top: 0,
        right: 464 + 2096,
        bottom: 192 + 0,
        colors: [0xffc65f, 0xff3fa1, 0xf4eee1, 0x3d3d3d, 0xf4eee1, 0xffffff]
    }

    ; 敌方污染被击败后真实血条的图标区域
    static enemyCatchableRegion := {
        left: 2096,
        top: 0,
        right: 464 + 2096,
        bottom: 192 + 0,
        colors: [0xffc65f, 0x272727, 0xfd0176, 0xaf3d3e, 0xf4eee1, 0x3d3d3d] ;, 0xf4eee1, 0xffffff
    }

    ; 敌方污染击败后异色出现的图标区域
    static shinyElfIndicatorRegion := {
        left: 1407,
        top: 344,
        right: 629 + 1407,
        bottom: 656 + 344,
        colors: [0x39a2cb, 0xfdc55e, 0xf4eee1, 0xf5bf5b]
    }

    ; 进战后右下角的捕捉按钮区域
    static captureButtonRegion := {
        left: 2124,
        top: 1234,
        right: 126 + 2124,
        bottom: 185 + 1234,
        colors: [0xb9b3ab, 0x2e252a, 0xf4eee1, 0x272727]
    }
}


; 咕噜球的特征
class GuluBallIdentifyingFeature {
    ; 捕捉球的图标区域
    static captureBall := {
        left: 208,
        top: 313,
        right: 562 + 208,
        bottom: 882 + 313,
        colors: []
    }

    ; 捕光球
    static buguang := {
        colors: [0xffffd5, 0x3e4cc8, 0xff293, 0xf1d186, 0xe7cd83]
    }
}


; 零散的色值
class ScatteredColors {
    ; 左上角血条颜色 绿色 健康
    static HealthBarColor1 := 0x73c615
    ; 左上角血条颜色 黄色 受伤
    static HealthBarColor2 := 0xfcb641
    ; 左上角血条颜色 红色 濒死
    static HealthBarColor3 := 0xaf3d3e
}


; 简化一下获取转换后的特征区域对象的函数调用
GetScaledIdentifyingFeatureRegion(region) {
    return IdentifyingFeatureInformation.getConvertedIdentifyingFeatureRegion(region)
}


; 判断一个区域内是否包含了所有特征色值, deviationValue是色值误差范围, 默认10
AreaHasAllFeatureColors(region, deviationValue := 10) {
    convertedRegion := GetScaledIdentifyingFeatureRegion(region)
    errorNum := 0
    errorColor := 0

    for index, color in convertedRegion.colors {
        if !PixelSearch(&_, &_, convertedRegion.left, convertedRegion.top, convertedRegion.right, convertedRegion.bottom,
            color, deviationValue) {
            ; 如果第一个色值就检测出错了就, 直接返回false
            if index == 1 {
                return false
            }

            if index > 1 {
                LocalFileLogger.debug(Format("检测色值失败, 失败色值: #{:06x}, 当前检测宽容度: {:02}, 当前匹配进度为 {:02}", color, deviationValue, index))
            }
            errorNum++
            errorColor := color

            if errorNum > 1 {
                return false
            }
        }
    }


    if errorNum != 0 {
        deviationValue += 10
        LocalFileLogger.debug(Format("当前色值组中有一项色值检测失败, 启动复检, 复检色值: #{:06x}, 增加检测宽容度: {:02}", errorColor, deviationValue))
        if !PixelSearch(&_, &_, convertedRegion.left, convertedRegion.top, convertedRegion.right, convertedRegion.bottom,
            errorColor, deviationValue) {
            LocalFileLogger.debug(Format("复检失败, 失败色值: #{:06x}, 当前检测宽容度: {:02}", errorColor, deviationValue))
            return false
        }
        LocalFileLogger.debug(Format("复检成功, 复检色值: #{:06x}, 当前检测宽容度: {:02}", errorColor, deviationValue))
    }

    return true
}


; ================== GUI ==================
InitGui() {
    if FileExist("app.ico") {
        TraySetIcon("app.ico", 1, true)
    }

    ui := Gui("-Resize -MaximizeBox -MinimizeBox +AlwaysOnTop")
    ui.Title := "洛克王国  自动避战 v" VERSION


    ; --- 不抢焦点 ---
    hwnd := ui.Hwnd
    exStyle := DllCall("GetWindowLongPtr", "Ptr", hwnd, "Int", -20, "Ptr")
    DllCall("SetWindowLongPtr", "Ptr", hwnd, "Int", -20, "Ptr", exStyle | 0x08000000)

    OnMessage(0x21, WM_MOUSEACTIVATE)
    WM_MOUSEACTIVATE(*) {
        return 3  ; MA_NOACTIVATE
    }

    ; --- 按钮 ---
    UIClass.gatherEnergyBtn := ui.AddButton("y+3 w95 h30", "自动聚气: 关")
    UIClass.gatherEnergyBtn.OnEvent("Click", onClickGatherEnergyBtn)

    UIClass.runAwayBtn := ui.AddButton("xm y+5 w95 h30", "自动逃跑: 关")
    UIClass.runAwayBtn.OnEvent("Click", onClickRunAwayBtn)

    UIClass.useSkills := ui.AddButton("xm y+5 w95 h30", "后台技能: 关")
    UIClass.useSkills.OnEvent("Click", onClickUseSkillsBtn)

    UIClass.HoldHandsAutomaticallyBtn := ui.AddButton("xm y+5 w95 h30", "自动牵手: 关")
    UIClass.HoldHandsAutomaticallyBtn.OnEvent("Click", onHoldHandsAutomaticallyBtn)

    UIClass.automaticallyUseSkillsBtn := ui.AddButton("xm y+5 w95 h30", "自动战斗: 关")
    UIClass.automaticallyUseSkillsBtn.OnEvent("Click", onClickAutomaticallyFightingBtn)


    ; testBtn := ui.AddButton("xm y+5 w95 h30", "测试按钮")
    ; testBtn.OnEvent("Click", SendOnce)

    ; GuiCtrl := ui.AddStatusBar("h30", "运行中...")

    UIClass.logBox := ui.AddEdit("ym x+6 w192 h165 ReadOnly -Border -VScroll -HScroll +Disabled")
    UIClass.logBox.SetFont("s9 c000000", "Consolas")


    ; 设置关闭事件, 关闭gui的时候关闭脚本
    ui.OnEvent("Close", GuiClose)  ; 绑定关闭事件

    GuiClose(*) {
        ExitApp()  ; 点击 X 时退出脚本
    }


    UIClass.ui := ui
    ; w315 h165
    ui.Show("w315 h180 NoActivate")
}


; ui快捷键隐藏/显示
QuickHide(*) {
    AddLog("快捷键触发, 切换UI显示/隐藏状态")
    if RunningStatus.uiState == 0 {
        UIClass.ui.Show("NoActivate")
        RunningStatus.uiState := 1
    } else {
        UIClass.ui.Hide()
        RunningStatus.uiState := 0
    }
}


; ================== 入口 ==================
Main() {
    ElevatePrivileges()
    InitGui()
    LocalFileLogger.enabled := DEBUG_LOCALLOG
    LocalFileLogger.version := VERSION
    LocalFileLogger.init()
    LocalFileLogger.info(Format("==========启动成功 工具版本 v{} , 当前屏幕分辨率: {}x{}==========", VERSION, Config.width, Config.height))
    AddLog(Format("启动成功 工具版本 v{} , 当前屏幕分辨率: {}x{}", VERSION, Config.width, Config.height))
    ; 监听按键隐藏/显示ui
    Hotkey("~f9", QuickHide)
}
Main()

; ================== 管理员提权 ==================
ElevatePrivileges() {
    if !A_IsAdmin {
        Run('*RunAs "' A_ScriptFullPath '"')
        ExitApp
    }
}


; 根据输入的xy坐标, 绘制一个十字准心, 来标识该点位
DrawAccurate(x, y, size := 20, w := 2, time := 2000) {
    g1 := Gui("+AlwaysOnTop -Caption +ToolWindow")
    g1.BackColor := "Red"
    g1.Show("x" (x - size) " y" y " w" (size * 2) " h" w " NA")

    g2 := Gui("+AlwaysOnTop -Caption +ToolWindow")
    g2.BackColor := "Red"
    g2.Show("x" x " y" (y - size) " w" w " h" (size * 2) " NA")

    SetTimer((*) => (g1.Destroy(), g2.Destroy()), -time)
}


; 根据输入的区域坐标, left top right bottom, 绘制一个矩形框, 来标识该区域
DrawRectangle(left, top, right, bottom, w := 2, time := 2000) {
    ; 计算宽高
    width := right - left
    height := bottom - top

    ; 上边
    gTop := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20")
    gTop.BackColor := "Red"
    gTop.Show("x" left " y" top " w" width " h" w " NA")

    ; 下边
    gBottom := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20")
    gBottom.BackColor := "Red"
    gBottom.Show("x" left " y" (bottom - w) " w" width " h" w " NA")

    ; 左边
    gLeft := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20")
    gLeft.BackColor := "Red"
    gLeft.Show("x" left " y" top " w" w " h" height " NA")

    ; 右边
    gRight := Gui("+AlwaysOnTop -Caption +ToolWindow +E0x20")
    gRight.BackColor := "Red"
    gRight.Show("x" (right - w) " y" top " w" w " h" height " NA")

    ; 定时关闭
    SetTimer(() => (
        gTop.Destroy(),
        gBottom.Destroy(),
        gLeft.Destroy(),
        gRight.Destroy()
    ), -time)
}


; ================== 测试用 ==================
SendOnce(*) {
}


; ================== 激活游戏窗口 ==================
ActivateGameWindow(*) {
    hwnd := WinExist("ahk_exe NRC-Win64-Shipping.exe")
    if hwnd {
        ActivateWindowById(hwnd)
    }
}

ActivateWindowById(hwnd) {
    WinShow("ahk_id " hwnd)
    WinRestore("ahk_id " hwnd)
    Sleep(100)

    WinActivate("ahk_id " hwnd)
    return WinWaitActive("ahk_id " hwnd, , 2)
}


; 修改互斥的UI状态, 比如自动聚气, 自动逃跑, 后台技能是互斥的, 不能同时开启
ModifyMutuallyExclusiveUIStates() {
    if (RunningStatus.avoidWarState == 1) {
        UIClass.runAwayBtn.Text := "自动逃跑: 关"
        UIClass.useSkills.Text := "后台技能: 关"
    } else if (RunningStatus.avoidWarState == 2) {
        UIClass.gatherEnergyBtn.Text := "自动聚气: 关"
        UIClass.useSkills.Text := "后台技能: 关"
    } else if (RunningStatus.avoidWarState == 3) {
        UIClass.gatherEnergyBtn.Text := "自动聚气: 关"
        UIClass.runAwayBtn.Text := "自动逃跑: 关"
    } else if (RunningStatus.avoidWarState == 0) {
        UIClass.gatherEnergyBtn.Text := "自动聚气: 关"
        UIClass.runAwayBtn.Text := "自动逃跑: 关"
        UIClass.useSkills.Text := "后台技能: 关"
    }

    if RunningStatus.automaticallyUseSkills {
        UIClass.automaticallyUseSkillsBtn.Text := "自动战斗: 开"
    } else {
        UIClass.automaticallyUseSkillsBtn.Text := "自动战斗: 关"
    }
}


; 按键事件
; 自动聚气
onClickGatherEnergyBtn(ctrl, *) {
    if RunningStatus.avoidWarState != 1 {
        ; 修改一下状态
        RunningStatus.avoidWarState := 1
        RunningStatus.automaticallyUseSkills := false
        ; 修改按键文字
        ctrl.Text := "自动聚气: 开"
        ModifyMutuallyExclusiveUIStates()
        AddLog("自动聚气已开启")
        whetherFighting()
        return
    }

    ; 修改一下状态
    RunningStatus.avoidWarState := 0
    ; 修改按键文字
    ctrl.Text := "自动聚气: 关"
    AddLog("自动聚气已关闭")
}


; 自动逃跑
onClickRunAwayBtn(ctrl, *) {
    if RunningStatus.avoidWarState != 2 {
        ; 修改一下状态
        RunningStatus.avoidWarState := 2
        RunningStatus.automaticallyUseSkills := false
        ; 修改按键文字
        ctrl.Text := "自动逃跑: 开"
        ModifyMutuallyExclusiveUIStates()
        AddLog("自动逃跑已开启")
        whetherFighting()
        return
    }

    ; 修改一下状态
    RunningStatus.avoidWarState := 0
    ; 修改按键文字
    ctrl.Text := "自动逃跑: 关"
    AddLog("自动逃跑已关闭")
}


; 后台使用技能1
onClickUseSkillsBtn(ctrl, *) {

    if !ProcessExist("NRC-Win64-Shipping.exe") {
        AddLog("提示: 未检测到洛克王国游戏程序, 无法执行自动使用技能1")
        RunningStatus.avoidWarState := 0
        UIClass.useSkills.Text := "后台技能1: 关"
        return
    }


    if RunningStatus.avoidWarState != 3 {
        ; 修改一下状态
        RunningStatus.avoidWarState := 3
        RunningStatus.automaticallyUseSkills := false
        ; 修改按键文字
        ctrl.Text := "后台技能: 开"
        ModifyMutuallyExclusiveUIStates()
        AddLog("后台使用技能已开启")
        automaticallyUseSkill1()
        return
    }

    ; 修改一下状态
    RunningStatus.avoidWarState := 0
    ; 修改按键文字
    ctrl.Text := "后台技能: 关"
    AddLog("后台使用技能已关闭")
}


; 自动牵手
onHoldHandsAutomaticallyBtn(ctrl, *) {
    if !RunningStatus.isHoldHandsAutomatically {
        ; 修改一下状态
        RunningStatus.isHoldHandsAutomatically := true
        ; 修改按键文字
        ctrl.Text := "自动牵手: 开"
        AddLog("自动牵手已开启")
        automaticallyHoldHands()
        return
    }

    ; 修改一下状态
    RunningStatus.isHoldHandsAutomatically := false
    ; 修改按键文字
    ctrl.Text := "自动牵手: 关"
    AddLog("自动牵手已关闭")
}

; 自动战斗ui逻辑
onClickAutomaticallyFightingBtn(ctrl, *) {
    if !RunningStatus.automaticallyUseSkills {
        ; 修改一下状态
        RunningStatus.automaticallyUseSkills := true
        RunningStatus.avoidWarState := 0
        ; 修改按键文字
        ctrl.Text := "自动战斗: 开"
        ModifyMutuallyExclusiveUIStates()
        AddLog("自动战斗已开启")
        automaticallyFighting()
        return
    }

    ; 修改一下状态
    RunningStatus.automaticallyUseSkills := false
    ; 修改按键文字
    ctrl.Text := "自动战斗: 关"
    AddLog("自动战斗已关闭")
}


; 自动避战逻辑, 循环检查是否进战
whetherFighting() {
    ; 清理可能多余的定时任务
    SetTimer(whetherFighting, 0)

    ; 检查状态是否被关闭
    if RunningStatus.avoidWarState == 0 || RunningStatus.avoidWarState == 3 {
        return
    }

    AddLog("正在检查是否进入战斗...")
    if !isItInNormalCondition() && isEnterCombat() {
        if RunningStatus.avoidWarState == 1 {
            AddLog("进入战斗, 目前模式为: 自动聚气")
            ; 自动聚气
            collectEnergy()
        } else if RunningStatus.avoidWarState == 2 {
            AddLog("进入战斗, 目前模式为: 自动逃跑")
            ; 自动逃跑
            exitCombat()
        }
    }

    ; 1500ms检查一次是否进入了战斗
    SetTimer(whetherFighting, -1500)
}


; 判断是否进入了战斗
isEnterCombat() {
    if AreaHasAllFeatureColors(IdentifyingFeatureInformation.hpInformation, 12) && getHealthBarColor() > 0 {
        return true
    }

    return false
}


; 战斗中进行聚能
collectEnergy() {
    SetTimer(collectEnergy, 0)

    if RunningStatus.avoidWarState != 1 {
        return
    }


    ; 这里检查一下是否在换人界面, 如果在换人界面就说明精灵被打死了, 直接逃跑
    if AreaHasAllFeatureColors(IdentifyingFeatureInformation.greenLove) {
        AddLog("处于换人界面, 启用自动逃跑")
        ; 被打死了就逃跑
        exitCombat()
        return
    }

    ; 检查一下战斗是否结束了
    if isItInNormalCondition() {
        return
    }


    ; 检查一下是否还存在聚气图标
    if AreaHasAllFeatureColors(IdentifyingFeatureInformation.gatherEnergy) {
        ;还能聚气就一直聚气
        AddLog("执行操作: 自动聚气")
        SendKey('x')
    }

    ; 递归调用一下
    SetTimer(collectEnergy, -2500)
}


; esc退出战斗
exitCombat() {
    if !isItInNormalCondition() {
        Sleep(500)
        SendKey('Esc')
        Sleep(1000)
        if PixelSearch(&x, &y, Config.width * 0.5, Config.height * 0.7, Config.width, Config.height, 0xf4eee1, 5) {
            AddLog("执行操作: 自动逃跑")
            Click(x, y + 10)
        }
    }
}


; 自动牵手
automaticallyHoldHands() {
    SetTimer(automaticallyHoldHands, 0)

    if !RunningStatus.isHoldHandsAutomatically {
        return
    }


    if isItInNormalCondition() && AreaHasAllFeatureColors(IdentifyingFeatureInformation.holdHands) {
        AddLog("检测到牵手选项, 执行自动牵手操作")
        SendKey("f")
    }

    SetTimer(automaticallyHoldHands, -3000)
}


; 自动使用1技能
automaticallyUseSkill1() {
    SetTimer(automaticallyUseSkill1, 0)

    if RunningStatus.avoidWarState != 3 {
        return
    }

    activeExe := WinGetProcessName("A")

    if (activeExe != "NRC-Win64-Shipping.exe") {
        AddLog("当前活动窗口: " activeExe ", 不是洛克王国, 准备发送后台按键")
        SendKeyToRoco("1")
    } else {
        AddLog("当前活动窗口: " activeExe ", 准备发送前台按键")
        SendKey("1")
    }
    randomNum := Random(1500, 4000)
    SetTimer(automaticallyUseSkill1, -randomNum)
}


; 自动战斗
automaticallyFighting() {
    SetTimer(automaticallyFighting, 0)

    ; 关闭自动战斗并且更新ui
    endAutoBattle() {
        RunningStatus.automaticallyUseSkills := false
        ModifyMutuallyExclusiveUIStates()
    }


    if !RunningStatus.automaticallyUseSkills {
        return
    }

    AddLog("开始检测是否进入战斗...")

    ; 自动战斗逻辑
    _automaticallyFighting() {

        ; AddLog("isItInNormalCondition  " isItInNormalCondition())
        ; AddLog("isEnterCombat  " isEnterCombat())
        if !(!isItInNormalCondition() && isEnterCombat()) {
            return
        }
        AddLog("进入战斗了, 检查是否是污染精灵")

        ; 如果没有进战, 就直接退出了
        if !AreaHasAllFeatureColors(IdentifyingFeatureInformation.enemyHpBarRegion, 5) {
            return
        }


        AddLog("检测到和污染精灵进入战斗, 开始自动释放技能")
        ; 检查一下是否打掉了第一条血
        while !AreaHasAllFeatureColors(IdentifyingFeatureInformation.enemyCatchableRegion, 10) {
            if AreaHasAllFeatureColors(IdentifyingFeatureInformation.shinyElfIndicatorRegion, 10) {
                AddLog("检测到异色精灵!!!!!!!!!!!")
                endAutoBattle()
                return
            }

            if isItInNormalCondition() {
                return
            }
            SendKey("2")
            Sleep(2000)
        }

        AddLog("检测到第一条血打掉了, 开始检测是否可以捕捉了")
        ; 打完了第一条血, 检查一下是否可以捕捉了
        while !AreaHasAllFeatureColors(IdentifyingFeatureInformation.captureButtonRegion, 10) {
            Sleep(2000)
        }

        AddLog("可以捕捉了, 检测一下是否出现了异色精灵")
        if AreaHasAllFeatureColors(IdentifyingFeatureInformation.shinyElfIndicatorRegion, 10) {
            AddLog("检测到异色精灵!!!!!!!!!!!")
            endAutoBattle()

            return
        }

        ; while AreaHasAllFeatureColors(IdentifyingFeatureInformation.catchableElves, 10) {
        ;   Sleep(2000)
        ; }
        AddLog("开始进行捕捉操作")
        SendKey("w")
        Sleep(500)


        ; DrawRectangle(GuluBallIdentifyingFeature.captureBall.left, GuluBallIdentifyingFeature.captureBall.top,
        ;   GuluBallIdentifyingFeature.captureBall.right, GuluBallIdentifyingFeature.captureBall.bottom)


        convertedRegion := GuluBallIdentifyingFeature.captureBall
        convertedColor := GuluBallIdentifyingFeature.buguang.colors

        startY := convertedRegion.top

        while (startY < convertedRegion.bottom) {
            AddLog("开始检测了")
            ; DrawRectangle(convertedRegion.left, startY, convertedRegion.right, convertedRegion.bottom)
            if PixelSearch(&x, &y, convertedRegion.left, startY, convertedRegion.right, convertedRegion.bottom,
                convertedColor[1], 10) {
                AddLog("第一个点检测成功")
                ; DrawAccurate(x, y)
                ; DrawRectangle(x - 60, y - 60, x + 60, y + 60)
                for index, color in convertedColor {
                    if index == 1 {
                        continue
                    }

                    if !PixelSearch(&_x, &_y, x - 60, y - 60, x + 60, y + 60, color, 10) {
                        AddLog(Format("检测失败, 当前色值: #{:06x}", color))
                        break
                    } else {
                        AddLog("循环检测中: " index)
                        ; DrawAccurate(_x, _y)
                    }

                    AddLog("发现捕光球")
                    Click(x, y)
                    Sleep(100)
                    SendKey("Space")
                    AddLog("执行操作: 捕捉")
                    return
                }

                startY := Integer(y + 10)


            } else {
                AddLog("检测失败")

                return
            }
        }
    }

    _automaticallyFighting()
    SetTimer(automaticallyFighting, -2000)
}


; 获取血条状态 return 0: 未发现血条 1:健康 2:受伤 3:濒危
getHealthBarColor() {
    hpInformation := GetScaledIdentifyingFeatureRegion(IdentifyingFeatureInformation.hpInformation)
    if PixelSearch(&x_, &y_, hpInformation.left, hpInformation.top, hpInformation.right, hpInformation.bottom, ScatteredColors.HealthBarColor1, 5) {
        return 1
    } else if PixelSearch(&x_, &y_, hpInformation.left, hpInformation.top, hpInformation.right, hpInformation.bottom, ScatteredColors.HealthBarColor2, 5) {
        return 2
    } else if PixelSearch(&x_, &y_, hpInformation.left, hpInformation.top, hpInformation.right, hpInformation.bottom, ScatteredColors.HealthBarColor3, 5) {
        return 3
    }

    return 0
}

; 检查是否处于大世界状态
isItInNormalCondition() {
    if AreaHasAllFeatureColors(IdentifyingFeatureInformation.starLogo, 5) {
        return true
    }
    return false
}


; 发送按键事件
SendKey(str, time := 50) {
    Send("{" str " down}")
    Sleep(time)
    Send("{" str " up}")
}


; 向指定程序发送按键事件(可后台)
ControlSendKey(key, time, exe) {
    ControlSend("{" key " down}", , "ahk_exe " exe)
    Sleep(time)
    ControlSend("{" key " up}", , "ahk_exe " exe)
}


; 给洛克王国发送按键事件
SendKeyToRoco(key, time := 50) {
    ControlSendKey(key, time, "NRC-Win64-Shipping.exe")
}


; 添加日志
AddLog(msg) {

    if !HasProp(AddLog, "lines")
        AddLog.lines := []

    ; 当前日志带时间
    newLine := FormatTime(, "HH:mm:ss") " " msg

    if (AddLog.lines.Length > 0) {
        last := AddLog.lines[AddLog.lines.Length]

        if (last = newLine) {
            return
        }
        else if (InStr(last, msg)) {
            AddLog.lines[AddLog.lines.Length] := newLine
        }
        else {
            AddLog.lines.Push(newLine)
        }
    }
    else {
        AddLog.lines.Push(newLine)
    }

    ; === 限制15行 ===
    if (AddLog.lines.Length > 15)
        AddLog.lines.RemoveAt(1)

    ; === 一次性拼接 ===
    text := ""
    for index, line in AddLog.lines {
        text .= (index = AddLog.lines.Length ? line : line "`r`n")
    }

    UIClass.logBox.Value := text

    ; 滚动到底部
    SendMessage(0x115, 7, 0, UIClass.logBox.Hwnd)
}


; 清空当前日志
clearLog() {
    ; 1. 清空UI
    UIClass.logBox.Value := ""

    ; 2. 清空缓存队列（关键）
    AddLog.lines := []
}


awaitTask(fun) {
    tmep := false

    while !tmep {

        if fun() {
            tmep := true
        }

        Sleep(100)
    }
}