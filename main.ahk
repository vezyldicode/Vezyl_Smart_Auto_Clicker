

; Đảm bảo mã hóa file là UTF-8 cho Unicode
FileEncoding "UTF-8"

; --- Biến toàn cục cờ lỗi ---
global ErrorFlag := false
global CONFIG_FILE := "VezylAutoClickerEclectron\config.ini"
global GLOBAL_ENV := "VezylAutoClickerProton\global.ini"
global LOCAL_ENV := "VezylAutoClickerProton\local.ini"


SetError(msg) {
    global ErrorFlag
    global app
    ErrorFlag := true
    ; Dừng auto click nếu đang chạy
    try {
        if (IsObject(app) && IsObject(app.clicker) && app.isRunning) {
            app.clicker.Stop()
            app.isRunning := false
            app.btnStart.Text := app.L.Has("Start") ? app.L["Start"] : "Bắt đầu"
            SetTimer(app.mouseCheckTimer, 0)
        }
    }
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
    __New(selectedID, button, interval, onlyActive, randomInterval := true, clickX := "", clickY := "", randomRange := 20, keyHotkey := "", hiddenClick := false, stopMode := "unlimited", stopCount := 100, stopTime := 10, clickType := "single") {
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
        this.stopMode := stopMode
        this.stopCount := stopCount
        this.stopTime := stopTime
        this.clickCounter := 0
        this.startTick := 0
        this.clickType := clickType
    }

    Start() {
        if (!this.running) {
            this.running := true
            this.clickCounter := 0
            this.startTick := A_TickCount
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
        this.clickCounter += 1
        if (this.stopMode = "count" && this.clickCounter >= this.stopCount) {
            this.Stop()
            MsgBox "Stopped after " this.stopCount " clicks."
            return
        }
        if (this.stopMode = "time" && ((A_TickCount - this.startTick) >= this.stopTime * 1000)) {
            this.Stop()
            MsgBox "Stopped after " this.stopTime " seconds."
            return
        }
        if (this.running)
            this._SetNextTimer()
    }

    ClickAtPosition() {
        ; Thuật toán random vị trí chuột nếu bật chkRandomPosition
        randX := this.clickX
        randY := this.clickY
        if (IsObject(this.parent) && IsObject(this.parent.chkRandomPosition) && this.parent.chkRandomPosition.Value) {
            range := this.parent.randomPosRange
            if (randX != "" && randY != "") {
                randX := Integer(this.clickX) + Random(-range, range)
                randY := Integer(this.clickY) + Random(-range, range)
            }
        }
        if (this.hiddenClick && this.selectedID != "") {
            btn := (this.button = "left") ? "Left" : (this.button = "right") ? "Right" : (this.button = "middle") ? "Middle" : "Left"
            if (randX != "" && randY != "") {
                ControlClick("x" randX " y" randY, "ahk_id " this.selectedID, , btn, , "NA")
                if (this.clickType = "double")
                    ControlClick("x" randX " y" randY, "ahk_id " this.selectedID, , btn, , "NA")
            } else {
                try {
                    ControlClick("", "ahk_id " this.selectedID, , btn, , "NA")
                    if (this.clickType = "double")
                        ControlClick("", "ahk_id " this.selectedID, , btn, , "NA")
                } catch {
                    SetError("Failed to click in window with ID: " this.selectedID "`nPlease ensure the window is valid and accessible. `nIf the issue persists, try using absolute coordinates instead.")
                    return
                }
            }
        } else if (this.button = "key" && this.keyHotkey != "") {
            Send "{" this.keyHotkey "}"
            if (this.clickType = "double")
                Send "{" this.keyHotkey "}"
        } else if (randX != "" && randY != "") {
            MouseGetPos(&curX, &curY)
            if (curX != randX || curY != randY)
                MouseMove(randX, randY, 0)
            Click(this.button)
            if (this.clickType = "double")
                Click(this.button)
        } else {
            Click(this.button)
            if (this.clickType = "double")
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
        this.button := "left"
        this.interval := 100
        this.hotkey := "F6"
        this.randomInterval := true
        this.usePos := false
        this.clickX := ""
        this.clickY := ""
        this.onlyActive := false
        this.hiddenClick := false
        ; Kiểm tra premium từ file config khi khởi động
        userKey := IniRead(GLOBAL_ENV, "General", "userError", "")
        serial64 := GetDriveSerialBase64()
        this.IsPremium := (userKey != "" && this.VerifyKey(serial64, userKey))

        ; Đọc ngôn ngữ từ config
        langCode := IniRead(CONFIG_FILE, "General", "Language", "en")
        langPath := "resources\lang\" langCode ".ini"
        L := Map()
        if FileExist(langPath) {
            for key in ["MouseButton","Left","Right","Middle","ClickSpeed","Hotkey","SelectWindow","Start","Stop", "MsgSelectWindow","MsgEnterHotkey","MsgClickSpeed","RandomInterval","RandomPos","UsePos", "Refresh", "GetPos", "Key", "AllWindows", "OnlyActive", "HiddenClick"]
                L[key] := IniRead(langPath, "Label", key, key)
        } else {
            ; fallback sang en.ini hoặc giá trị mặc định
            langPath := "resources\lang\en.ini"
            for key in ["MouseButton","Left","Right","Middle","ClickSpeed","Hotkey","SelectWindow","Start","Stop", "MsgSelectWindow","MsgEnterHotkey","MsgClickSpeed","RandomInterval","RandomPos","UsePos", "Refresh", "GetPos", "Key", "AllWindows", "OnlyActive", "HiddenClick"]
                L[key] := IniRead(langPath, "Label", key, key)
        }

        if FileExist(LOCAL_ENV) {
            iniPath := LOCAL_ENV
        } else {
            iniPath := GLOBAL_ENV
        }
        this.winList := WindowManager.GetWindowList()
        this.titles := []
        for win in this.winList
            this.titles.Push(win.title)
        this.selectedID := ""
        this.clicker := ""

        this.gui := Gui()
        this.gui.BackColor := 0xFBFBFB
        this.gui.SetFont("s9", "Segoe UI")
        if this.IsPremium
            this.gui.Title := "Vezyl Smart Auto Clicker Pro"
        else
            this.gui.Title := "Vezyl Smart Auto Clicker"

        this.gui.SetFont("s20", "Segoe UI")
        this.gui.Add("Text", "x8 y8 w482 h41 +0x200", "Vezyl Smart Auto Clicker")
        this.gui.SetFont()
        this.gui.SetFont("s9", "Segoe UI")
        this.gui.Add("Text", "x-8 y55 w503 h2 +0x10", "")


        ; --- Chọn nút chuột bằng combobox ---
        this.gui.AddText("x8 y63 w97 h26 +0x200", L["MouseButton"])
        this.cbButton := this.gui.AddComboBox("x109 y64 w120 vButtonType", [L["Left"], L["Right"], L["Middle"], L["Key"]])
        ; Gán giá trị ban đầu cho combobox
        btnIndex := (this.button = "left") ? 1 : (this.button = "right") ? 2 : (this.button = "middle") ? 3 : 4
        this.cbButton.Value := btnIndex
        this.cbButton.OnEvent("Change", ObjBindMethod(this, "OnButtonTypeChanged"))

        ; --- Radio: Single Click hoặc Double Click ---
        this.rdoSingleClick := this.gui.AddRadio("x360 y64 w130 h28", "Single Click")
        this.rdoDoubleClick := this.gui.AddRadio("x496 y64 w160 h26", "Double Click")

        ; --- Hotkey cho phím bất kỳ ---
        this.hkKey := this.gui.AddHotkey("x232 y64 w120 h24 vKeyHotkey", this.keyHotkey ? this.keyHotkey : "")
        ; Ẩn mặc định nếu không chọn 'Key'
        this.hkKey.Visible := (this.button = "key")


        ; --- Tốc độ click và Hotkey---
        this.gui.AddText("x359 y104 w120 h23 +0x200", L["ClickSpeed"])
        this.edtInterval := this.gui.AddEdit("x480 y104 w67 h25 vInterval", this.interval)
        this.gui.AddText("x7 y104 w150 h23 +0x200", L["Hotkey"])
        this.hkCtrl := this.gui.AddHotkey("x159 y103 w50 h26 vHotkey", this.hotkey)


        ; --- Đọc randomRange từ config ---
        this.randomRange := Integer(IniRead(CONFIG_FILE, "General", "RandomRange", "20"))
        randomLabel := (L.Has("RandomInterval") ? L["RandomInterval"] : "Random interval") " (+-" this.randomRange "ms)"

        ; --- Checkbox random interval ---
        this.chkRandomInterval := this.gui.AddCheckBox( "x8 y374 w290 h23 vRandomInterval" (this.randomInterval?" Checked":""), randomLabel)

        this.randomPosRange := Integer(IniRead(CONFIG_FILE, "General", "RandomPosRange", "20"))
        randomPosLabel := (L.Has("RandomPos") ? L["RandomPos"] : "Random Position") " (+-" this.randomPosRange "px)"
        this.chkRandomPosition := this.gui.AddCheckBox("x328 y376 w329 h23 vRandomPosition", (this.randomPosRange ? randomPosLabel : "Random Position"))

        ; --- Radio: Chỉ click khi cửa sổ active, click toàn bộ, hoặc click ẩn (xếp dọc) ---
        this.rdoAllWindows := this.gui.AddRadio( "x8 y192 w289 h23 vRdoAllWindows", L.Has("AllWindows") ? L["AllWindows"] : "Click trên toàn bộ cửa sổ")
        this.rdoOnlyActive := this.gui.AddRadio( "x8 y223 w288 h23 vRdoOnlyActive", L.Has("OnlyActive") ? L["OnlyActive"] : "Chỉ click khi cửa sổ được chọn đang active")
        this.rdoHiddenClick := this.gui.AddRadio("x8 y256 w290 h23 vRdoHiddenClick", L.Has("HiddenClick") ? L["HiddenClick"] : "Click ẩn (không cần cửa sổ active)")
        this.rdoOnlyActive.OnEvent("Click", ObjBindMethod(this, "OnOnlyActiveChanged"))
        this.rdoAllWindows.OnEvent("Click", ObjBindMethod(this, "OnOnlyActiveChanged"))
        this.rdoHiddenClick.OnEvent("Click", ObjBindMethod(this, "OnOnlyActiveChanged"))

        ; --- Đọc lại chế độ click sau khi đã tạo radio ---
        clickMode := IniRead(iniPath, "General", "ClickMode", "all")
        this.rdoAllWindows.Value := (clickMode = "all")
        this.rdoOnlyActive.Value := (clickMode = "active")
        this.rdoHiddenClick.Value := (clickMode = "hidden")
        this.onlyActive := (clickMode = "active") ; <-- Thêm dòng này
        this.hiddenClick := (clickMode = "hidden") ; <-- Thêm dòng này

        ; --- Chọn cửa sổ ---
        this.txtWin := this.gui.AddText("x320 y194 w337 h23 +0x200 +Center", L["SelectWindow"])
        this.cb := this.gui.AddComboBox("x320 y224  vWinTitle w257", this.titles)
        this.btnRefresh := this.gui.AddButton("x584 y225 w73 h23", L["Refresh"]) ; Nút refresh
        this.btnRefresh.OnEvent("Click", ObjBindMethod(this, "RefreshWindowList"))

        if !this.onlyActive {
            this.txtWin.Visible := false
            this.cb.Visible := false
            this.btnRefresh.Visible := false
        }
        ; --- Checkbox bật/tắt click tại vị trí chỉ định ---
        this.chkUsePos := this.gui.AddCheckBox("x8 y296 w129 h23 vUsePos" (this.usePos ? " Checked" : ""), L["UsePos"])
        this.chkUsePos.OnEvent("Click", ObjBindMethod(this, "OnUsePosChanged"))

        ; --- Nhập tọa độ click và nút Get Pos ---
        this.txtX := this.gui.AddText("x148 y296 w27 h23 +0x200", "X:")
        this.edtX := this.gui.AddEdit("x176 y296 w74 h25 vClickX", this.clickX)
        this.txtY := this.gui.AddText("x271 y296 w27 h23 +0x200", "Y:")
        this.edtY := this.gui.AddEdit("x299 y296 w74 h25 vClickY", this.clickY)
        this.btnGetPos := this.gui.AddButton("x375 y295 w139 h28", L["GetPos"])
        this.btnGetPos.OnEvent("Click", ObjBindMethod(this, "GetPos_Click"))

        ; Ẩn các control tọa độ nếu chưa check
        this.OnUsePosChanged()

        ; --- Checkbox Auto Stop ---
        this.autoStop := !!IniRead(iniPath, "General", "AutoStop", "0")
        this.chkAutoStop := this.gui.AddCheckBox("x8 y335 w120 h23 vAutoStop" (this.autoStop ? " Checked" : ""), "Auto Stop")

        ; Thêm label "What is auto stop?" bên cạnh checkbox
        this.lblAutoStopInfo := this.gui.AddText("x132 y337 w120 h23 +0x200 cBlue", "What is auto stop?")
        this.lblAutoStopInfo.OnEvent("Click", (*) => (
            MouseGetPos(&mx, &my),
            ToolTip("Auto Stop if mouse moves too fast (to prevent losing control).`n Doesnt work on Hidden Click mode.`nTurn off if you don't want this feature."),
            SetTimer(() => ToolTip(), -5000)
        ))
        ; Tooltip sẽ hiển thị ngay tại vị trí chuột và tự tắt sau 5 giây bằng SetTimer


                ; --- Tùy chọn dừng ---
        this.rdoUnlimited := this.gui.AddRadio("x8 y145 w147 h23 vRdoUnlimited Checked Group", "Unlimited")
        this.rdoStopCount := this.gui.AddRadio("x161 y146 w102 h23 vRdoStopCount", "Stop after")
        this.rdoStopTime := this.gui.AddRadio("x400 y148 w89 h23 vRdoStopTime", "Stop after")

        ; Đặt các Edit/Text cùng dòng với radio tương ứng
        this.edtStopCount := this.gui.AddEdit("x264 y147 w63 h21 vStopCount Disabled", "100")
        this.txtClicks := this.gui.AddText("x329 y147 w61 h23 +0x200", "clicks")
        this.edtStopTime := this.gui.AddEdit("x490 y150 w63 h21 vStopTime Disabled", "10")
        this.txtSeconds := this.gui.AddText("x555 y150 w61 h23 +0x200", "seconds")

        ; Sự kiện bật/tắt edit box
        this.rdoUnlimited.OnEvent("Click", (*) => (
            this.edtStopCount.Enabled := false,
            this.edtStopTime.Enabled := false
        ))
        this.rdoStopCount.OnEvent("Click", (*) => (
            this.edtStopCount.Enabled := true,
            this.edtStopTime.Enabled := false
        ))
        this.rdoStopTime.OnEvent("Click", (*) => (
            this.edtStopCount.Enabled := false,
            this.edtStopTime.Enabled := true
        ))
                ; --- Thêm nút Load/Save Config ---
        this.btnLoadConfig := this.gui.AddButton("x327 y407 w336 h25", "Load Config")
        this.btnSaveConfig := this.gui.AddButton("x8 y407 w306 h25", "Save Config")
        this.btnLoadConfig.OnEvent("Click", ObjBindMethod(this, "LoadConfig_Click"))
        this.btnSaveConfig.OnEvent("Click", ObjBindMethod(this, "SaveConfig_Click"))


        this.btnStart := this.gui.AddButton("x494 y8 w176 h49 Default", "Start")
        this.btnStart.OnEvent("Click", ObjBindMethod(this, "Start_Click"))
        this.gui.OnEvent("Close", ObjBindMethod(this, "OnClose"))

        

        this.L := L
        this.isRunning := false
        this.mouseCheckTimer := ObjBindMethod(this, "CheckMouseSpeed")
        this.lastMouseX := 0
        this.lastMouseY := 0
        this.lastMouseCheckTime := 0

        this.LoadIniToGUI(iniPath)



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
    OnButtonTypeChanged(*) {
        ; Cập nhật thuộc tính button dựa trên combobox
        idx := this.cbButton.Value
        btns := ["left", "right", "middle", "key"]
        this.button := btns[idx]
        ; Nếu chọn 'key' thì hiện hotkey, ngược lại ẩn
        this.hkKey.Visible := (this.button = "key")
    }

    Show() {
        this.gui.Show("w681 h466")
    }
    LoadConfig_Click(*) {
        file := FileSelect(1, , "Select config file", "*.ini")
        if !file
            return
        this.LoadIniToGUI(file)
        MsgBox "Config loaded!"
    }
        LoadIniToGUI(file) {
        this.button := IniRead(file, "General", "Button", "left")
        this.interval := Integer(IniRead(file, "General", "Interval", "100"))
        this.hotkey := IniRead(file, "General", "Hotkey", "F6")
        this.randomInterval := !!IniRead(file, "General", "RandomInterval", "1")
        this.usePos := !!IniRead(file, "General", "UsePos", "0")
        this.clickX := IniRead(file, "General", "ClickX", "")
        this.clickY := IniRead(file, "General", "ClickY", "")
        this.chkRandomInterval.Value := this.randomInterval
        this.chkUsePos.Value := this.usePos
        this.edtInterval.Value := this.interval
        this.hkCtrl.Value := this.hotkey
        this.edtX.Value := this.clickX
        this.edtY.Value := this.clickY
        btnIndex := (this.button = "left") ? 1 : (this.button = "right") ? 2 : (this.button = "middle") ? 3 : 4
        this.cbButton.Value := btnIndex
        this.hkKey.Visible := (this.button = "key")
        clickMode := IniRead(file, "General", "ClickMode", "all")
        this.rdoAllWindows.Value := (clickMode = "all")
        this.rdoOnlyActive.Value := (clickMode = "active")
        this.rdoHiddenClick.Value := (clickMode = "hidden")
        this.onlyActive := !!IniRead(file, "General", "OnlyActive", "0")
        this.hiddenClick := !!IniRead(file, "General", "HiddenClick", "0")
        this.OnOnlyActiveChanged()
        this.chkAutoStop.Value := !!IniRead(file, "General", "AutoStop", "0")
        clickType := IniRead(file, "General", "ClickType", "single")
        this.rdoSingleClick.Value := (clickType = "single")
        this.rdoDoubleClick.Value := (clickType = "double")
        this.chkRandomPosition.Value := !!IniRead(file, "General", "RandomPosition", "0")
        stopMode := IniRead(file, "General", "StopMode", "unlimited")
        this.rdoUnlimited.Value := (stopMode = "unlimited")
        this.rdoStopCount.Value := (stopMode = "count")
        this.rdoStopTime.Value := (stopMode = "time")
        this.edtStopCount.Value := IniRead(file, "General", "StopCount", "100")
        this.edtStopTime.Value := IniRead(file, "General", "StopTime", "10")
        this.selectedID := IniRead(file, "General", "WindowID", "")
        this.cb.Text := IniRead(file, "General", "WindowTitle", "")
    }

    SaveGUIToIni(file) {
        IniWrite(this.button, file, "General", "Button")
        IniWrite(String(this.edtInterval.Value), file, "General", "Interval")
        IniWrite(String(this.hkCtrl.Value), file, "General", "Hotkey")
        IniWrite(this.chkRandomInterval.Value ? "1" : "0", file, "General", "RandomInterval")
        IniWrite(String(this.cb.Text), file, "General", "WindowTitle")
        IniWrite(String(this.selectedID), file, "General", "WindowID")
        IniWrite(this.chkUsePos.Value ? "1" : "0", file, "General", "UsePos")
        IniWrite(String(this.edtX.Value), file, "General", "ClickX")
        IniWrite(String(this.edtY.Value), file, "General", "ClickY")
        IniWrite(this.chkAutoStop.Value ? "1" : "0", file, "General", "AutoStop")
        clickMode := this.rdoAllWindows.Value ? "all" : this.rdoOnlyActive.Value ? "active" : "hidden"
        IniWrite(clickMode, file, "General", "ClickMode")
        IniWrite(this.rdoOnlyActive.Value ? "1" : "0", file, "General", "OnlyActive")
        IniWrite(this.rdoHiddenClick.Value ? "1" : "0", file, "General", "HiddenClick")
        ; --- Lưu kiểu click ---
        clickType := this.rdoSingleClick.Value ? "single" : "double"
        IniWrite(clickType, file, "General", "ClickType")
        ; --- Lưu random position ---
        IniWrite(this.chkRandomPosition.Value ? "1" : "0", file, "General", "RandomPosition")
        ; --- Lưu tùy chọn dừng ---
        stopMode := this.rdoUnlimited.Value ? "unlimited" : this.rdoStopCount.Value ? "count" : "time"
        IniWrite(stopMode, file, "General", "StopMode")
        IniWrite(String(this.edtStopCount.Value), file, "General", "StopCount")
        IniWrite(String(this.edtStopTime.Value), file, "General", "StopTime")
    }

    SaveConfig_Click(*) {
        file := FileSelect(2, , "Save config as", "*.ini")
        if !file
            return
        if !RegExMatch(file, "\.ini$") {
            file .= ".ini"
        }
        this.SaveGUIToIni(file)
        MsgBox "Config saved!"
    }

    Start_Click(*) {
        localIni := LOCAL_ENV

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

        if (!this.IsPremium) {
            if (this.rdoHiddenClick.Value) {
                ; MsgBox "This feature is only available in the Premium version. Please upgrade to use it."
                this.ShowLicenseBox()
                return
            }
        }
        
            ; Lấy giá trị nút chuột từ combobox
            btns := ["left", "right", "middle", "key"]
            this.button := btns[this.cbButton.Value]
            if (this.button = "key") {
                this.keyHotkey := this.hkKey.Value
                if (this.keyHotkey = "") {
                    MsgBox "Please select a key!"
                    return
                }
                if (this.rdoHiddenClick.Value) {
                    MsgBox "Hidden click do not support key press!"
                    return
                }
            }
            this.interval := Integer(this.edtInterval.Value)
            if (this.interval < 1) {
                MsgBox "Click speed must be greater than 0!"
                return
            }
            if(this.chkRandomPosition.Value && !this.chkUsePos.Value) {
                MsgBox "Random Position requires Use Position to be checked!"
                return
            }
            hk := this.hkCtrl.Value
            if (hk = "") {
                MsgBox "Please enter a hotkey!"
                return
            }
            this.hotkey := hk
            ; Xác định chế độ click
            if (this.rdoAllWindows.Value)
                clickMode := "all"
            else if (this.rdoOnlyActive.Value)
                clickMode := "active"
            else if (this.rdoHiddenClick.Value)
                clickMode := "hidden"
            IniWrite(clickMode, localIni, "General", "ClickMode")

            ; Xác định chế độ onlyActive và hiddenClick
            this.onlyActive := this.rdoOnlyActive.Value
            this.hiddenClick := this.rdoHiddenClick.Value

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

            ; Lưu các giá trị GUI vào local.ini
            this.SaveGUIToIni(localIni)

            if (IsObject(this.clicker))
                this.clicker.Stop()

            this.randomRange := Integer(IniRead(CONFIG_FILE, "General", "RandomRange", "20"))
            stopMode := this.rdoUnlimited.Value ? "unlimited" : this.rdoStopCount.Value ? "count" : "time"
            clickType := this.rdoSingleClick.Value ? "single" : "double"
            this.clicker := AutoClicker(
                this.selectedID, this.button, this.interval, this.onlyActive, this.randomInterval,
                this.clickX, this.clickY, this.randomRange, this.keyHotkey, this.hiddenClick,
                stopMode, Integer(this.edtStopCount.Value), Integer(this.edtStopTime.Value), clickType
            )
            this.clicker.parent := this ; Truyền tham chiếu đến GUI để lấy randomPosRange và trạng thái checkbox
            if (this.hotkey) {
                try Hotkey(this.hotkey, , "Off")
            }
            Hotkey(this.hotkey, ObjBindMethod(this, "ToggleClicker"), "On")
            this.isRunning := true
            this.btnStart.Text := (this.L.Has("Stop") ? this.L["Stop"] : "Dừng")
            SoundBeep
            Sleep 100
            SoundBeep
            this.clicker.Start()
            ; Bắt đầu kiểm tra tốc độ chuột nếu Auto Stop bật
            if (this.chkAutoStop.Value && (this.rdoAllWindows.Value || this.rdoOnlyActive.Value)) {
                local mx, my
                MouseGetPos(&mx, &my)
                this.lastMouseX := mx
                this.lastMouseY := my
                this.lastMouseCheckTime := A_TickCount
                SetTimer(this.mouseCheckTimer, 30)
            }
        } else {
            if (IsObject(this.clicker))
                this.clicker.Stop()
            this.isRunning := false
            this.btnStart.Text := this.L.Has("Start") ? this.L["Start"] : "Bắt đầu"
            SoundBeep
            SetTimer(this.mouseCheckTimer, 0)
        }
    }
    ToggleClicker(*) {
        if (this.isRunning)
            this.Stop_Click()
        else
            this.Start_Click()
    }
    Stop_Click(*) {
        if (IsObject(this.clicker))
            this.clicker.Stop()
        this.isRunning := false
        this.btnStart.Text := this.L.Has("Start") ? this.L["Start"] : "Bắt đầu"
        SoundBeep
        SetTimer(this.mouseCheckTimer, 0)
    }
    CheckMouseSpeed(*) {
        MouseGetPos(&curX, &curY)
        now := A_TickCount
        dt := now - this.lastMouseCheckTime
        if (dt < 10) ; tránh chia 0 hoặc quá nhỏ
            return
        dx := curX - this.lastMouseX
        dy := curY - this.lastMouseY
        dist := Sqrt(dx*dx + dy*dy)
        speed := dist / dt ; px/ms
        ; Ngưỡng tốc độ: ví dụ > 50 px/ms (tương đương 5000px trong 100ms)
        if (speed > 50 && this.isRunning && this.chkAutoStop.Value && (this.rdoAllWindows.Value || this.rdoOnlyActive.Value)) {
            SetTimer(this.mouseCheckTimer, 0)
            SetError("Auto click stopped: Mouse moved too fast! (Auto Stop)")
        }
        this.lastMouseX := curX
        this.lastMouseY := curY
        this.lastMouseCheckTime := now
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
        ToolTip "Right click to get position..."
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
    ShowLicenseBox() {
        licensegui := Gui("+AlwaysOnTop", "Enter License Key")
        licensegui.SetFont("s10", "Segoe UI")
        serial64 := GetDriveSerialBase64()
        licensegui.AddText("xm", "Enter License Key to use Premium feature:")
        edt := licensegui.AddEdit("xm w250 vKey")
        lblInvalid := licensegui.AddText("xm y+5 w220 cRed", "") ; label báo lỗi, thêm w220 để đủ rộng
        btnOK := licensegui.AddButton("xm w120", "OK")
        btnNoKey := licensegui.AddButton("x+10 w120", "I dont have one")
        result := ""
        closed := false
        btnOK.OnEvent("Click", (*) => (
            result := edt.Value,
            lblInvalid.Text := "",
            (Trim(result) != "" ? (
                IniDelete(GLOBAL_ENV, "General", "userError"),
                IniWrite(result, GLOBAL_ENV, "General", "userError"),
                this.VerifyKey(serial64, result)
                    ? (
                        closed := true,
                        licensegui.Destroy(),
                        MsgBox("License key accepted! You can now use Premium features."),
                        Run(A_ScriptFullPath),
                        ExitApp
                    )
                    : (lblInvalid.Text := "Invalid key!", edt.Focus())
            ) : "")
        ))
        btnNoKey.OnEvent("Click", (*) => (
            edt.Value := serial64, ; Gán personal ID vào textbox nhập key
            edt.Focus()            ; Đưa focus vào textbox để dễ copy
        ))
        licensegui.OnEvent("Close", (*) => (
            closed := true,
            licensegui.Destroy()
        ))
        licensegui.Show("w280 h140")
        while !closed
            Sleep 50
    }
    VerifyKey(base64, key) {
        secret := "vezyl2025pros" ; Đổi thành chuỗi bí mật giống hàm trên
        expected := SubStr(this.Hash("MD5", base64 . secret), 1, 16)
        if (key = "802b166628fd049e") {
            expected := "802b166628fd049e" ; Key mặc định cho người dùng thử
        }
        return (key = expected)
    }

    Hash(alg, input) {
        if (alg != "MD5")
            throw Error("Chỉ hỗ trợ MD5")
        tmpFile := A_Temp . "\\ahk_md5_input.txt"
        if FileExist(tmpFile)
            FileDelete tmpFile
        FileAppend input, tmpFile, "UTF-8"
        hash := ""
        try {
            for line in StrSplit(StdOut := this.ExecGetStdOut('certutil -hashfile "' tmpFile '" MD5'), "`n") {
                if RegExMatch(line, "i)^[0-9a-f]{32}$", &m) {
                    hash := m[0]
                    break
                }
            }
        } catch {
            ; Handle error
        }
        if FileExist(tmpFile)
            FileDelete tmpFile
        return hash
    }

    ExecGetStdOut(cmd) {
        tmpOut := A_Temp . "\\ahk_md5_output.txt"
        RunWait cmd . ' > "' . tmpOut . '"', , "Hide"
        if FileExist(tmpOut) {
            result := FileRead(tmpOut, "UTF-8")
            FileDelete tmpOut
            return result
        }
        return ""
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

GetDriveSerialBase64() {
    serial := DriveGetSerial("C:\")
    return BufferToBase64(serial)
}

BufferToBase64(str) {
    buf := Buffer(StrPut(str, "UTF-8"))
    StrPut(str, buf, "UTF-8")
    return CryptBinaryToString(buf)
}

CryptBinaryToString(buf) {
    static CRYPT_STRING_BASE64 := 0x1
    DllCall("Crypt32.dll\CryptBinaryToStringW"
        , "Ptr", buf.Ptr
        , "UInt", buf.Size
        , "UInt", CRYPT_STRING_BASE64
        , "Ptr", 0
        , "UInt*", &len := 0)
    out := Buffer(len * 2)
    DllCall("Crypt32.dll\CryptBinaryToStringW"
        , "Ptr", buf.Ptr
        , "UInt", buf.Size
        , "UInt", CRYPT_STRING_BASE64
        , "Ptr", out.Ptr
        , "UInt*", &len)
    return StrGet(out, len)
}