#Requires AutoHotkey v2.0
#SingleInstance Force
CoordMode "Pixel", "Screen"


class Config {
  static width := A_ScreenWidth
  static height := A_ScreenHeight
}


; 当前运行状态
class RunningStatus {
  ; 是否启动自动聚气/逃跑 0: 关闭 1:自动聚气 2:自动逃跑
  static avoidWarState := 0
}

; ui实例类
class UIClass {
  static ui := ""
  static gatherEnergyBtn := ""
  static runAwayBtn := ""
  static logBox := ""
}


; 聚能黄色五角星色值 #ffc65f
EnergyColor := 0xffc65f
; 聚能黄色五角星旁边的定位色值
; x的黑色
EnergyColorNearby_1 := 0x272727
; 聚能字的灰白色
EnergyColorNearby_2 := 0xc3c3b9
EnergyColorNearby_3 := 0xdbd4c5
; 聚能图标的白色
EnergyColorNearby_4 := 0xf4eee1
; 聚能黑灰底色
EnergyColorNearby_5 := 0x5c5648
; 换精灵时左下角的绿色心
GreenLove_1 := 0x82bf38
GreenLove_2 := 0x64a517
GreenLove_3 := 0x3d3d3d


; 左上角血条颜色 绿色 健康
HealthBarColor1 := 0x73c615
; 左上角血条颜色 黄色 受伤
HealthBarColor2 := 0xfcb641
; 左上角血条颜色 红色 濒死
HealthBarColor3 := 0xaf3d3e


; ================== GUI ==================
InitGui() {
  global ui

  ; TraySetIcon("app.ico", 1, true)

  ui := Gui("-Resize -MaximizeBox -MinimizeBox +AlwaysOnTop")
  ui.Title := "洛克王国  自动避战"


  ; --- 不抢焦点 ---
  hwnd := ui.Hwnd
  exStyle := DllCall("GetWindowLongPtr", "Ptr", hwnd, "Int", -20, "Ptr")
  DllCall("SetWindowLongPtr", "Ptr", hwnd, "Int", -20, "Ptr", exStyle | 0x08000000)

  OnMessage(0x21, WM_MOUSEACTIVATE)
  WM_MOUSEACTIVATE(*) {
    return 3  ; MA_NOACTIVATE
  }

  ; --- 按钮 ---
  UIClass.gatherEnergyBtn := ui.AddButton("y+15 w100 h30", "自动聚气: 关")
  UIClass.gatherEnergyBtn.OnEvent("Click", onClickGatherEnergyBtn)

  UIClass.runAwayBtn := ui.AddButton("xm y+20 w100 h30", "自动逃跑: 关")
  UIClass.runAwayBtn.OnEvent("Click", onClickRunAwayBtn)

  ; GuiCtrl := ui.AddStatusBar("h30", "运行中...")

  UIClass.logBox := ui.AddEdit("ym x+15 w160 h105 ReadOnly -Border -VScroll -HScroll +Disabled")
  UIClass.logBox.SetFont("s9 c000000", "Consolas")


  ; testBtn := ui.AddButton("xm y+20 w100 h30", "测试按钮")

  ; 设置关闭事件, 关闭gui的时候关闭脚本
  ui.OnEvent("Close", GuiClose)  ; 绑定关闭事件

  GuiClose(*) {
    ExitApp()  ; 点击 X 时退出脚本
  }


  UIClass.ui := ui
  ui.Show("w300 h120 NOACTIVATE")
}


