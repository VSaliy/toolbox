###
### Save this file as "install-software.ps1"
###

# check for elevated powershell
write-host -nonewline -fore cyan "Info: Verifying user is elevated:" 
If (-Not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    write-host -fore Red "NO"
    return write-error "You must run this script elevated."
}
write-host -fore Yellow "YES" 

write-host -fore cyan "Info: making temp directory."
$null = mkdir -ea 0 c:\tmp

function ReloadPathFromRegistry {
    write-host -fore darkcyan "      Reloading Path From Registry."
    $u = ([System.Environment]::GetEnvironmentVariable( "path", 'User'))
    $m = ([System.Environment]::GetEnvironmentVariable( "path", 'Machine'))
    $newPath = "$m;$u"
    $env:path = $newPath
}

# install gradle
if( !(get-command -ea 0 gradle.bat) ) { 
    write-host -fore cyan "Info: Downloading Gradle"
    (New-Object System.Net.WebClient).DownloadFile("https://services.gradle.org/distributions/gradle-4.4-bin.zip", "c:\tmp\gradle-4.4-bin.zip" )
    if( !(test-path -ea 0  "c:\tmp\gradle-4.4-bin.zip") ) { return write-error "Unable to download Maven" }
    write-host -fore darkcyan "      Unpacking Gradle."

    Expand-Archive C:\tmp\gradle-4.4-bin.zip -DestinationPath c:\

    write-host -fore darkcyan "      Adding gradle to system PATH."
    $p = ([System.Environment]::GetEnvironmentVariable( "path", 'Machine'))
    $p = "$p;C:\gradle-4.4\bin;"
    ([System.Environment]::SetEnvironmentVariable( "path", $p,  'Machine'))
    ReloadPathFromRegistry
    ([System.Environment]::SetEnvironmentVariable( 'GRADLE_HOME', "C:\gradle-4.4",  "Machine"))
    ReloadPathFromRegistry
    if( !(get-command -ea 0 mvn.cmd) ) { return write-error "No Maven in PATH." }
}

# install wix
<#
if (!(get-command -ea 0 heat.exe) ) {
    write-host -fore cyan "Info: Downloading Wix Toolset."
    invoke-webrequest "https://github.com/wixtoolset/wix3/releases/download/wix311rtm/wix311.exe" -outfile  "c:\tmp\wix311.exe"
    if( !(test-path -ea 0 "c:\tmp\wix311.exe" ) ) { return write-error "Unable to download Wix Toolset" }
    write-host -fore darkcyan "      Installing Wix Toolset"
    C:\tmp\wix311.exe /passive /noreboot
    while( get-process wix*  ) { write-host -NoNewline "." ; sleep 1 }
    write-host -fore darkcyan "      adding Wix Toolset to system PATH."
    $p = ([System.Environment]::GetEnvironmentVariable( "path", 'Machine'))
    $p = "$p;${env:ProgramFiles(x86)}\WiX Toolset v3.11\bin"
    ([System.Environment]::SetEnvironmentVariable( "path", $p,  'Machine'))
    ReloadPathFromRegistry
    if (!(get-command -ea 0 heat.exe) ) { return "No Wix Toolset in path." }
}#>
<#
# Install node.js via nvm
if( !(get-command -ea 0 node.exe) ) { 
    write-host -fore cyan "Info: Installing NodeJS."
    
    invoke-webrequest "https://github.com/coreybutler/nvm-windows/releases/download/1.1.1/nvm-noinstall.zip" -outfile  "c:\tmp\nvm.zip" 
    mkdir -force -ea 0 "$env:ALLUSERSPROFILE\nvm"
    Expand-Archive c:\tmp\nvm.zip -DestinationPath "$env:ALLUSERSPROFILE\nvm"

    $p = ([System.Environment]::GetEnvironmentVariable( "path", 'Machine'))
    $p = "$p;$env:ALLUSERSPROFILE\nvm;$env:ProgramFiles\nodejs;"
    ([System.Environment]::SetEnvironmentVariable( "path", $p,  'Machine'))
    ReloadPathFromRegistry

    $env:NVM_HOME="$env:ALLUSERSPROFILE\nvm"
    $env:NVM_SYMLINK="$env:ProgramFiles\nodejs"

    ([System.Environment]::SetEnvironmentVariable( "NVM_HOME", "$env:ALLUSERSPROFILE\nvm",  'Machine'))
    ([System.Environment]::SetEnvironmentVariable( "NVM_SYMLINK", "$env:ProgramFiles\nodejs",  'Machine'))

    set-content -Path "$env:ALLUSERSPROFILE\nvm\settings.txt" -Value "root: $env:ALLUSERSPROFILE\nvm`npath: $env:ProgramFiles\nodejs"
    nvm install 7.10.0
    nvm use 7.10.0 
   
    ReloadPathFromRegistry
   
    if( !(get-command -ea 0 node.exe) ) { return write-error "No NodeJS in PATH." }
#>    
<# for build machines, since I don't want this per-user    
    # use system-wide locations for npm
    npm config --global set cache "$env:ALLUSERSPROFILE\npm-cache"
    npm config --global set prefix "$env:ALLUSERSPROFILE\npm"
    $p = ([System.Environment]::GetEnvironmentVariable( "path", 'Machine'))
    $p = "$env:ALLUSERSPROFILE\npm;$p"
    ([System.Environment]::SetEnvironmentVariable( "path", $p,  'Machine'))    
    ReloadPathFromRegistry
#>    
#}