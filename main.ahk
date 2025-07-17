#Requires AutoHotkey v2.0

#SingleInstance Force
SetTitleMatchMode(2)

class WindowManager {
    static GetWindowList() {
        winList := []
        idList := WinGetList()
        for thisID in idList {
            title := WinGetTitle("ahk_id " thisID)
            if (title != "")
                winList.Push({id: thisID, title: title})
        }
        return winList
    }
}

class AutoClicker {
    __New(selectedID, button, interval, onlyActive) {
        this.selectedID := selectedID
        this.button := button
        this.interval := interval
        this.onlyActive := onlyActive
        this.running := false
        this.timer := ObjBindMethod(this, "DoClick")
    }

    Start() {
        if (!this.running) {
            this.running := true
            SetTimer(this.timer, this.interval)
        }
    }

    Stop() {
        if (this.running) {
            this.running := false
            SetTimer(this.timer, 0)
        }
    }

    Toggle() {
        if (this.running)
            this.Stop()
        else
            this.Start()
    }

    DoClick(*) {
        if (this.onlyActive) {
            if (WinGetID("A") = this.selectedID) {
                Click(this.button)
            }
        } else {
            Click(this.button)
        }
    }
}

class AutoClickerGUI {
    __New() {
        if FileExist("VezylAutoClickerProton\local.ini") {
            iniPath := "VezylAutoClickerProton\local.ini"
        } else {
            iniPath := "VezylAutoClickerProton\global.ini"
        }
        this.button := IniRead(iniPath, "General", "Button", "left")
        this.interval := Integer(IniRead(iniPath, "General", "Interval", "100"))
        this.hotkey := IniRead(iniPath, "General", "Hotkey", "F6")
        this.onlyActive := !!IniRead(iniPath, "General", "OnlyActive", "1")

        this.winList := WindowManager.GetWindowList()
        this.titles := []
        for win in this.winList
            this.titles.Push(win.title)
        this.selectedID := ""
        this.clicker := ""

        this.gui := Gui("+ToolWindow", "Auto Clicker")
        this.gui.AddText(, "Chọn cửa sổ:")
        this.cb := this.gui.AddComboBox("vWinTitle w300", this.titles)
        this.gui.AddText(, "Nút chuột:")
        this.btnRadio := this.gui.AddRadio("vBtnLeft" (this.button="left"?" Checked":"") , "Trái")
        this.btnRadio2 := this.gui.AddRadio("vBtnRight" (this.button="right"?" Checked":""), "Phải")
        this.btnRadio3 := this.gui.AddRadio("vBtnMiddle" (this.button="middle"?" Checked":""), "Giữa")
        this.gui.AddText(, "Tốc độ click (ms):")
        this.edtInterval := this.gui.AddEdit("vInterval w100", this.interval)
        this.gui.AddText(, "Hotkey Start/Stop:")
        this.edtHotkey := this.gui.AddEdit("vHotkey w100", this.hotkey)
        this.chkOnlyActive := this.gui.AddCheckBox("vOnlyActive" (this.onlyActive?" Checked":""), "Chỉ click khi cửa sổ được chọn đang active")
        this.gui.AddButton("Default", "Bắt đầu").OnEvent("Click", ObjBindMethod(this, "Start_Click"))
        this.gui.OnEvent("Close", ObjBindMethod(this, "OnClose"))
    }

    Show() {
        this.gui.Show("AutoSize")
    }

    Start_Click(*) {
        ; Nếu chỉ click khi cửa sổ active, bắt buộc phải chọn cửa sổ
        if (this.chkOnlyActive.Value) {
            if (this.cb.Text = "") {
                MsgBox "Vui lòng chọn một cửa sổ!"
                return
            }
            Loop this.winList.Length {
                if (this.winList[A_Index].title = this.cb.Text) {
                    this.selectedID := this.winList[A_Index].id
                    break
                }
            }
        } else {
            this.selectedID := "" ; Không cần ID khi click toàn cục
        }

        if (this.btnRadio.Value)
            this.button := "left"
        else if (this.btnRadio2.Value)
            this.button := "right"
        else if (this.btnRadio3.Value)
            this.button := "middle"
        this.interval := Integer(this.edtInterval.Value)
        if (this.interval < 1) {
            MsgBox "Tốc độ click phải lớn hơn 0!"
            return
        }
        hk := this.edtHotkey.Value
        if (hk = "") {
            MsgBox "Vui lòng nhập hotkey!"
            return
        }
        this.hotkey := hk
        this.onlyActive := this.chkOnlyActive.Value

        ; Xử lý file local.ini
        localIniDir := "VezylAutoClickerProton"
        localIni := localIniDir "\local.ini"
        if !DirExist(localIniDir)
            DirCreate localIniDir
        if FileExist(localIni)
            FileDelete localIni
        IniWrite(this.button,    localIni, "General", "Button")
        IniWrite(this.interval,  localIni, "General", "Interval")
        IniWrite(this.hotkey,    localIni, "General", "Hotkey")
        IniWrite(this.onlyActive,localIni, "General", "OnlyActive")
        IniWrite(this.cb.Text,   localIni, "General", "WindowTitle")
        IniWrite(this.selectedID,localIni, "General", "WindowID")

        if (IsObject(this.clicker))
            this.clicker.Stop()

        this.clicker := AutoClicker(this.selectedID, this.button, this.interval, this.onlyActive)
        Hotkey(this.hotkey, ObjBindMethod(this, "ToggleClicker"), "On")
        ; MsgBox "Nhấn " this.hotkey " để Start/Stop auto click!"
    }

    ToggleClicker(*) {
        if (IsObject(this.clicker))
            this.clicker.Toggle()
    }

    OnClose(*) {
        if (IsObject(this.clicker))
            this.clicker.Stop()
        ExitApp
    }
}

; Chạy chương trình
app := AutoClickerGUI()
app.Show()