; ================== 入口 ==================
Main() {
  ElevatePrivileges()
  InitGui()
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


DrawAccurate(x, y, size := 20) {
  g1 := Gui("+AlwaysOnTop -Caption +ToolWindow")
  g1.BackColor := "Red"
  g1.Show("x" (x - size) " y" y " w" (size * 2) " h2 NA")

  g2 := Gui("+AlwaysOnTop -Caption +ToolWindow")
  g2.BackColor := "Red"
  g2.Show("x" x " y" (y - size) " w2 h" (size * 2) " NA")

  SetTimer((*) => (g1.Destroy(), g2.Destroy()), -2000)
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
    ; 修改按键文字
    ctrl.Text := "自动逃跑: 开"
    UIClass.gatherEnergyBtn.Text := "自动聚气: 关"
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

; 自动避战逻辑, 循环检查是否进战
whetherFighting() {
  ; 检查状态是否被关闭
  if RunningStatus.avoidWarState == 0 {
    return
  }

  AddLog("正在检查是否进入战斗...")
  if whetherEnterCombat() {
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

  ; 500ms检查一次是否进入了战斗
  SetTimer(whetherFighting, -1000)
}


; 判断是否进入了战斗
whetherEnterCombat() {
  ; 颜色偏差值
  deviationValue := 10
  ; 查找屏幕的左下小部分
  ; x起始点和终点
  startX := 0
  endX := Config.width * 0.15
  ; y起始点和终点
  startY := Config.height * 0.8
  endY := Config.height
  ;400x170
  ; 先进行粗略判断
  if PixelSearch(&x, &y, startX, startY, endX, endY, EnergyColor, deviationValue) {
    if PixelSearch(&_, &_, startX, startY, endX, endY, EnergyColorNearby_1, deviationValue)
      && PixelSearch(&x_, &y_, startX, startY, endX, endY, EnergyColorNearby_2, deviationValue)
      && PixelSearch(&_, &_, startX, startY, endX, endY, EnergyColorNearby_3, deviationValue)
      && PixelSearch(&_, &_, startX, startY, endX, endY, EnergyColorNearby_4, deviationValue)
      && PixelSearch(&_, &_, startX, startY, endX, endY, EnergyColorNearby_5, deviationValue) {
      ; && PixelSearch(&a_, &b_, 0, 0, width * 0.15, height * 0.1, HealthBarColor, 5)
      ; 左下角聚能色值验证 + 左上角血条色值验证
      ; DrawBox(x_, y_)
      ; DrawBox(a_, b_)

      if getHealthBarColor() > 0 {
        return true
      }
    }

  }

  return false
}


; 战斗中进行聚能
collectEnergy() {
  ; 颜色偏差值
  deviationValue := 10
  ; 查找屏幕的左下小部分
  ; x起始点和终点
  startX := 0
  endX := Config.width * 0.15
  ; y起始点和终点
  startY := Config.height * 0.8
  endY := Config.height

  ; 这里检查一下是否在换人界面, 如果在换人界面就说明精灵被打死了, 直接逃跑
  if PixelSearch(&_, &_, startX, startY, endX, endY, GreenLove_1, deviationValue)
    && PixelSearch(&_, &_, startX, startY, endX, endY, GreenLove_2, deviationValue)
    && PixelSearch(&_, &_, startX, startY, endX, endY, GreenLove_3, deviationValue) {
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
  if PixelSearch(&x, &y, startX, startY, endX, endY, EnergyColor, deviationValue) {
    if PixelSearch(&_, &_, startX, startY, endX, endY, EnergyColorNearby_1, deviationValue)
      && PixelSearch(&x_, &y_, startX, startY, endX, endY, EnergyColorNearby_2, deviationValue)
      && PixelSearch(&_, &_, startX, startY, endX, endY, EnergyColorNearby_3, deviationValue)
      && PixelSearch(&_, &_, startX, startY, endX, endY, EnergyColorNearby_4, deviationValue)
      && PixelSearch(&_, &_, startX, startY, endX, endY, EnergyColorNearby_5, deviationValue) {

      ;还能聚气就一直聚气
      AddLog("开始执行聚气动作")
      Sleep(500)
      SendKey('x')
      Sleep(3000)
    }
  }

  ; 递归调用一下
  SetTimer(collectEnergy, -2000)
}


; esc退出战斗
exitCombat() {
  if !isItInNormalCondition() {
    Sleep(500)
    SendKey('Esc')
    Sleep(1000)
    PixelSearch(&x, &y, Config.width * 0.5, Config.height * 0.7, Config.width, Config.height, 0xf4eee1, 5)
    if x != '' && y != '' {
      AddLog("开始执行逃跑操作")
      Click(x, y + 10)
    }
  }
}

; 获取血条状态 return 0: 未发现血条 1:健康 2:受伤 3:濒危
getHealthBarColor() {
  ; x起始点和终点
  startX := 0
  endX := Config.width * 0.15
  ; y起始点和终点
  startY := 0
  endY := Config.height * 0.1
  if PixelSearch(&x_, &y_, startX, startY, endX, endY, HealthBarColor1, 5) {
    return 1
  } else if PixelSearch(&x_, &y_, startX, startY, endX, endY, HealthBarColor2, 5) {
    return 2
  } else if PixelSearch(&x_, &y_, startX, startY, endX, endY, HealthBarColor3, 5) {
    return 3
  }

  return 0
}

; 检查是否处于大世界状态
isItInNormalCondition() {
  if PixelSearch(&_, &_, 0, 0, Config.width * 0.1, Config.height * 0.1, 0x64d1fd, 5)
    && PixelSearch(&_, &_, 0, 0, Config.width * 0.1, Config.height * 0.1, 0xffc65f, 5)
    && PixelSearch(&_, &_, 0, 0, Config.width * 0.1, Config.height * 0.1, 0x2469ba, 5) {
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
  if (AddLog.lines.Length > 5)
    AddLog.lines.RemoveAt(1)

  ; === 重绘 ===
  UIClass.logBox.Value := ""
  for line in AddLog.lines
    UIClass.logBox.Value .= line "`r`n"

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