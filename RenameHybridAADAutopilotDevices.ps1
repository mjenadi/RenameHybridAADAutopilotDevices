<#PSScriptInfo
.VERSION 1.0
.AUTHOR Marouane Jenadi
.COMPANYNAME SCC
.COPYRIGHT
.TAGS
.LICENSEURI
.PROJECTURI
.ICONURI
.EXTERNALMODULEDEPENDENCIES 
.REQUIREDSCRIPTS
.EXTERNALSCRIPTDEPENDENCIES
.RELEASENOTES
Version 1.0: Initial version.
.PRIVATEDATA
#>
<# 
.DESCRIPTION 
 Rename Hybrid AAD Autopilot Devices
#> 

Param()

# If we are running as a 32-bit process on an x64 system, re-launch as a 64-bit process
if ("$env:PROCESSOR_ARCHITEW6432" -ne "ARM64") {
    if (Test-Path "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe")
    {
        & "$($env:WINDIR)\SysNative\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy bypass -File "$PSCommandPath"
        Exit $lastexitcode
    }
}

# Create a tag file just so Intune knows this was installed
if (-not (Test-Path "$($env:ProgramData)\Microsoft\RenameComputer")) {
        Mkdir "$($env:ProgramData)\Microsoft\RenameComputer"
}
Set-Content -Path "$($env:ProgramData)\Microsoft\RenameComputer\RenameComputer.ps1.tag" -Value "Installed"

# Initialization
$dest = "C:\Windows\Logs\Software"
if (-not (Test-Path $dest)) {
    mkdir $dest
}
Start-Transcript "$dest\RenameComputer.log" -Append

# Make sure we are already domain-joined
$goodToGo = $true
$details = Get-ComputerInfo
if (-not $details.CsPartOfDomain) {
    Write-Host "Not part of a domain."
    $goodToGo = $false
}

# Make sure we have connectivity
$dcInfo = [ADSI]"LDAP://RootDSE"
if ($dcInfo.dnsHostName -eq $null) {
    Write-Host "No connectivity to the domain."
    $goodToGo = $false
}

if ($goodToGo) {
    DO {
        # Get the new computer name
        $NewName = "MJLAB"
        $Random =  "{0:D4}" -f ( Get-Random -Minimum 0000 -Maximum 9999 )
        $NewComputerName = $NewName + $Random 

        # Check the new computer name
        $test = (([adsisearcher]"(&(objectCategory=Computer)(name=$NewComputerName))").findall()).properties
        If($test){
            Write-Host "$NewComputerName already exists."
            $Exists = $True
        }
        else {
            Write-host "Verified $NewComputerName is not in use"
            $Exists = $False
        }       
    }
    While ($Exists -eq $True)

    # Set the computer name
    Write-Host "Renaming computer to $NewComputerName"
    Rename-Computer -NewName $NewComputerName

    # Remove the scheduled task
    Disable-ScheduledTask -TaskName "RenameComputer" -ErrorAction Ignore
    Unregister-ScheduledTask -TaskName "RenameComputer" -Confirm:$false -ErrorAction Ignore
    Write-Host "Scheduled task unregistered."

    # Make sure we reboot if still in ESP/OOBE by reporting a 1641 return code (hard reboot)
    if ($details.CsUserName -match "defaultUser") {
        Write-Host "Exiting during ESP/OOBE with return code 1641"
        Stop-Transcript
        Exit 1641
    }
    else {
        Write-Host "Initiating a restart in 10 minutes"
        & shutdown.exe /g /t 600 /f /c "Redemarrage de votre PC pour un changement de Nom. Enregistrez votre travail"
        Stop-Transcript
        Exit 0
    }
}
else {
    # Check to see if already scheduled
    $existingTask = Get-ScheduledTask -TaskName "RenameComputer" -ErrorAction SilentlyContinue
    if ($existingTask -ne $null) {
        Write-Host "Scheduled task already exists."
        Stop-Transcript
        Exit 0
    }

    # Copy myself to a safe place if not already there
    if (-not (Test-Path "$dest\RenameComputer.ps1")) {
        Copy-Item $PSCommandPath "$dest\RenameComputer.ps1"
    }

    # Create the scheduled task action
    $action = New-ScheduledTaskAction -Execute "Powershell.exe" -Argument "-NoProfile -ExecutionPolicy bypass -WindowStyle Hidden -File $dest\RenameComputer.ps1"

    # Create the scheduled task trigger
    $timespan = New-Timespan -minutes 5
    $triggers = @()
    $triggers += New-ScheduledTaskTrigger -Daily -At 9am
    $triggers += New-ScheduledTaskTrigger -AtLogOn -RandomDelay $timespan
    $triggers += New-ScheduledTaskTrigger -AtStartup -RandomDelay $timespan
    
    # Register the scheduled task
    Register-ScheduledTask -User SYSTEM -Action $action -Trigger $triggers -TaskName "RenameComputer" -Description "RenameComputer" -Force
    Write-Host "Scheduled task created."
}

Stop-Transcript
 