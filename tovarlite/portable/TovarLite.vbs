Option Explicit
' Zip-root launcher. Creates TovarLite.lnk beside this file, then opens the login-mode UI.
Dim sh, fso, dir, ps1, mePath, lnkPath, icoPath, sc
Set fso = CreateObject("Scripting.FileSystemObject")
Set sh = CreateObject("WScript.Shell")
mePath = WScript.ScriptFullName
dir = fso.GetParentFolderName(mePath)
ps1 = dir & "\App\TovarLitePortableUI.ps1"
icoPath = dir & "\App\logo.ico"

If Not fso.FileExists(ps1) Then
    MsgBox "Missing file:" & vbCrLf & ps1, vbCritical, "TovarLite"
    WScript.Quit 1
End If

lnkPath = dir & "\TovarLite.lnk"
Set sc = sh.CreateShortcut(lnkPath)
sc.TargetPath = mePath
sc.WorkingDirectory = dir
If fso.FileExists(icoPath) Then
    sc.IconLocation = icoPath & ",0"
End If
sc.Description = "TovarLite"
sc.Save

sh.Run "powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File """ & ps1 & """", 0, False
