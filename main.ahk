; --- Biến toàn cục cờ lỗi ---
global ErrorFlag := false

SetError(msg) {
    global ErrorFlag
    ErrorFlag := true
    MsgBox msg
    ; Khởi động lại chương trình
    Run(A_ScriptFullPath)
    ExitApp
}

#Requires AutoHotkey v2.0

#SingleInstance Force
SetTitleMatchMode(2)
SendMode("InputThenPlay")
CoordMode "Mouse", "Screen"

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
    __New(selectedID, button, interval, onlyActive, randomInterval := true, clickX := "", clickY := "", randomRange := 20, keyHotkey := "", hiddenClick := false) {
        this.selectedID := selectedID
        this.button := button
        this.interval := interval
        this.onlyActive := onlyActive
        this.randomInterval := randomInterval
        this.clickX := clickX
        this.clickY := clickY
        this.randomRange := randomRange
        this.keyHotkey := keyHotkey
        this.hiddenClick := hiddenClick
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
            try {
                activeID := WinGetID("A")
            } catch {
                return
            }
            if (activeID = this.selectedID) {
                this.ClickAtPosition()
            }
        } else {
            this.ClickAtPosition()
        }
        if (this.running)
            this._SetNextTimer()
    }

    ClickAtPosition() {
        if (this.hiddenClick && this.selectedID != "") {
            ; Click ẩn vào cửa sổ chỉ định
            btn := (this.button = "left") ? "Left" : (this.button = "right") ? "Right" : (this.button = "middle") ? "Middle" : "Left"
            ; Nếu click tại vị trí chỉ định
            if (this.clickX != "" && this.clickY != "") {
                ControlClick("x" this.clickX " y" this.clickY, "ahk_id " this.selectedID, , btn, , "NA")
            } else {
                try {
                    ControlClick("", "ahk_id " this.selectedID, , btn, , "NA")
                } catch {
                    SetError("Failed to click in window with ID: " this.selectedID "`nPlease ensure the window is valid and accessible. `nIf the issue persists, try using absolute coordinates instead.")
                    return
                }
                    
            }
        } else if (this.button = "key" && this.keyHotkey != "") {
            Send "{" this.keyHotkey "}"
        } else if (this.clickX != "" && this.clickY != "") {
            MouseGetPos(&curX, &curY)
            if (curX != this.clickX || curY != this.clickY)
                MouseMove(this.clickX, this.clickY, 0)
            Click(this.button)
        } else {
            Click(this.button)
        }
    }
    _SetNextTimer() {
        if this.randomInterval {
            min := Max(1, this.interval - this.randomRange)
            maxDelay := this.interval + this.randomRange
            delay := Random(min, maxDelay)
        } else {
            delay := this.interval
        }
        SetTimer(this.timer, delay)
    }
}

