#Requires AutoHotkey v2.0

; Hàm Hash MD5 sử dụng certutil (không cần .NET)
Hash(alg, input) {
    if (alg != "MD5")
        throw Error("Chỉ hỗ trợ MD5")
    tmpFile := A_Temp . "\\ahk_md5_input.txt"
    if FileExist(tmpFile)
        FileDelete tmpFile
    FileAppend input, tmpFile, "UTF-8"
    hash := ""
    try {
        for line in StrSplit(StdOut := ExecGetStdOut('certutil -hashfile "' tmpFile '" MD5'), "`n") {
            if RegExMatch(line, "i)^[0-9a-f]{32}$", &m) {
                hash := m[0]
                break
            }
        }
    }
    if FileExist(tmpFile)
        FileDelete tmpFile
    return hash
}

ExecGetStdOut(cmd) {
    shell := ComObject("WScript.Shell")
    exec := shell.Exec(cmd)
    return exec.StdOut.ReadAll()
}

; Hàm tạo key từ 1 dãy base64 (ví dụ: hardware ID base64)
GenKeyFromBase64(base64) {
    secret := "vezyl2025pros" ; Đổi thành chuỗi bí mật của bạn
    return SubStr(Hash("MD5", base64 . secret), 1, 16)
}

; Hàm giải mã key (kiểm tra key có hợp lệ với base64 không)
VerifyKey(base64, key) {
    secret := "vezyl2025pros" ; Đổi thành chuỗi bí mật giống hàm trên
    expected := SubStr(Hash("MD5", base64 . secret), 1, 16)
    return (key = expected)
}

; === GUI đơn giản ===
myGui := Gui()
myGui.Title := "AutoKey Tool"
myGui.AddText(, "Base64:")
base64Edit := myGui.AddEdit("w300")
myGui.AddText(, "Key:")
keyEdit := myGui.AddEdit("w300")

btnGen := myGui.AddButton("x10 y+10 w140", "Tạo Key từ Base64")
btnCheck := myGui.AddButton("x+10 yp w140", "Kiểm tra Key")

btnGen.OnEvent("Click", GenKey)
btnCheck.OnEvent("Click", CheckKey)

GenKey(*) {
    base64 := base64Edit.Value
    key := GenKeyFromBase64(base64)
    keyEdit.Value := key
}

CheckKey(*) {
    base64 := base64Edit.Value
    key := keyEdit.Value
    if VerifyKey(base64, key)
        MsgBox "Key hợp lệ cho base64 này!", "Kết quả", 64
    else
        MsgBox "Key KHÔNG hợp lệ!", "Kết quả", 16
}

myGui.Show()

