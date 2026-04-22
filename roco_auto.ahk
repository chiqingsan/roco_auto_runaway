#Requires AutoHotkey v2.0
#SingleInstance Force
CoordMode "Pixel", "Screen"

#Include LocalFileLogger.ahk


VERSION := "1.3"
DEBUG_LOCALLOG := true  ; 是否开启本地调试日志

class Config {
  static width := A_ScreenWidth
  static height := A_ScreenHeight

  static scaleX  := A_ScreenWidth / 2560
  static scaleY := A_ScreenHeight / 1440
}


; 当前运行状态
class RunningStatus {
  ; 是否启动自动聚气/逃跑 0: 关闭 1:自动聚气 2:自动逃跑 3:自动使用1技能
  static avoidWarState := 0

  ; 是否启用自动牵手功能
  static isHoldHandsAutomatically := false
}

; ui实例类
class UIClass {
  static ui := ""
  static gatherEnergyBtn := ""
  static useSkills := "" ; 自动使用技能1
  static runAwayBtn := ""
  static HoldHandsAutomaticallyBtn := ""
  static logBox := ""
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
    name: "starLogo",
    left: 0,
    top: 0,
    right: 420,
    bottom: 180,
    
    ; 特征色值
    colors: [0x2469ba, 0x64d1fd, 0x266ebd, 0x73c615, 0x5ca011]
  }


  ; 进入战斗后, 左上角的精灵血条信息区域 420x180
  static hpInformation := {
    name: "hpInformation",
    left: 0,
    top: 0,
    right: 420,
    bottom: 180,
    ; 特征色值
    colors: [0xffc65f, 0x3d3d3d, 0x79786f, 0xf4eee1, 0xffffff]
  }
  

  ; 换人界面左下角的绿色心区域
  static greenLove := {
    name: "greenLove",
    left: 88,
    top: 1156,
    right: 322+88,
    bottom: 201+1156,
    colors: [0x85c13c, 0x65a617, 0x3d3d3d, 0x66a619, 0xffffff]
  }

  ; 左下角的聚能图标区域
  static gatherEnergy := {
    name: "gatherEnergy",
    left: 0,
    top: 1150,
    right: 250,
    bottom: 1440,
    colors: [0xffc65f, 0x272727, 0x4f4e4b, 0xf4eee1, 0x5c5648]
  }


  ; 牵手的图标区域
  static holdHands := {
    name: "holdHands",
    left: 1343,
    top: 628,
    right: 638+1343,
    bottom: 337+628,
    colors: [0xdc9827, 0xfaf3e4, 0xf4eee1, 0x272727, 0x3d3d3d, 0xffffff] ;0x2a2928, 0xf4ba53
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
  ; 检查计数, 当计数大于1时, 尝试记录检测失败的结果, 来优化后续的检测效率
  count := 0

  for color in convertedRegion.colors {
    if !PixelSearch(&_, &_, convertedRegion.left, convertedRegion.top, convertedRegion.right, convertedRegion.bottom,
      color, deviationValue) {
      if count > 0 {
        LocalFileLogger.debug(Format("检测色值失败, 检测对象 {}, 失败色值: {}, 当前检测宽容度: {}, 当前匹配进度为 {:02}", convertedRegion.name, color, deviationValue, count))
      }
  
      return false
    }
    count++
  }
  return true
}


