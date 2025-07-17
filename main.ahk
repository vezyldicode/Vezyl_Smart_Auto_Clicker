#Requires AutoHotkey v2.0

#SingleInstance Force
SetTitleMatchMode(2)
SendMode("InputThenPlay")

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
    __New(selectedID, button, interval, onlyActive, randomInterval := true) {
        this.selectedID := selectedID
        this.button := button
        this.interval := interval
        this.onlyActive := onlyActive
        this.randomInterval := randomInterval
        this.running := false
        this.timer := ObjBindMethod(this, "DoClick")
    }

    Start() {
        if (!this.running) {
            this.running := true
            this._SetNextTimer()
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
                SendEvent("{" this.button " down}")
                Sleep 10
                SendEvent("{" this.button " up}")
            }
        } else {
            SendEvent("{" this.button " down}")
            Sleep 10
            SendEvent("{" this.button " up}")
        }
        if (this.running)
            this._SetNextTimer()
    }

    _SetNextTimer() {
        if this.randomInterval {
            min := Max(1, this.interval - 20)
            maxDelay := this.interval + 20
            delay := Random(min, maxDelay)
        } else {
            delay := this.interval
        }
        SetTimer(this.timer, delay)
    }
}

class AutoClickerGUI {
    __New() {
        FileEncoding "UTF-8"
        langPath := "resources\lang\en.ini"
        L := Map()
        for key in ["MouseButton","Left","Right","Middle","ClickSpeed","Hotkey","OnlyActive","SelectWindow","Start","MsgSelectWindow","MsgEnterHotkey","MsgClickSpeed","RandomInterval"]
            L[key] := IniRead(langPath, "Label", key, key)

        if FileExist("VezylAutoClickerProton\local.ini") {
            iniPath := "VezylAutoClickerProton\local.ini"
        } else {
            iniPath := "VezylAutoClickerProton\global.ini"
        }
        this.button := IniRead(iniPath, "General", "Button", "left")
        this.interval := Integer(IniRead(iniPath, "General", "Interval", "100"))
        this.hotkey := IniRead(iniPath, "General", "Hotkey", "F6")
        this.onlyActive := !!IniRead(iniPath, "General", "OnlyActive", "1")
        this.randomInterval := !!IniRead(iniPath, "General", "RandomInterval", "1")

        this.winList := WindowManager.GetWindowList()
        this.titles := []
        for win in this.winList
            this.titles.Push(win.title)
        this.selectedID := ""
        this.clicker := ""

        this.gui := Gui()
        this.gui.BackColor := 0xFBFBFB
        this.gui.SetFont("c484b6a")
        this.gui.SetFont("s9", "Segoe UI")

        ; --- Nút chuột: 3 radio trên 1 hàng ---
        this.gui.AddText("xm ym", L["MouseButton"])
        this.btnRadio := this.gui.AddRadio("xp+70 yp-2 vBtnLeft" (this.button="left"?" Checked":"") , L["Left"])
        this.btnRadio2 := this.gui.AddRadio("xp+60 yp vBtnRight" (this.button="right"?" Checked":""), L["Right"])
        this.btnRadio3 := this.gui.AddRadio("xp+60 yp vBtnMiddle" (this.button="middle"?" Checked":""), L["Middle"])

        ; --- Tốc độ click và Hotkey trên cùng 1 hàng ---
        this.gui.AddText("xm y+15", L["ClickSpeed"])
        this.edtInterval := this.gui.AddEdit("xp+110 yp-2 w70 vInterval", this.interval)
        this.gui.AddText("xp+90 yp", L["Hotkey"])
        this.hkCtrl := this.gui.AddHotkey("xp+110 yp-2 w100 vHotkey", this.hotkey)

        ; --- Checkbox ---
        this.chkOnlyActive := this.gui.AddCheckBox("xm y+15 vOnlyActive" (this.onlyActive?" Checked":""), L["OnlyActive"])
        this.chkOnlyActive.OnEvent("Click", ObjBindMethod(this, "OnOnlyActiveChanged"))

        ; --- Checkbox random interval ---
        this.chkRandomInterval := this.gui.AddCheckBox("xm y+10 vRandomInterval" (this.randomInterval?" Checked":""), L.Has("RandomInterval") ? L["RandomInterval"] : "Random interval (+-20ms)")

        ; --- Chọn cửa sổ xuống dưới cùng ---
        this.txtWin := this.gui.AddText("xm y+25", L["SelectWindow"])
        this.cb := this.gui.AddComboBox("xp+90 yp-2 vWinTitle w300", this.titles)

        if !this.onlyActive {
            this.txtWin.Visible := false
            this.cb.Visible := false
        }

        this.btnStart := this.gui.AddButton("xm y+20 Default", L["Start"])
        this.btnStart.OnEvent("Click", ObjBindMethod(this, "Start_Click"))
        this.gui.OnEvent("Close", ObjBindMethod(this, "OnClose"))

        this.L := L
        this.isRunning := false
    }

    OnOnlyActiveChanged(*) {
        show := this.chkOnlyActive.Value
        this.txtWin.Visible := show
        this.cb.Visible := show
    }

    Show() {
        this.gui.Show("AutoSize")
    }

    Start_Click(*) {
        if (!this.isRunning) {
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
            hk := this.hkCtrl.Value
            if (hk = "") {
                MsgBox "Vui lòng nhập hotkey!"
                return
            }
            this.hotkey := hk
            this.onlyActive := this.chkOnlyActive.Value
            this.randomInterval := this.chkRandomInterval.Value

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
            IniWrite(this.randomInterval,localIni, "General", "RandomInterval")
            IniWrite(this.cb.Text,   localIni, "General", "WindowTitle")
            IniWrite(this.selectedID,localIni, "General", "WindowID")

            if (IsObject(this.clicker))
                this.clicker.Stop()

            this.clicker := AutoClicker(this.selectedID, this.button, this.interval, this.onlyActive, this.randomInterval)
            Hotkey(this.hotkey, ObjBindMethod(this, "ToggleClicker"), "On")
            this.isRunning := true
            this.btnStart.Text := this.L.Has("Stop") ? this.L["Stop"] : "Dừng"
            SoundBeep
            Sleep 100
            SoundBeep
            this.clicker.Start()
        } else {
            if (IsObject(this.clicker))
                this.clicker.Stop()
            this.isRunning := false
            this.btnStart.Text := this.L.Has("Start") ? this.L["Start"] : "Bắt đầu"
            SoundBeep
        }
    }

    ToggleClicker(*) {
        if (IsObject(this.clicker)) {
            this.clicker.Toggle()
            this.isRunning := this.clicker.running
            this.btnStart.Text := this.isRunning
                ? (this.L.Has("Stop") ? this.L["Stop"] : "Dừng")
                : (this.L.Has("Start") ? this.L["Start"] : "Bắt đầu")
            if this.isRunning {
                SoundBeep
                Sleep 100
                SoundBeep
            } else {
                SoundBeep
            }
        }
    }

    OnClose(*) {
        if (IsObject(this.clicker))
            this.clicker.Stop()
        ExitApp
    }
}

Max(a, b) {
    return a > b ? a : b
}
Min(a, b) {
    return a < b ? a : b
}

; Chạy chương trình
app := AutoClickerGUI()
app.Show()