function VerifyUserElevation {
    write-host -nonewline -fore cyan "Info: Verifying user is elevated:" 
    If (-Not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        write-host -fore Red "NO"
        return write-error "You must run this script elevated."
    }
    write-host -fore Yellow "YES" 
}

function MakeTempDirectory {
    write-host -fore cyan "Info: making temp directory."
    $null = mkdir -ea 0 c:\tmp
}

function DiffPathFromRegistry {
    $u = ([System.Environment]::GetEnvironmentVariable( "path", 'User'))
    $m = ([System.Environment]::GetEnvironmentVariable( "path", 'Machine'))
    $newPath = "$m;$u"
    $np = $newpath.split(";") |% { $_.trim("\").Trim() }
    $op = $env:path.split(";") |% { $_.trim("\").Trim() }
    diff $np $op
}

function ReloadPathFromRegistry {
    write-host -fore darkcyan "      Reloading Path From Registry."
    $u = ([System.Environment]::GetEnvironmentVariable( "path", 'User'))
    $m = ([System.Environment]::GetEnvironmentVariable( "path", 'Machine'))
    $newPath = "$m;$u"
    $env:path = $newPath
}

function GetEnvironmentFromRegistry {
    ([System.Environment]::GetEnvironmentVariables( 'User'))
    ([System.Environment]::GetEnvironmentVariables( 'Machine'))
}

# install chocolatey oneget provider
function InstallChocolatey {
    write-host -fore cyan "Info: Ensuring Chocolatey OneGet provider is installed."
    $pp = get-packageprovider -force chocolatey
    if( !$pp ) { return write-error "can't get chocolatey package provider "}
    # start with a clean slate.
    ReloadPathFromRegistry
}

# install nuget oneget provider
function InstallNuGet {
    write-host -fore cyan "Info: Ensuring NuGet OneGet provider is installed."
    $np = get-packageprovider -force nuget
    if( !$np ) { return write-error "can't get nuget package provider "}
    # start with a clean slate.
    ReloadPathFromRegistry
}

# install jdk8
function InstallJDK8 {
    if( !(get-command -ea 0 java.exe) ) {
        write-host -fore cyan "Info: Installing JDK 8."
        $null = install-package -provider chocolatey jdk8 -force
        if( !(get-command -ea 0 java.exe) ) { return write-error "No Java in PATH." }
    }
    write-host -fore darkcyan "      Setting JAVA_HOME environment key."
    ([System.Environment]::SetEnvironmentVariable('JAVA_HOME',  (resolve-path "$((get-command -ea 0 javac).Source)..\..\..").Path , "Machine" ))
}

# install intellijidea-ultimate
function InstallIntelliJIDEA {
    if( !(get-command -ea 0 idea.exe) ) {

        write-host -fore cyan "Info: Downloading InteliiJ IDEA 2017.3"
        ( New-Object System.Net.WebClient).DownloadFile("https://download.jetbrains.com/idea/ideaIU-2017.3.exe","c:\tmp\ideaIU-2017.3.exe")
        ( New-Object System.Net.WebClient).DownloadFile("https://gist.githubusercontent.com/VSaliy/d8d923759f694b1681260ce937e65487/raw/9440f8bc3ac550ff9ee03a4607423bcb39705b10/silent.config","c:\tmp\silent.config")
        if( !(test-path -ea 0  "c:\tmp\ideaIU-2017.3.exe" ) ) { return write-error "Unable to download IntelliJ IDEA" }
        if( !(test-path -ea 0  "c:\tmp\silent.config" ) ) { return write-error "Unable to download IntelliJ IDEA" }

        write-host -fore cyan "Info: Installing IntelliJ IDEA"
        C:\tmp\ideaIU-2017.3.exe /S /CONFIG=c:\tmp\silent.config /D=d:\dev\ide\ideaIU-2017.3
        while( (get-process -ea 0 ideaIU*) )  { write-host -NoNewline "|" ; sleep 1 }
        ReloadPathFromRegistry

        write-host -fore darkcyan "      Adding IDEA to system PATH."
        $p = ([System.Environment]::GetEnvironmentVariable( "path", 'Machine'))
        $p = "$p;D:\dev\ide\ideaIU-2017.3\bin;"
        ([System.Environment]::SetEnvironmentVariable( "path", $p,  'Machine'))
        ReloadPathFromRegistry
        ([System.Environment]::SetEnvironmentVariable( 'IDEA_HOME', "d:\dev\ide\ideaIU-2017.3",  "Machine"))
        ReloadPathFromRegistry
        if( !(get-command -ea 0 idea64.exe) ) { return write-error "No idea in PATH." }
    }
}

# Install node.js via nvm
function InstallNodeJSviaNVM {
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
        
    <# for build machines, since I don't want this per-user    
        # use system-wide locations for npm
        npm config --global set cache "$env:ALLUSERSPROFILE\npm-cache"
        npm config --global set prefix "$env:ALLUSERSPROFILE\npm"
        $p = ([System.Environment]::GetEnvironmentVariable( "path", 'Machine'))
        $p = "$env:ALLUSERSPROFILE\npm;$p"
        ([System.Environment]::SetEnvironmentVariable( "path", $p,  'Machine'))    
        ReloadPathFromRegistry
    #>    
    }
}

# install gulp
function InstallGulp {
    if( !(get-command -ea 0 gulp) ) {
        write-host -fore cyan "Info: Installing Gulp globally."
        npm install -g gulp
        if( !(get-command -ea 0 gulp) ) { return write-error "No gulp in PATH. (npm bin folder missing?)" }
    }
}

# install 7zip
function Install7zip {
    if( ! (test-path -ea 0  "$env:ProgramFiles\7-Zip\7z.exe")) {
        write-host -fore cyan "Info: Downloading 7zip."
        ( New-Object System.Net.WebClient).DownloadFile("http://www.7-zip.org/a/7z1604-x64.msi", "c:\tmp\7z1604-x64.msi" );
        if( !(test-path -ea 0  "c:\tmp\7z1604-x64.msi") ) { return write-error "Unable to download 7zip installer" }
        write-host -fore darkcyan "      Installing 7Zip."
        Start-Process -wait -FilePath msiexec -ArgumentList  "/i", "c:\tmp\7z1604-x64.msi", "/passive"
    
        if( ! (test-path -ea 0  "$env:ProgramFiles\7-Zip\7z.exe"))  { return write-error "Unable to install 7zip" } 
    }
}

# install Ruby 2.3
function InstallRuby {
    if( !(get-command -ea 0 ruby) ) {
        write-host -fore cyan "Info: Downloading Ruby."
        ( New-Object System.Net.WebClient).DownloadFile("http://dl.bintray.com/oneclick/rubyinstaller/rubyinstaller-2.3.1.exe","c:\tmp\rubyinstaller-2.3.1.exe")
        if( !(test-path -ea 0  "c:\tmp\rubyinstaller-2.3.1.exe" ) ) { return write-error "Unable to download ruby installer" }
        write-host -fore darkcyan "      Running Ruby Installer."
        C:\tmp\rubyinstaller-2.3.1.exe /verysilent /dir=c:\ruby2.3.1 /tasks="assocfiles,modpath"
        while( (get-process -ea 0 rubyinstaller*) )  { write-host -NoNewline "." ; sleep 1 }
        ReloadPathFromRegistry
        if( !(get-command -ea 0 ruby.exe) ) { return write-error "No RUBY in PATH." }
        $ruby = (get-command -ea 0 ruby.exe).Source
        $null = netsh firewall add allowedprogram  "$ruby" "$ruby" ENABLE
    }
}

# install ruby-devkit
function InstallRubyDevKit {
    # ruby devkit
    if( ! (test-path -ea 0  "C:\ruby2.3.1\devkit")) {
        write-host -fore cyan "Info: Downloading Ruby Devkit."
        ( New-Object System.Net.WebClient).DownloadFile("http://dl.bintray.com/oneclick/rubyinstaller/DevKit-mingw64-32-4.7.2-20130224-1151-sfx.exe", "c:\tmp\DevKit-mingw64-32-4.7.2-20130224-1151-sfx.exe" )
        if( !(test-path -ea 0  "c:\tmp\DevKit-mingw64-32-4.7.2-20130224-1151-sfx.exe") ) { return write-error "Unable to download ruby devkit" }
        write-host -fore darkcyan "      Unpacking ruby devkit."
        & "$env:ProgramFiles\7-Zip\7z" x C:\tmp\DevKit-mingw64-32-4.7.2-20130224-1151-sfx.exe -oC:\ruby2.3.1\devkit
        pushd C:\ruby2.3.1\devkit\
        write-host -fore darkcyan "      Installing ruby devkit."
        ruby dk.rb init
        ruby dk.rb install

        write-host -fore darkcyan "      Installing missing ruby certificate roots."
    set-content -path "c:\ruby2.3.1\lib\ruby\2.3.0\rubygems\ssl_certs\fastly.pem" -value @"
-----BEGIN CERTIFICATE-----
MIIO5DCCDcygAwIBAgISESFY8xfYRUgn/tM1S/rCQFqRMA0GCSqGSIb3DQEBCwUA
MGYxCzAJBgNVBAYTAkJFMRkwFwYDVQQKExBHbG9iYWxTaWduIG52LXNhMTwwOgYD
VQQDEzNHbG9iYWxTaWduIE9yZ2FuaXphdGlvbiBWYWxpZGF0aW9uIENBIC0gU0hB
MjU2IC0gRzIwHhcNMTYwMzEwMTc1NDA5WhcNMTgwMzEzMTQwNDA2WjBsMQswCQYD
VQQGEwJVUzETMBEGA1UECAwKQ2FsaWZvcm5pYTEWMBQGA1UEBwwNU2FuIEZyYW5j
aXNjbzEVMBMGA1UECgwMRmFzdGx5LCBJbmMuMRkwFwYDVQQDDBBsLnNzbC5mYXN0
bHkubmV0MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEAy8dy9W+1kNgD
fZZaVm9OuB6aAcLysbODKUvHt7IvPEJjLZYMP5SLCB5+eo93Vb1Vl3I/lU+qdBIP
1Yzi9Oh8XB+DBA7YmgzyeuWvT07YBOJOfXrbQK9tx+dmcZQtU3oka0uqOUDeT8fE
qccufwxA0RoVPGEKCZjDr4NALIBL4ckKxWeibvwnX1rN1fqyMMiW36ML3A9gdSA5
0YIy7vh9CDvaSt/hBn/pUt2xkhhwtdi/zr6BrpjsMSgB/0qT03GukZ7fsxLI7Kwa
yspUlhLUbY99pKiXrf6NNuTIHt57IuD3a1TnBnHkOs9uQny31o3ShPOnxo4hB0xj
d+bbz2GsuQIDAQABo4ILhDCCC4AwDgYDVR0PAQH/BAQDAgWgMEkGA1UdIARCMEAw
PgYGZ4EMAQICMDQwMgYIKwYBBQUHAgEWJmh0dHBzOi8vd3d3Lmdsb2JhbHNpZ24u
Y29tL3JlcG9zaXRvcnkvMIIJyQYDVR0RBIIJwDCCCbyCEGwuc3NsLmZhc3RseS5u
ZXSCECouMXN0ZGlic2Nkbi5jb22CCiouYW1hbi5jb22CGCouYW5zd2Vyc2luZ2Vu
ZXNpcy5jby51a4IWKi5hbnN3ZXJzaW5nZW5lc2lzLm9yZ4IUKi5hcGkubGl2ZXN0
cmVhbS5jb22CEiouYXJrZW5jb3VudGVyLmNvbYIUKi5hdHRyaWJ1dGlvbi5yZXBv
cnSCDSouYmVzdGVnZy5jb22CEyouYnV5aXRkaXJlY3QuY28udWuCESouY29udGVu
dGJvZHkuY29tghQqLmNyZWF0aW9ubXVzZXVtLm9yZ4IbKi5jdXJhdGlvbnMuYmF6
YWFydm9pY2UuY29tgg4qLmRsc2FkYXB0LmNvbYIVKi5kb2xsYXJzaGF2ZWNsdWIu
Y29tghoqLmV4Y2l0ZW9ubGluZXNlcnZpY2VzLmNvbYIQKi5mYXN0bHlsYWJzLmNv
bYIPKi5maWxlcGlja2VyLmlvghIqLmZpbGVzdGFja2FwaS5jb22CESouZm9kLXNh
bmRib3guY29tghEqLmZvZC1zdGFnaW5nLmNvbYIKKi5mb2Q0LmNvbYIMKi5mdWxs
MzAuY29tgg4qLmZ1bmRwYWFzLmNvbYIPKi5mdW5rZXI1MzAuY29tghAqLmZ1bm55
b3JkaWUuY29tgg8qLmdhbWViYXR0ZS5jb22CCCouaGZhLmlvghEqLmphY2t0aHJl
YWRzLmNvbYIMKi5rbm5sYWIuY29tgg8qLmxlYWRlcnNpbi5jb22CDCoubGV0ZW1w
cy5jaIIPKi5sb290Y3JhdGUuY29tghUqLm1hcmxldHRlZnVuZGluZy5jb22CDyou
bXliZXN0ZWdnLmNvbYIJKi5uZmwuY29tggsqLnBhdGNoLmNvbYIMKi5wZWJibGUu
Y29tghAqLnBvdHRlcm1vcmUuY29tghAqLnByaW1lc3BvcnQuY29tghgqLnByb3Rl
Y3RlZC1jaGVja291dC5uZXSCCyoucmNoZXJ5LnNlgg4qLnJ1YnlnZW1zLm9yZ4IP
Ki5yd2xpdmVjbXMuY29tghcqLnNhZmFyaWJvb2tzb25saW5lLmNvbYISKi5zbWFy
dHNwYXJyb3cuY29tgg0qLnRhYy1jZG4ubmV0gg8qLnRoZXJlZHBpbi5jb22CDyou
dGhyaWxsaXN0LmNvbYIPKi50b3RhbHdpbmUuY29tgg8qLnRyYXZpcy1jaS5jb22C
DyoudHJhdmlzLWNpLm9yZ4ISKi50cmVhc3VyZWRhdGEuY29tggwqLnR1cm5lci5j
b22CDyoudW5pdGVkd2F5Lm9yZ4IOKi51bml2ZXJzZS5jb22CCSoudXJ4LmNvbYIK
Ki52ZXZvLmNvbYIbKi52aWRlb2NyZWF0b3IueWFob28tbmV0LmpwghYqLndob2xl
Zm9vZHNtYXJrZXQuY29tghMqLnliaS5pZGNmY2xvdWQubmV0ghEqLnlvbmRlcm11
c2ljLmNvbYIQYS4xc3RkaWJzY2RuLmNvbYINYWZyb3N0cmVhbS50doIPYXBpLmRv
bWFpbnIuY29tgg1hcGkubnltYWcuY29tghdhcHAuYmV0dGVyaW1wYWN0Y2RuLmNv
bYIaYXNzZXRzLmZsLm1hcmthdmlwLWNkbi5jb22CHGFzc2V0czAxLmN4LnN1cnZl
eW1vbmtleS5jb22CEmF0dHJpYnV0aW9uLnJlcG9ydIIYY2RuLmZpbGVzdGFja2Nv
bnRlbnQuY29tghZjZG4uaGlnaHRhaWxzcGFjZXMuY29tggxjZG4ua2V2eS5jb22C
C2RvbWFpbnIuY29tgh5lbWJlZC1wcmVwcm9kLnRpY2tldG1hc3Rlci5jb22CGGVt
YmVkLm9wdGltaXplcGxheWVyLmNvbYIWZW1iZWQudGlja2V0bWFzdGVyLmNvbYIO
ZmFzdGx5bGFicy5jb22CD2ZsLmVhdDI0Y2RuLmNvbYIKZnVsbDMwLmNvbYIMZnVu
ZHBhYXMuY29tgg1mdW5rZXI1MzAuY29tggtnZXRtb3ZpLmNvbYIZZ2l2aW5ndHVl
c2RheS5naXZlZ2FiLmNvbYIOaS51cHdvcnRoeS5jb22CGmltYWdlcy5mbC5tYXJr
YXZpcC1jZG4uY29tgg9qYWNrdGhyZWFkcy5jb22CFmpzaW4uYWRwbHVnY29tcGFu
eS5jb22CFWpzaW4uYmx1ZXBpeGVsYWRzLmNvbYIKa25ubGFiLmNvbYINbGVhZGVy
c2luLmNvbYINbG9vdGNyYXRlLmNvbYITbWVkaWEuYmFyZm9vdC5jby5ueoIVbWVk
aWEucmlnaHRtb3ZlLmNvLnVrgg1tZXJyeWphbmUuY29tgiBtaWdodHktZmxvd2Vy
cy00MjAubWVycnlqYW5lLmNvbYIgbmV4dGdlbi1hc3NldHMuZWRtdW5kcy1tZWRp
YS5jb22CCW55bWFnLmNvbYILKi5ueW1hZy5jb22CCXBhdGNoLmNvbYIKcGViYmxl
LmNvbYIPcGl4ZWwubnltYWcuY29tgg5wcmltZXNwb3J0LmNvbYIicHJvcXVlc3Qu
dGVjaC5zYWZhcmlib29rc29ubGluZS5kZYIMcnVieWdlbXMub3JnghVzYWZhcmli
b29rc29ubGluZS5jb22CEXNlYXJjaC5tYXB6ZW4uY29tghFzdGF0aWMudmVzZGlh
LmNvbYIOdGhlZ3VhcmRpYW4udHaCECoudGhlZ3VhcmRpYW4udHaCDXRocmlsbGlz
dC5jb22CDXRvdGFsd2luZS5jb22CB3VyeC5jb22CGXZpZGVvY3JlYXRvci55YWhv
by1uZXQuanCCGndlbGNvbWUtZGV2LmJhbmtzaW1wbGUuY29tghB3aWtpLXRlbXAu
Y2EuY29tgg13d3cuYmxpbnEuY29tggx3d3cuYnVscS5jb22CInd3dy5jcmlzdGlh
bm9yb25hbGRvZnJhZ3JhbmNlcy5jb22CGXd3dy5mcmVlZ2l2aW5ndHVlc2RheS5v
cmeCEXd3dy5mcmVlbG90dG8uY29tgg53d3cuaW9kaW5lLmNvbYIXd3d3LmxhcHRv
cHNkaXJlY3QuY28udWuCDnd3dy5sZXRlbXBzLmNoghF3d3cubWVycnlqYW5lLmNv
bYIkd3d3Lm1pZ2h0eS1mbG93ZXJzLTQyMC5tZXJyeWphbmUuY29tghh3d3cubWls
bHN0cmVhbWxvdDQ2LmluZm+CEnd3dy5wb3R0ZXJtb3JlLmNvbYITd3d3LnRyYWlu
b3JlZ29uLm9yZ4IQd3d3LnZzbGl2ZS5jby5uejAJBgNVHRMEAjAAMB0GA1UdJQQW
MBQGCCsGAQUFBwMBBggrBgEFBQcDAjBJBgNVHR8EQjBAMD6gPKA6hjhodHRwOi8v
Y3JsLmdsb2JhbHNpZ24uY29tL2dzL2dzb3JnYW5pemF0aW9udmFsc2hhMmcyLmNy
bDCBoAYIKwYBBQUHAQEEgZMwgZAwTQYIKwYBBQUHMAKGQWh0dHA6Ly9zZWN1cmUu
Z2xvYmFsc2lnbi5jb20vY2FjZXJ0L2dzb3JnYW5pemF0aW9udmFsc2hhMmcycjEu
Y3J0MD8GCCsGAQUFBzABhjNodHRwOi8vb2NzcDIuZ2xvYmFsc2lnbi5jb20vZ3Nv
cmdhbml6YXRpb252YWxzaGEyZzIwHQYDVR0OBBYEFExxRkNZ5ZAu1b3yysQe7R0J
p5v0MB8GA1UdIwQYMBaAFJbeYfG9HBYpUxzAzH07gwBA5hp8MA0GCSqGSIb3DQEB
CwUAA4IBAQAK0xY/KR6G9I6JJN1heilrcYEm71lrzxyAOrOq2YZV9l1L+qgSGxjV
vzvCNczZr76DD54+exBymDerBbwSI47JpSg3b5EzyiVvhz5r9rADYPBZBAkcTTUJ
std5fSbTMEKk+sB/DGdLr6v07kY+WRYbXMBuYNfRBVCoRXabzT5AMJEIYOudGFQC
1S/4tx3t1w7l4584Mr7uTAlDcMsNOkU4gs0Onghn6IAfuu1MN/0BYCuwO/qKdt5L
gN8rZB60W6VFOJGd1qJJv5erH/1j2nC8PBZQwl//IwW437uRNI5/ti3Fj/WR/0+T
dwT31o1uEbJZ0Mr5XmLQ/l8kal+xOiS0
-----END CERTIFICATE-----
"@

    set-content -path "c:\ruby2.3.1\lib\ruby\2.3.0\rubygems\ssl_certs\GeoTrustGlobalCA.pem" -value @"
-----BEGIN CERTIFICATE-----
MIIDVDCCAjygAwIBAgIDAjRWMA0GCSqGSIb3DQEBBQUAMEIxCzAJBgNVBAYTAlVT
MRYwFAYDVQQKEw1HZW9UcnVzdCBJbmMuMRswGQYDVQQDExJHZW9UcnVzdCBHbG9i
YWwgQ0EwHhcNMDIwNTIxMDQwMDAwWhcNMjIwNTIxMDQwMDAwWjBCMQswCQYDVQQG
EwJVUzEWMBQGA1UEChMNR2VvVHJ1c3QgSW5jLjEbMBkGA1UEAxMSR2VvVHJ1c3Qg
R2xvYmFsIENBMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA2swYYzD9
9BcjGlZ+W988bDjkcbd4kdS8odhM+KhDtgPpTSEHCIjaWC9mOSm9BXiLnTjoBbdq
fnGk5sRgprDvgOSJKA+eJdbtg/OtppHHmMlCGDUUna2YRpIuT8rxh0PBFpVXLVDv
iS2Aelet8u5fa9IAjbkU+BQVNdnARqN7csiRv8lVK83Qlz6cJmTM386DGXHKTubU
1XupGc1V3sjs0l44U+VcT4wt/lAjNvxm5suOpDkZALeVAjmRCw7+OC7RHQWa9k0+
bw8HHa8sHo9gOeL6NlMTOdReJivbPagUvTLrGAMoUgRx5aszPeE4uwc2hGKceeoW
MPRfwCvocWvk+QIDAQABo1MwUTAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBTA
ephojYn7qwVkDBF9qn1luMrMTjAfBgNVHSMEGDAWgBTAephojYn7qwVkDBF9qn1l
uMrMTjANBgkqhkiG9w0BAQUFAAOCAQEANeMpauUvXVSOKVCUn5kaFOSPeCpilKIn
Z57QzxpeR+nBsqTP3UEaBU6bS+5Kb1VSsyShNwrrZHYqLizz/Tt1kL/6cdjHPTfS
tQWVYrmm3ok9Nns4d0iXrKYgjy6myQzCsplFAMfOEVEiIuCl6rYVSAlk6l5PdPcF
PseKUgzbFbS9bZvlxrFUaKnjaZC2mqUPuLk/IH2uSrW4nOQdtqvmlKXBx4Ot2/Un
hw4EbNX/3aBd7YdStysVAq45pmp06drE57xNNB6pXE0zX5IJL4hmXXeXxx12E6nV
5fEWCRE11azbJHFwLJhWC9kXtNHjUStedejV0NxPNO3CBWaAocvmMw==
-----END CERTIFICATE-----
"@

    set-content -path "c:\ruby2.3.1\lib\ruby\2.3.0\rubygems\ssl_certs\GlobalSignRoot.pem" -value @"
-----BEGIN CERTIFICATE-----
MIIDdTCCAl2gAwIBAgILBAAAAAABFUtaw5QwDQYJKoZIhvcNAQEFBQAwVzELMAkGA1UEBhMCQkUx
GTAXBgNVBAoTEEdsb2JhbFNpZ24gbnYtc2ExEDAOBgNVBAsTB1Jvb3QgQ0ExGzAZBgNVBAMTEkds
b2JhbFNpZ24gUm9vdCBDQTAeFw05ODA5MDExMjAwMDBaFw0yODAxMjgxMjAwMDBaMFcxCzAJBgNV
BAYTAkJFMRkwFwYDVQQKExBHbG9iYWxTaWduIG52LXNhMRAwDgYDVQQLEwdSb290IENBMRswGQYD
VQQDExJHbG9iYWxTaWduIFJvb3QgQ0EwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQDa
DuaZjc6j40+Kfvvxi4Mla+pIH/EqsLmVEQS98GPR4mdmzxzdzxtIK+6NiY6arymAZavpxy0Sy6sc
THAHoT0KMM0VjU/43dSMUBUc71DuxC73/OlS8pF94G3VNTCOXkNz8kHp1Wrjsok6Vjk4bwY8iGlb
Kk3Fp1S4bInMm/k8yuX9ifUSPJJ4ltbcdG6TRGHRjcdGsnUOhugZitVtbNV4FpWi6cgKOOvyJBNP
c1STE4U6G7weNLWLBYy5d4ux2x8gkasJU26Qzns3dLlwR5EiUWMWea6xrkEmCMgZK9FGqkjWZCrX
gzT/LCrBbBlDSgeF59N89iFo7+ryUp9/k5DPAgMBAAGjQjBAMA4GA1UdDwEB/wQEAwIBBjAPBgNV
HRMBAf8EBTADAQH/MB0GA1UdDgQWBBRge2YaRQ2XyolQL30EzTSo//z9SzANBgkqhkiG9w0BAQUF
AAOCAQEA1nPnfE920I2/7LqivjTFKDK1fPxsnCwrvQmeU79rXqoRSLblCKOzyj1hTdNGCbM+w6Dj
Y1Ub8rrvrTnhQ7k4o+YviiY776BQVvnGCv04zcQLcFGUl5gE38NflNUVyRRBnMRddWQVDf9VMOyG
j/8N7yy5Y0b2qvzfvGn9LhJIZJrglfCm7ymPAbEVtQwdpf5pLGkkeB6zpxxxYu7KyJesF12KwvhH
hm4qxFYxldBniYUr+WymXUadDKqC5JlR3XC321Y9YeRq4VzW9v493kHMB65jUr9TU/Qr6cf9tveC
X4XSQRjbgbMEHMUfpIBvFSDJ3gyICh3WZlXi/EjJKSZp4A==
-----END CERTIFICATE-----
"@

        write-host -fore darkcyan "      Testing ruby devkit."
        gem install json --platform=ruby
        $answer =  ruby -rubygems -e "require 'json'; puts JSON.load('[42]').inspect"
        if( $answer -ne "[42]") {
            return write-error "Ruby devkit/gems not working?"
        }

        # perform ruby updates and get gems
        gem update --system
        gem install rake
        gem install bundler
        gem install bundle
        popd
    }
}

# install python 2.7 and 3.5
function InstallPython {
    if( !(get-command -ea 0 python.exe) ) { 
        write-host -fore cyan "Info: Downloading Python 2.7 and 3.5"
        ( New-Object System.Net.WebClient).DownloadFile("https://www.python.org/ftp/python/2.7.12/python-2.7.12.amd64.msi","c:\tmp\python-2.7.12.amd64.msi")
        ( New-Object System.Net.WebClient).DownloadFile("https://www.python.org/ftp/python/3.5.2/python-3.5.2-amd64.exe","c:\tmp\python-3.5.2-amd64.exe" )

        if( !(test-path -ea 0  "c:\tmp\python-2.7.12.amd64.msi") ) { return write-error "Unable to download Python 2.7" }
        if( !(test-path -ea 0  "c:\tmp\python-3.5.2-amd64.exe") ) { return write-error "Unable to download Python 3.5" }
        write-host -fore darkcyan "      Installing Python 2.7."
        Start-Process -wait -FilePath msiexec -ArgumentList  "/i", "C:\tmp\python-2.7.12.amd64.msi", "TARGETDIR=c:\python27", "ALLUSERS=1", "ADDLOCAL=All", "/passive"
        write-host -fore darkcyan "      Installing Python 3.5."
        C:\tmp\python-3.5.2-amd64.exe /quiet InstallAllUsers=1 PrependPath=1
        while( (get-process -ea 0 python*) )  { write-host -NoNewline "." ; sleep 1 }
        ReloadPathFromRegistry
        if( !(get-command -ea 0 python.exe) ) { return write-error "No PYTHON in PATH." }
    }
}

#install Tox
function InstallTox {
    if( !(get-command -ea 0 tox.exe) ) { 
        write-host -fore cyan "Info: Installing Tox"
        pip install tox
        if( !(get-command -ea 0 tox.exe) ) { return write-error "No TOX  in PATH." }
    }
}

# install maven
function InstallMaven {
    if( !(get-command -ea 0 mvn.cmd) ) { 
        write-host -fore cyan "Info: Downloading Maven"
        (New-Object System.Net.WebClient).DownloadFile("http://www-eu.apache.org/dist/maven/maven-3/3.5.2/binaries/apache-maven-3.5.2-bin.zip", "c:\tmp\apache-maven-3.5.2-bin.zip" )
        if( !(test-path -ea 0  "c:\tmp\apache-maven-3.5.2-bin.zip") ) { return write-error "Unable to download Maven" }
        write-host -fore darkcyan "      Unpacking Maven."
        Expand-Archive C:\tmp\apache-maven-3.5.2-bin.zip -DestinationPath c:\
        write-host -fore darkcyan "      Adding mvn to system PATH."
        $p = ([System.Environment]::GetEnvironmentVariable( "path", 'Machine'))
        $p = "$p;C:\apache-maven-3.5.2\bin"
        ([System.Environment]::SetEnvironmentVariable( "path", $p,  'Machine'))
        ReloadPathFromRegistry
        if( !(get-command -ea 0 mvn.cmd) ) { return write-error "No Maven in PATH." }
    }
}

# install gradle
function InstallGradle {
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
        ([System.Environment]::SetEnvironmentVariable( 'GRADLE_USER_HOME', "D:\gradle",  "Machine"))
        ReloadPathFromRegistry
        if( !(get-command -ea 0 mvn.cmd) ) { return write-error "No Maven in PATH." }
    }
}

#install go-lang
function InstallGoLang {
    if( !(get-command -ea 0 go.exe) ) { 
        write-host -fore cyan "Info: Downloading Go"
        invoke-webrequest "https://storage.googleapis.com/golang/go1.8.3.windows-amd64.msi" -outfile  "c:\tmp\go1.8.3.windows-amd64.msi" 
        if( !(test-path -ea 0  "c:\tmp\go1.8.3.windows-amd64.msi" ) ) { return write-error "Unable to download Go" }
        write-host -fore darkcyan "      Installing Go."
        Start-Process -wait -FilePath msiexec -ArgumentList  "/i", "C:\tmp\go1.8.3.windows-amd64.msi", "/passive"
        ReloadPathFromRegistry
        if( !(get-command -ea 0 go.exe) ) { return write-error "No GO in PATH." }
    }
}

# install glide
function InstallGlide {
    if( !(get-command -ea 0 glide.exe) ) {
        write-host -fore cyan "Info: Downloading Glide"
        invoke-webrequest "https://github.com/Masterminds/glide/releases/download/v0.11.1/glide-v0.11.1-windows-amd64.zip" -outfile  "c:\tmp\glide-v0.11.1-windows-amd64.zip"
        if( !(test-path -ea 0  "c:\tmp\glide-v0.11.1-windows-amd64.zip" ) ) { return write-error "Unable to download Glide" }
        write-host -fore darkcyan "      Unpacking Glide."
        Expand-Archive C:\tmp\glide-v0.11.1-windows-amd64.zip -DestinationPath c:\glide
        write-host -fore darkcyan "      adding glide to system PATH."
        $p = ([System.Environment]::GetEnvironmentVariable( "path", 'Machine'))
        $p = "$p;C:\glide\windows-amd64"
        ([System.Environment]::SetEnvironmentVariable( "path", $p,  'Machine'))
        ReloadPathFromRegistry
        if( !(get-command -ea 0 glide.exe) ) { return write-error "No glide in PATH." }
    }
}

# install git
function InstallGit {
    if( !(get-command -ea 0 git) ) { 
        write-host -fore cyan "Info: Downloading GIT"
        invoke-webrequest "https://github.com/git-for-windows/git/releases/download/v2.11.1.windows.1/Git-2.11.1-64-bit.exe" -outfile  "c:\tmp\gitinstall.exe"
        if( !(test-path -ea 0  "c:\tmp\gitinstall.exe" ) ) { return write-error "Unable to download Git" }
        write-host -fore cyan "Info: Installing GIT"
        Start-Process -wait -FilePath c:\tmp\gitinstall.exe -ArgumentList  "/silent"
        
        # it also needs to be in x86. 
        write-host -fore darkcyan "      Putting git in x86 program files too."
        robocopy /mir "$env:ProgramFiles\git" "${env:ProgramFiles(x86)}\git"
        
        ReloadPathFromRegistry
        if( !(get-command -ea 0 git) ) { 
            write-host -fore darkcyan "      adding git to system PATH."
            $p = ([System.Environment]::GetEnvironmentVariable( "path", 'Machine'))
            $p = "$p;$env:ProgramFiles\git\bin"
            ([System.Environment]::SetEnvironmentVariable( "path", $p,  'Machine'))
        }
        ReloadPathFromRegistry
        if( !(get-command -ea 0 git.exe) ) { return write-error "No git in PATH." }
    }
}

# Fixing firewall rules
function FixFirewallRules {
    write-host -fore cyan "Info: Fixing firewall rules for languages/tools"
    Get-NetFirewallRule -DisplayName "Remote Desktop*" | Set-NetFirewallRule -enabled true
    @("java", "javaw", "javaws", "node", "ruby", "go", "glide" ) |% { $app = ((get-command -ea 0 $_).source); $null= netsh firewall add allowedprogram  "$app" "$app" ENABLE }    
}

# visual studio code
function InstallVSCode {
    if( !(get-command -ea 0 code) ) {
        write-host -fore cyan "Info: Downloading Visual Studio Code"
        invoke-webrequest "https://go.microsoft.com/fwlink/?LinkID=623230" -outfile  "c:\tmp\vs_code.exe" 
        if( !(test-path -ea 0 "c:\tmp\vs_code.exe" ) ) { return write-error "Unable to download VS code" }
        write-host -fore darkcyan "      Installing VS Code"
        C:\tmp\vs_code.exe /silent /norestart
        while( get-process vs_*  ) { write-host -NoNewline "." ; sleep 1 }
        ReloadPathFromRegistry
        if( !(get-command -ea 0 code) ) { return write-error "No VS Code in PATH." }
    }
}

# install wix
function InstallWix {
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
    }
}

# check for a good version of dotnet-cli
function InstallDotnetCli {
    $good = $false

    if( (get-command -ea 0 dotnet) ) {
        $v = (dotnet --version ) -replace '.*-00',''
        $good = $v -gt 4811
    }
        
    if( -not $good ) {
        write-host -fore cyan "Info: Downloading dotnet-cli tools"
        invoke-webrequest "https://dotnetcli.blob.core.windows.net/dotnet/Sdk/rel-1.0.0/dotnet-dev-win-x64.latest.exe" -outfile "c:\tmp\dotnet-cli.exe"
        if( !(test-path -ea 0 "c:\tmp\dotnet-cli.exe" ) ) { return write-error "Unable to download dotnet-cli" }
        write-host -fore darkcyan "      Installing Dotnet-cli"
        C:\tmp\dotnet-cli.exe /install /passive /noreboot SKIP_VSU_CHECK=1
        while( get-process dotnet-*  ) { write-host -NoNewline "." ; sleep 1 }
        ReloadPathFromRegistry
        if( !(get-command -ea 0 dotnet) ) { return write-error "No dotnet.exe in PATH." }
    }
}

# install android-studio
function InstallAndroidStudio {
    if( !(get-command -ea 0 studio64.exe) ) {

        write-host -fore cyan "Info: Downloading Android Studio"
        ( New-Object System.Net.WebClient).DownloadFile("https://dl.google.com/dl/android/studio/install/3.0.1.0/android-studio-ide-171.4443003-windows.exe","c:\tmp\android-studio-ide-171.4443003-windows.exe")
        ( New-Object System.Net.WebClient).DownloadFile("https://gist.githubusercontent.com/VSaliy/d8d923759f694b1681260ce937e65487/raw/9440f8bc3ac550ff9ee03a4607423bcb39705b10/silent.config","c:\tmp\silent.config")
        if( !(test-path -ea 0  "c:\tmp\android-studio-ide-171.4443003-windows.exe" ) ) { return write-error "Unable to download Android Studio" }
        if( !(test-path -ea 0  "c:\tmp\silent.config" ) ) { return write-error "Unable to download Android Studio" }

        write-host -fore cyan "Info: Installing Android Studio"
        C:\tmp\android-studio-ide-171.4443003-windows.exe /S /CONFIG=c:\tmp\silent.config /D=d:\dev\ide\android-studio-ide-171.4443003
        while( (get-process -ea 0 ideaIU*) )  { write-host -NoNewline "|" ; sleep 1 }
        ReloadPathFromRegistry

        write-host -fore darkcyan "      Adding Android Studio to system PATH."
        $p = ([System.Environment]::GetEnvironmentVariable( "path", 'Machine'))
        $p = "$p;D:\dev\ide\android-studio-ide-171.4443003\bin;"
        ([System.Environment]::SetEnvironmentVariable( "path", $p,  'Machine'))
        ReloadPathFromRegistry
        ([System.Environment]::SetEnvironmentVariable( 'ANDROID_HOME', "d:\dev\ide\android-studio-ide-171.4443003", "Machine"))
        ReloadPathFromRegistry
        if( !(get-command -ea 0 idea64.exe) ) { return write-error "No idea in PATH." }
    }
}

# install Google Chrome
function InstallGoogleChrome {
    if( !(get-command -ea 0 chrome.exe) ) {

        write-host -fore cyan "Info: Downloading Google Crome"
        ( New-Object System.Net.WebClient).DownloadFile("http://dl.google.com/chrome/install/375.126/chrome_installer.exe","c:\tmp\chrome_installer.exe")
        if( !(test-path -ea 0  "c:\tmp\chrome_installer.exe" ) ) { return write-error "Unable to download Google Chrome" }

        write-host -fore cyan "Info: Installing Google Chrome"
        C:\tmp\chrome_installer.exe /silent /install
        sleep 15
        while( (get-process -ea 0 *chrome*) )  { write-host -NoNewline "|" ; sleep 1 }
        ReloadPathFromRegistry

        write-host -fore darkcyan "      Adding Google Chrome to system PATH."
        $p = ([System.Environment]::GetEnvironmentVariable( "path", 'Machine'))
        $p = "$p;C:\Program Files (x86)\Google\Chrome\Application\;"
        ([System.Environment]::SetEnvironmentVariable( "path", $p,  'Machine'))
        ReloadPathFromRegistry
        if( !(get-command -ea 0 chrome.exe) ) { return write-error "No Google Chrome in PATH." }
    }
}

function DownloadFileFromOneDrive{
    param (
            $DownloadURL = "$( throw 'DownloadURL is a mandatory Parameter' )",
      $PSCredentials = "$( throw 'credentials is a mandatory Parameter' )",
      $DownloadPath  = "$( throw 'DownloadPath is a mandatory Parameter' )"
       )
    process{
     $DownloadURI = New-Object System.Uri($DownloadURL);
     $SharepointHost = "https://" + $DownloadURI.Host
     $soCredentials =  New-Object Microsoft.SharePoint.Client.SharePointOnlineCredentials($PSCredentials.UserName.ToString(),$PSCredentials.password) 
     $clientContext = New-Object Microsoft.SharePoint.Client.ClientContext($SharepointHost)
     $clientContext.Credentials = $soCredentials;
     $destFile = $DownloadPath + [System.IO.Path]::GetFileName($DownloadURI.LocalPath)
     $fileInfo = [Microsoft.SharePoint.Client.File]::OpenBinaryDirect($clientContext, $DownloadURI.LocalPath);
     $fstream = New-Object System.IO.FileStream($destFile, [System.IO.FileMode]::Create);
     $fileInfo.Stream.CopyTo($fstream)
     $fstream.Flush()
     $fstream.Close()
     Write-Host ("File downloaded to " + ($destFile))
    }
   }

# install licence server
function InstallLicenceServer {
    if( !(get-command -ea 0 IntelliJIDEALicenseServer_windows_amd64.exe) ) {

        write-host -fore cyan "Info: Downloading LicenceServer"
        # invoke-webrequest "https://github.com/VSaliy/tools/raw/dev/Setting%20up%20a%20development%20environment/LS.zip" -outfile  "c:\tmp\LicenceServer.zip"
        ( New-Object System.Net.WebClient).DownloadFile("https://github.com/VSaliy/tools/raw/dev/Setting%20up%20a%20development%20environment/LS.zip", "c:\tmp\LicenceServer.zip")
        if( !(test-path -ea 0  "c:\tmp\LicenceServer.zip" ) ) { return write-error "Unable to download Licence Server" }

        write-host -fore cyan "Info: Unpacking Licence Server"
        Expand-Archive c:\tmp\LicenceServer.zip -DestinationPath D:\dev\ide\LicenceServer
        write-host -fore darkcyan "      adding Licence Server to system PATH."
         $p = ([System.Environment]::GetEnvironmentVariable( "path", 'Machine'))
         $p = "$p;D:\dev\ide\LicenceServer"
        ([System.Environment]::SetEnvironmentVariable( "path", $p,  'Machine'))
        ReloadPathFromRegistry
        if( !(get-command -ea 0 IntelliJIDEALicenseServer_windows_amd64.exe) ) { return write-error "No Licence Server in PATH." }
    }
}

#install Everything
function InstallEverything {
    if( !(get-command -ea 0 Everything.exe) ) {
        write-host -fore cyan "Info: Downloading Everything"
        invoke-webrequest "https://www.voidtools.com/Everything-1.4.1.877.x86.zip" -outfile  "c:\tmp\Everything.zip"
        if( !(test-path -ea 0  "c:\tmp\Everything.zip" ) ) { return write-error "Unable to download Everything" }
        write-host -fore darkcyan "      Unpacking Everything."
        Expand-Archive C:\tmp\Everything.zip -DestinationPath D:\usr\app\Everything
        write-host -fore darkcyan "      adding Everything to system PATH."
        $p = ([System.Environment]::GetEnvironmentVariable( "path", 'Machine'))
        $p = "$p;D:\usr\app\Everything"
        ([System.Environment]::SetEnvironmentVariable( "path", $p,  'Machine'))
        ReloadPathFromRegistry
        if( !(get-command -ea 0 Everything.exe) ) { return write-error "No Everything in PATH." }
    }
}


# # install lazarus
# function InstallLazarus {
#     if( !(get-command -ea 0 lazarus.exe) ) {
#         write-host -fore cyan "Info: Downloading Lazarus"
#         ( New-Object System.Net.WebClient).DownloadFile("https://netcologne.dl.sourceforge.net/project/lazarus/Lazarus%20Windows%2032%20bits/Lazarus%201.8.0/lazarus-1.8.0-fpc-3.0.4-win32.exe","c:\tmp\lazarus-1.8.0-fpc-3.0.4-win32.exe")
#     }
# }

VerifyUserElevation
# InstallEverything
#MakeTempDirectory
# InstallLicenceServer
# $cred = Get-Credential
# DownloadFileFromOneDrive -DownloadURL $args[0] -PSCredentials $cred -DownloadPath 'c:\tmp\'
InstallGoogleChrome
#InstallChocolatey           # Chocolatey
#InstallNuGet                # NuGet
#InstallJDK8                 # JDK 8
#InstallIntelliJIDEA         # IntelliJ IDEA
#InstallAndroidStudio         # android-studio
#InstallNodeJSviaNVM         # NodeJS via NVM
#InstallGulp                 # Gulp
#Install7zip                 # 7zip
#InstallRuby                 # Ruby
#InstallRubyDevKit           # Ruby-DevKit
#InstallPython               # Python 2.7 and 3.5
#InstallTox                  # Tox
#InstallMaven                # Maven 3.5.2
#InstallGradle               # Gradle
#InstallGoLang               # GoLang
#InstallGlide                # Glide
#InstallGit                  # Git
#FixFirewallRules
#InstallVSCode               # Visual Studio Code
#InstallWix                  # Wix
#InstallDotnetCli            # Dotnet-Cli tools
#InstallLazarus              # Lazarus aka Delphi


#https://notepad-plus-plus.org/repository/7.x/7.5.3/npp.7.5.3.Installer.x64.exe
#
#http://www.farmanager.com/files/Far30b5000.x64.20170807.msi
#https://github.com/Maximus5/ConEmu/releases/download/v17.12.05/ConEmuSetup.171205.exe
#https://dl.google.com/dl/cloudsdk/channels/rapid/GoogleCloudSDKInstaller.exe
#https://download.bitcomet.com/achive/BitComet_1.47.zip
#https://github-production-release-asset-2e65be.s3.amazonaws.com/56899284/eb5601ea-d3f6-11e7-965d-097467585325?X-Amz-Algorithm=AWS4-HMAC-SHA256&X-Amz-Credential=AKIAIWNJYAX4CSVEH53A%2F20171207%2Fus-east-1%2Fs3%2Faws4_request&X-Amz-Date=20171207T213729Z&X-Amz-Expires=300&X-Amz-Signature=eca73311bc1b4e8bdf293cd305e3828dd94abb848466067d20e024f9c27c53ac&X-Amz-SignedHeaders=host&actor_id=209736&response-content-disposition=attachment%3B%20filename%3DInsomnia.Setup.5.12.3.exe&response-content-type=application%2Foctet-stream
#https://dl.pstmn.io/download/latest/win64
#https://vorboss.dl.sourceforge.net/project/xming/Xming/6.9.0.31/Xming-6-9-0-31-setup.exe
#https://download.fosshub.com/Protected/expiretime=1510363093;badurl=aHR0cDovL3d3dy5mb3NzaHViLmNvbS9TcGFjZVNuaWZmZXIuaHRtbA==/898d73fae7a045739f89c2e170ef47d13402cd98801887f4fd4734aea4d94e4f/SpaceSniffer/spacesniffer_1_3_0_2.zip
#http://downloads.typesafe.com/scalaide-pack/4.7.0-vfinal-oxygen-212-20170929/scala-SDK-4.7.0-vfinal-2.12-win32.win32.x86_64.zip
#https://downloads.slack-edge.com/releases_x64/SlackSetup.exe
#https://download.mobatek.net/10420170816103227/MobaXterm_Installer_v10.4.zip
#https://dl.tvcdn.de/download/TeamViewer_Setup.exe
#https://www.syntevo.com/static/smart/download/smartgit/smartgit-win32-setup-jre-17_1_0.zip#http://ftp-stud.fht-esslingen.de/pub/Mirrors/eclipse/oomph/epp/oxygen/R/eclipse-inst-win64.exe
#https://repo.spring.io/release/org/springframework/boot/spring-boot-cli/1.5.7.RELEASE/spring-boot-cli-1.5.7.RELEASE-bin.zip
#
#http://www.eclipse.org/downloads/download.php?file=/technology/epp/downloads/release/oxygen/1a/eclipse-java-oxygen-1a-win32-x86_64.zip
#http://www.eclipse.org/downloads/download.php?file=/technology/epp/downloads/release/oxygen/1a/eclipse-jee-oxygen-1a-win32-x86_64.zip
#https://releases.hashicorp.com/vagrant/2.0.1/vagrant_2.0.1_x86_64.msi?_ga=2.149607350.1437125475.1513402085-809140183.1509223383

#http://www.graphviz.org/pub/graphviz/stable/windows/graphviz-2.38.msi
#https://release.gitkraken.com/win64/GitKrakenSetup.exe
#https://s3-us-west-2.amazonaws.com/cycligent-downloads/CycligentGitTool/installers/win32/x64/CycligentGitToolSetup-0.5.2-win32-x64.exe
#https://downloads-guests.open.collab.net/files/documents/61/13440/GitEye-2.0.0-windows.x86_64.zip
#https://aurees.com/download/AureesSetup-x64.exe
#https://codeload.github.com/FabriceSalvaire/CodeReview/zip/V0.3.1
##https://releases.hashicorp.com/packer/1.1.1/packer_1.1.1_linux_amd64.zip?_ga=2.25252477.1317664923.1509584822-1184512955.1509584822
#https://codeload.github.com/aws/aws-sdk-java/zip/1.11.222

#https://puppet-pdk.s3.amazonaws.com/pdk/1.2.1.0/repos/windows/pdk-1.2.1.0-x64.msi
#https://s3.amazonaws.com/pe-client-tools-releases/2017.3/pe-client-tools/17.3.2/repos/windows/pe-client-tools-17.3.2-x64.msi
#https://s3.amazonaws.com/puppet-agents/2017.3/puppet-agent/5.3.3/repos/windows/puppet-agent-5.3.3-x64.msi

write-host -fore green  "You should restart this computer now. (ie, type 'RESTART-COMPUTER' )"
return