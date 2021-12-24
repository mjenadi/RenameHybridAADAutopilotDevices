# RenameHybridAADAutopilotDevices
Here is a script inspired by Michael Niehaus script Rename Computer for hybrid devices : https://github.com/mtniehaus/RenameComputer  without any needs of azure functions, everything is in the script

the only difference is in this part of script : 

# Get the new computer name
    $newName = Invoke-RestMethod -Method GET -Uri "https://generatename.azurewebsites.net/api/HttpTrigger1?prefix=AD-"
    
Replaced by this :

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
    
    To set up the RenameComputer app in Intune go to : https://github.com/mtniehaus/RenameComputer or https://oofhours.com/2020/05/19/renaming-autopilot-deployed-hybrid-azure-ad-join-devices/
