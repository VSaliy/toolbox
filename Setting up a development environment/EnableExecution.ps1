Set-ExecutionPolicy -Scope CurrentUser Unrestricted
Set-ExecutionPolicy Unrestricted

ls -Recurse *.ps1 | Unblock-File
ls -Recurse *.psm1 | Unblock-File