class AutoClickerGUI {
    __New() {
        this.keyHotkey := "" ; Khởi tạo thuộc tính keyHotkey
        this.selectedID := ""
        this.clicker := ""

        FileEncoding "UTF-8"
        ; Đọc ngôn ngữ từ config
        langCode := IniRead("VezylAutoClickerEclectron\config.ini", "General", "Language", "en")
        langPath := "resources\lang\" langCode ".ini"
        L := Map()
        if FileExist(langPath) {
            for key in ["MouseButton","Left","Right","Middle","ClickSpeed","Hotkey","SelectWindow","Start","Stop", "MsgSelectWindow","MsgEnterHotkey","MsgClickSpeed","RandomInterval","UsePos", "Refresh", "GetPos", "Key", "AllWindows", "OnlyActive", "HiddenClick"]
                L[key] := IniRead(langPath, "Label", key, key)
        } else {
            ; fallback sang en.ini hoặc giá trị mặc định
            langPath := "resources\lang\en.ini"
            for key in ["MouseButton","Left","Right","Middle","ClickSpeed","Hotkey","SelectWindow","Start","Stop", "MsgSelectWindow","MsgEnterHotkey","MsgClickSpeed","RandomInterval","UsePos", "Refresh", "GetPos", "Key", "AllWindows", "OnlyActive", "HiddenClick"]
                L[key] := IniRead(langPath, "Label", key, key)
        }

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
        this.usePos := !!IniRead(iniPath, "General", "UsePos", "0")
        this.clickX := IniRead(iniPath, "General", "ClickX", "")
        this.clickY := IniRead(iniPath, "General", "ClickY", "")
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
        this.gui.Title := "Vezyl Smart Auto Clicker"

        ; --- Nút chuột: 3 radio trên 1 hàng + 1 radio phím bất kỳ ---
        this.gui.AddText("xm ym", L["MouseButton"])
        this.btnRadio := this.gui.AddRadio("xp+70 yp-2 vBtnLeft" (this.button="left"?" Checked":"") , L["Left"])
        this.btnRadio2 := this.gui.AddRadio("xp+60 yp vBtnRight" (this.button="right"?" Checked":""), L["Right"])
        this.btnRadio3 := this.gui.AddRadio("xp+60 yp vBtnMiddle" (this.button="middle"?" Checked":""), L["Middle"])
        this.btnRadioKey := this.gui.AddRadio("xp+60 yp vBtnKey" (this.button="key"?" Checked":""), L["Key"])

        ; --- Hotkey cho phím bất kỳ ---
        this.hkKey := this.gui.AddHotkey("xp+60 yp+2 w100 vKeyHotkey", this.keyHotkey ? this.keyHotkey : "")
        ; Ẩn mặc định nếu không chọn radio phím
        this.hkKey.Visible := (this.button="key")
        ; Sự kiện chuyển radio
        this.btnRadio.OnEvent("Click", ObjBindMethod(this, "OnRadioChanged"))
        this.btnRadio2.OnEvent("Click", ObjBindMethod(this, "OnRadioChanged"))
        this.btnRadio3.OnEvent("Click", ObjBindMethod(this, "OnRadioChanged"))
        this.btnRadioKey.OnEvent("Click", ObjBindMethod(this, "OnRadioChanged"))


        ; --- Tốc độ click và Hotkey trên cùng 1 hàng ---
        this.gui.AddText("xm y+15", L["ClickSpeed"])
        this.edtInterval := this.gui.AddEdit("xp+110 yp-2 w70 vInterval", this.interval)
        this.gui.AddText("xp+90 yp", L["Hotkey"])
        this.hkCtrl := this.gui.AddHotkey("xp+110 yp-2 w100 vHotkey", this.hotkey)


        ; --- Đọc randomRange từ config ---
        this.randomRange := Integer(IniRead("VezylAutoClickerEclectron\config.ini", "General", "RandomRange", "20"))
        randomLabel := (L.Has("RandomInterval") ? L["RandomInterval"] : "Random interval") " (+-" this.randomRange "ms)"

        ; --- Checkbox random interval ---
        this.chkRandomInterval := this.gui.AddCheckBox("xm y+10 vRandomInterval" (this.randomInterval?" Checked":""), randomLabel)

        ; --- Radio: Chỉ click khi cửa sổ active, click toàn bộ, hoặc click ẩn (xếp dọc) ---
        this.rdoAllWindows := this.gui.AddRadio("xm y+15 vRdoAllWindows" (!this.onlyActive ? " Checked" : ""), L.Has("AllWindows") ? L["AllWindows"] : "Click trên toàn bộ cửa sổ")
        this.rdoOnlyActive := this.gui.AddRadio("xm y+5 vRdoOnlyActive" (this.onlyActive ? " Checked" : ""), L.Has("OnlyActive") ? L["OnlyActive"] : "Chỉ click khi cửa sổ được chọn đang active")
        this.rdoHiddenClick := this.gui.AddRadio("xm y+5 vRdoHiddenClick", L.Has("HiddenClick") ? L["HiddenClick"] : "Click ẩn (không cần cửa sổ active)")
        this.rdoOnlyActive.OnEvent("Click", ObjBindMethod(this, "OnOnlyActiveChanged"))
        this.rdoAllWindows.OnEvent("Click", ObjBindMethod(this, "OnOnlyActiveChanged"))
        this.rdoHiddenClick.OnEvent("Click", ObjBindMethod(this, "OnOnlyActiveChanged"))


        ; --- Chọn cửa sổ xuống dưới cùng ---
        this.txtWin := this.gui.AddText("xm y+25", L["SelectWindow"])
        this.cb := this.gui.AddComboBox("xp+90 yp-2 vWinTitle w250", this.titles)
        this.btnRefresh := this.gui.AddButton("xp+250 yp-2 w50", L["Refresh"]) ; Nút refresh
        this.btnRefresh.OnEvent("Click", ObjBindMethod(this, "RefreshWindowList"))

        if !this.onlyActive {
            this.txtWin.Visible := false
            this.cb.Visible := false
            this.btnRefresh.Visible := false
        }
        ; --- Checkbox bật/tắt click tại vị trí chỉ định ---
        this.chkUsePos := this.gui.AddCheckBox("xm y+10 vUsePos" (this.usePos ? " Checked" : ""), L["UsePos"])
        this.chkUsePos.OnEvent("Click", ObjBindMethod(this, "OnUsePosChanged"))

        ; --- Nhập tọa độ click và nút Get Pos ---
        this.txtX := this.gui.AddText("xm y+15", "X:")
        this.edtX := this.gui.AddEdit("xp+20 yp-2 w60 vClickX", this.clickX)
        this.txtY := this.gui.AddText("xp+70 yp", "Y:")
        this.edtY := this.gui.AddEdit("xp+20 yp-2 w60 vClickY", this.clickY)
        this.btnGetPos := this.gui.AddButton("xp+80 yp-2 w70", L["GetPos"])
        this.btnGetPos.OnEvent("Click", ObjBindMethod(this, "GetPos_Click"))

        ; Ẩn các control tọa độ nếu chưa check
        this.OnUsePosChanged()

        this.btnStart := this.gui.AddButton("xm y+20 Default", L["Start"])
        this.btnStart.OnEvent("Click", ObjBindMethod(this, "Start_Click"))
        this.gui.OnEvent("Close", ObjBindMethod(this, "OnClose"))

        this.L := L
        this.isRunning := false
    }

