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
        this.winList := WindowManager.GetWindowList()
        this.titles := []
        for win in this.winList
            this.titles.Push(win.title)
        this.selectedID := ""
        this.button := "left"
        this.interval := 100
        this.clicker := ""
        this.hotkey := "F6"
        this.onlyActive := true

        this.gui := Gui("+AlwaysOnTop +ToolWindow", "Auto Clicker")
        this.gui.AddText(, "Chọn cửa sổ:")
        this.cb := this.gui.AddComboBox("vWinTitle w300", this.titles)
        this.gui.AddText(, "Nút chuột:")
        this.btnRadio := this.gui.AddRadio("vBtnLeft Checked", "Trái")
        this.btnRadio2 := this.gui.AddRadio("vBtnRight", "Phải")
        this.btnRadio3 := this.gui.AddRadio("vBtnMiddle", "Giữa")
        this.gui.AddText(, "Tốc độ click (ms):")
        this.edtInterval := this.gui.AddEdit("vInterval w100", "100")
        this.gui.AddText(, "Hotkey Start/Stop:")
        this.edtHotkey := this.gui.AddEdit("vHotkey w100", "F6")
        this.chkOnlyActive := this.gui.AddCheckBox("vOnlyActive Checked", "Chỉ click khi cửa sổ được chọn đang active")
        this.gui.AddButton("Default", "Bắt đầu").OnEvent("Click", ObjBindMethod(this, "Start_Click"))
        this.gui.OnEvent("Close", ObjBindMethod(this, "OnClose"))
    }

    Show() {
        this.gui.Show("AutoSize")
    }

    Start_Click(*) {
        idx := this.cb.Value
        if (idx = "") {
            MsgBox "Vui lòng chọn một cửa sổ!"
            return
        }
        Loop this.winList.Length {
            if (this.winList[A_Index].title = this.cb.Text) {
                this.selectedID := this.winList[A_Index].id
                break
            }
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

        ; Thêm cửa sổ xác nhận
        msg := "Bạn có chắc chắn muốn bắt đầu auto click với các thiết lập hiện tại không?"
        result := MsgBox(msg, "Xác nhận", 0x24) ; 0x24 = YesNo + Question icon
        if (result != 6) ; 6 là Yes, 7 là No
            return

        if (IsObject(this.clicker))
            this.clicker.Stop()

        this.clicker := AutoClicker(this.selectedID, this.button, this.interval, this.onlyActive)
        Hotkey(this.hotkey, ObjBindMethod(this, "ToggleClicker"), "On")
        MsgBox "Nhấn " this.hotkey " để Start/Stop auto click!"
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