Option Explicit
' Compatibility launcher for older desktop shortcuts that pointed at App\Launch-TovarLite.vbs
Dim sh, fso, app, ps1, cmd
Set fso = CreateObject("Scripting.FileSystemObject")
Set sh = CreateObject("WScript.Shell")
app = fso.GetParentFolderName(WScript.ScriptFullName)
ps1 = app & "\TovarLitePortableUI.ps1"

If Not fso.FileExists(ps1) Then
    MsgBox "Missing file:" & vbCrLf & ps1, vbCritical, "TovarLite"
    WScript.Quit 1
End If

cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File """ & ps1 & """"
sh.Run cmd, 0, False