    OnOnlyActiveChanged(*) {
        show := this.rdoOnlyActive.Value || this.rdoHiddenClick.Value
        this.txtWin.Visible := show
        this.cb.Visible := show
        this.btnRefresh.Visible := show ; Ẩn/hiện nút Refresh cùng combobox
    }

    OnUsePosChanged(*) {
        show := this.chkUsePos.Value
        this.txtX.Visible := show
        this.edtX.Visible := show
        this.txtY.Visible := show
        this.edtY.Visible := show
        this.btnGetPos.Visible := show
    }
    OnRadioChanged(*) {
        isKey := this.btnRadioKey.Value
        this.hkKey.Visible := isKey
    }

    Show() {
        this.gui.Show("AutoSize")
    }

    Start_Click(*) {
        localIniDir := "VezylAutoClickerProton"
            localIni := localIniDir "\local.ini"
            if !DirExist(localIniDir)
                DirCreate localIniDir
            if FileExist(localIni)
                FileDelete localIni
            
        if (!this.isRunning) {
            ; Nếu chỉ click khi cửa sổ active hoặc click ẩn, bắt buộc phải chọn cửa sổ
            if (this.rdoOnlyActive.Value || this.rdoHiddenClick.Value) {
                if (this.cb.Text = "") {
                    MsgBox "Please select 1 window or click on 'All Windows'!"
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
            else if (this.btnRadioKey.Value) {
                this.button := "key"
                this.keyHotkey := this.hkKey.Value
                if (this.keyHotkey = "") {
                    MsgBox "Please select a key!"
                    return
                }
            }
            if (this.btnRadioKey.Value && this.rdoHiddenClick.Value) {
                MsgBox "Hidden click do not support key press!"
                return
            }
            this.interval := Integer(this.edtInterval.Value)
            if (this.interval < 1) {
                MsgBox "Click speed must be greater than 0!"
                return
            }
            hk := this.hkCtrl.Value
            if (hk = "") {
                MsgBox "Please enter a hotkey!"
                return
            }
            this.hotkey := hk
            ; Xác định chế độ onlyActive và hiddenClick
            this.onlyActive := this.rdoOnlyActive.Value
            this.hiddenClick := this.rdoHiddenClick.Value
            IniWrite(this.onlyActive,localIni, "General", "OnlyActive")
            IniWrite(this.hiddenClick,localIni, "General", "HiddenClick")

            this.randomInterval := this.chkRandomInterval.Value

            ; Lấy giá trị từ checkbox
            usePos := this.chkUsePos.Value
            if usePos {
                this.clickX := Trim(this.edtX.Value)
                this.clickY := Trim(this.edtY.Value)
                ; Nếu nhập thiếu 1 trong 2 thì bỏ qua (click theo chuột hiện tại)
                if (this.clickX = "" or this.clickY = "")
                    this.clickX := this.clickY := ""
            } else {
                this.clickX := this.clickY := ""
            }

            ; Xử lý file local.ini
            
            IniWrite(this.button,    localIni, "General", "Button")
            IniWrite(this.interval,  localIni, "General", "Interval")
            IniWrite(this.hotkey,    localIni, "General", "Hotkey")
            IniWrite(this.onlyActive,localIni, "General", "OnlyActive")
            IniWrite(this.randomInterval,localIni, "General", "RandomInterval")
            IniWrite(this.cb.Text,   localIni, "General", "WindowTitle")
            IniWrite(this.selectedID,localIni, "General", "WindowID")
            IniWrite(this.chkUsePos.Value, localIni, "General", "UsePos")
            IniWrite(this.edtX.Value,      localIni, "General", "ClickX")
            IniWrite(this.edtY.Value,      localIni, "General", "ClickY")

            if (IsObject(this.clicker))
                this.clicker.Stop()

            this.randomRange := Integer(IniRead("VezylAutoClickerEclectron\config.ini", "General", "RandomRange", "20"))
            this.clicker := AutoClicker(this.selectedID, this.button, this.interval, this.onlyActive, this.randomInterval, this.clickX, this.clickY, this.randomRange, this.keyHotkey, this.hiddenClick)
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

    GetPos_Click(*) {
        ; Nếu có chọn cửa sổ, active cửa sổ đó (chỉ khi chọn onlyActive)
        if (this.rdoOnlyActive.Value || this.rdoHiddenClick.Value) && this.cb.Text != "" {
            Loop this.winList.Length {
                if (this.winList[A_Index].title = this.cb.Text) {
                    try WinActivate("ahk_id " this.winList[A_Index].id)
                    break
                }
            }
            Sleep 300 ; Đợi cửa sổ active
        }
        ToolTip "Click chuột phải để lấy vị trí..."
        ; Đợi click chuột phải
        Hotkey("RButton", ObjBindMethod(this, "OnGetPosRButton"), "On")
    }

    OnGetPosRButton(*) {
        MouseGetPos(&x, &y) ; Lấy tọa độ tuyệt đối trên màn hình
        this.edtX.Value := x
        this.edtY.Value := y
        ToolTip
        Hotkey("RButton", ObjBindMethod(this, "OnGetPosRButton"), "Off")
        this.gui.Show("NA") ; Bring GUI to front
        this.gui.Show() 
    }

    RefreshWindowList(*) {
        this.winList := WindowManager.GetWindowList()
        this.titles := []
        for win in this.winList
            this.titles.Push(win.title)
        this.cb.Delete() ; Xóa hết các mục cũ
        this.cb.Add(this.titles) ; Thêm lại danh sách mới
        this.cb.Text := "" ; Reset lựa chọn
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