; ================== GUI ==================
InitGui() {
  global ui

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
  UIClass.gatherEnergyBtn := ui.AddButton("y+5 w100 h30", "自动聚气: 关")
  UIClass.gatherEnergyBtn.OnEvent("Click", onClickGatherEnergyBtn)

  UIClass.useSkills := ui.AddButton("y+5 w100 h30", "后台技能1: 关")
  UIClass.useSkills.OnEvent("Click", onClickUseSkillsBtn)

  UIClass.runAwayBtn := ui.AddButton("xm y+10 w100 h30", "自动逃跑: 关")
  UIClass.runAwayBtn.OnEvent("Click", onClickRunAwayBtn)
  
  UIClass.HoldHandsAutomaticallyBtn := ui.AddButton("xm y+10 w100 h30", "自动牵手: 关")
  UIClass.HoldHandsAutomaticallyBtn.OnEvent("Click", onHoldHandsAutomaticallyBtn)

  ; testBtn := ui.AddButton("xm y+10 w100 h30", "测试按钮")
  ; testBtn.OnEvent("Click", SendOnce)

  ; GuiCtrl := ui.AddStatusBar("h30", "运行中...")

  UIClass.logBox := ui.AddEdit("ym x+12 w170 h140 ReadOnly -Border -VScroll -HScroll +Disabled")
  UIClass.logBox.SetFont("s9 c000000", "Consolas")


  ; 设置关闭事件, 关闭gui的时候关闭脚本
  ui.OnEvent("Close", GuiClose)  ; 绑定关闭事件

  GuiClose(*) {
    ExitApp()  ; 点击 X 时退出脚本
  }


  UIClass.ui := ui
  ui.Show("w300 h160 NOACTIVATE")
}


; ================== 入口 ==================
Main() {
  ElevatePrivileges()
  InitGui()
  LocalFileLogger.enabled := DEBUG_LOCALLOG
  LocalFileLogger.init()
  AddLog("开始运行...")
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


; 按键事件
; 自动聚气
onClickGatherEnergyBtn(ctrl, *) {
  if RunningStatus.avoidWarState != 1 {
    ; 修改一下状态
    RunningStatus.avoidWarState := 1
    ; 修改按键文字
    ctrl.Text := "自动聚气: 开"
    UIClass.runAwayBtn.Text := "自动逃跑: 关"
    UIClass.useSkills.Text := "后台技能1: 关"
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


; 自动使用技能1
onClickUseSkillsBtn(ctrl, *) {
  if RunningStatus.avoidWarState != 3 {
    ; 修改一下状态
    RunningStatus.avoidWarState := 3
    ; 修改按键文字
    ctrl.Text := "后台技能1: 开"
    UIClass.runAwayBtn.Text := "自动逃跑: 关"
    UIClass.gatherEnergyBtn.Text := "自动聚气: 关"

    AddLog("后台技能1已开启")
    whetherFighting()
    return
  }

  ; 修改一下状态
  RunningStatus.avoidWarState := 0
  ; 修改按键文字
  ctrl.Text := "后台技能1: 关"
  AddLog("后台技能1已关闭")
}


; 自动逃跑
onClickRunAwayBtn(ctrl, *) {
  if RunningStatus.avoidWarState != 2 {
    ; 修改一下状态
    RunningStatus.avoidWarState := 2
    ; 修改按键文字
    ctrl.Text := "自动逃跑: 开"
    UIClass.gatherEnergyBtn.Text := "自动聚气: 关"
    UIClass.useSkills.Text := "后台技能1: 关"
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


; 自动避战逻辑, 循环检查是否进战
whetherFighting() {
  ; 清理可能多余的定时任务
  SetTimer(whetherFighting, 0)

  ; 检查状态是否被关闭
  if RunningStatus.avoidWarState == 0 {
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
    } else if RunningStatus.avoidWarState == 3 {
      AddLog("进入战斗, 目前模式为: 后台技能1")
      ; 后台技能1
      automaticallyUseSkill1()
    }

  ; 1000ms检查一次是否进入了战斗
  SetTimer(whetherFighting, -1000)
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
  if RunningStatus.avoidWarState != 3 {
    return
  }

  if !ProcessExist("NRC-Win64-Shipping.exe") {
    AddLog("提示: 未检测到洛克王国游戏程序, 无法执行自动使用技能1")
    RunningStatus.avoidWarState := 0
    UIClass.useSkills.Text := "后台技能1: 关"
    return
  }

  AddLog("执行操作: 使用1技能")
  SendKeyToRoco("1")
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

  ; === 限制5行 ===
  if (AddLog.lines.Length > 8)
    AddLog.lines.RemoveAt(1)

  ; === 一次性拼接 ===
  text := ""
  for line in AddLog.lines
    text .= line "`r`n"

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
