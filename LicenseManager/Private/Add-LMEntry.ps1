<#
    .Synopsis

        This script add an entry to the JSON concurrency file.

    .Description

        This script add an entry to the JSON concurrency file without determining if it should.
        The only logic that occurs is whether or not there will be a duplicate entry. If so, it prevents that.
    
    .Parameter LicenseManager
        
        An object, as converted from `Watch-LMEvent`'s LicenseManager Parameter.
    
    .Parameter ProcessName

        The name of the Process, with the extension.

    .Parameter ProcesssId

        The Process ID of the currently running Process.

    .Parameter ProcesssUserName

        The UserName of the user running the aforementioned Process ID.
#>
function Add-LMEntry {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true)]
        [array]
        $LicenseManager,

        [Parameter(Mandatory = $true)]
        [IO.FileInfo]
        $ProcessName,

        [Parameter(Mandatory = $true)]
        [int32]
        $ProcessId,

        [Parameter()]
        [string]
        $ProcessUserName
    )
    Write-Verbose "[Add-LMEntry] Bound Parameters: $($MyInvocation.BoundParameters | Out-String)"
    Write-Verbose "[Add-LMEntry] Unbound Parameters: $($MyInvocation.UnboundParameters | Out-String)"
    
    [IO.FileInfo] $jsonFilePath = "$($LicenseManager.DirectoryPath)\${ProcessName}.json"
    Write-Verbose "[Add-LMEntry] JSON File: ${jsonFilePath}"
    
    $jsonFileExists = Test-Path $jsonFilePath
    Write-Verbose "[Add-LMEntry] JSON file exists: ${jsonFileExists}"
    Write-Verbose "[Add-LMEntry] JSON file size: $($jsonFilePath.Length)"
    
    if (-not $jsonFileExists) {
        Write-Verbose "[Add-LMEntry] Creating Empty JSON file."
        New-Item -ItemType File -Path $jsonFilePath -Force

        $jsonFileExists = Test-Path $jsonFilePath
        Write-Verbose "[Add-LMEntry] JSON file exists: ${jsonFileExists}"
    }

    $jsonChangeMade = $false
    if ($jsonFilePath.Length -gt 0 -and -not ([string]::IsNullOrEmpty((Get-Content $jsonFilePath).Trim()))) {
        Write-Verbose "[Add-LMEntry] JSON file is NOT empty."
        
        $jsonInfo = Get-Content -LiteralPath $jsonFilePath | Out-String | ConvertFrom-Json
        Write-Verbose "[Add-LMEntry] JSON: $($jsonInfo | ConvertTo-Json)"
        
        Write-Verbose "[Add-LMEntry] Updating JSON ..."
        $newJsonInfo = $jsonInfo | Foreach-Object {
            $currentJsonInfo = $_
            if (($currentJsonInfo.ComputerName -eq $env:COMPUTERNAME) -and ($currentJsonInfo.UserName -eq $ProcessUserName)) {
                Write-Verbose "[Add-LMEntry] Relevant JSON Info Found: $($currenJsonInfo | Out-String)"
                if ($currentJsonInfo.ProcessId -contains $ProcessId) {
                    Write-Verbose "[Add-LMEntry] Relevant JSON contains the Process Id (${ProcessId}) we want to Add!"
                } else {
                    Write-Verbose "[Add-LMEntry] Relevant JSON needs the Process Id (${ProcessId}) added."
                    $currentJsonInfo.ProcessId = $currentJsonInfo.ProcessId + $ProcessId
                }
                    
                Write-Verbose "[Add-LMEntry] Update the TimeStamp."
                $currentJsonInfo.TimeStamp = (Get-Date -Format 'O')

                Write-Verbose "[Add-LMEntry] Relevant JSON Info Updated: $($currentJsonInfo | Out-String)"
                Write-Output $currentJsonInfo
                $jsonChangeMade = $true
            } else {
                Write-Output $currentJsonInfo
            }
        }

        if (-not $jsonChangeMade) {
            Write-Verbose "[Add-LMEntry] JSON doesn't have an existing entry."

            $appendJsonInfo = @{
                ComputerName = $env:COMPUTERNAME
                UserName     = $ProcessUserName
                ProcessId    = @($ProcessId)
                TimeStamp    = (Get-Date -Format 'O')
            }

            if ($newJsonInfo -is [array]) {
                [System.Collections.ArrayList] $newJsonInfo = $newJsonInfo
            } else {
                [System.Collections.ArrayList] $newJsonInfo = @( $newJsonInfo )
            }

            $newJsonInfo.Add($appendJsonInfo) | Out-Null

            Write-Verbose "[Add-LMEntry] JSON: $($newJsonInfo | Out-String)"

            $jsonChangeMade = $true
        }
    } else {
        Write-Verbose "[Add-LMEntry] JSON file is empty."

        $newJsonInfo = @{
            ComputerName = $env:COMPUTERNAME
            UserName = $ProcessUserName
            ProcessId = @($ProcessId)
            TimeStamp = (Get-Date -Format 'O')
        }

        $jsonChangeMade = $true
    }

    if ($jsonChangeMade) {
        [string] $newJsonInfo = $newJsonInfo | ConvertTo-Json
        Write-Verbose "[Add-LMEntry] New JSON: $($newJsonInfo | Out-String)"
    } else {
        Write-Verbose "[Add-LMEntry] No Change Made; nothing new to show."
    }

    if ($jsonChangeMade) {
        Write-Verbose "[Add-LMEntry] Quick check for Race Conditions ..."
        if ((Test-Path $jsonFilePath) -and (Get-ItemProperty $jsonFilePath).Length -ne $jsonFilePath.Length) {
            Write-Verbose "[Add-LMEntry] Race Condition: File Size has changed. Restart Add-LMEntry"
            Add-LMEntry @PSBoundParameters
        } else {
            Write-Verbose "[Add-LMEntry] NO Race Conditions found."
            Write-Verbose "[Add-LMEntry] Opening JSON file for write (locking) ..."
            while ($true) {
                try {
                    # $file = [System.IO.File]::Open($jsonFilePath, 'OpenOrCreate', 'Write', 'None')
                    $file = [System.IO.StreamWriter] ([string] $jsonFilePath)
                    Write-Verbose "[Add-LMEntry] JSON File Opened and Locked."
                    break
                } catch {
                    Write-Warning "[Add-LMEntry] Error Opening/Locking JSON File: $($Error[0].Exception.InnerException.Message)"
                    Write-Verbose "[Add-LMEntry] Trying again ..."
                    Start-Sleep -Milliseconds 100
                }
            }
            
            Write-Verbose "[Add-LMEntry] Writing JSON ..."
            $file.WriteLine($newJsonInfo)
            Write-Verbose "[Add-LMEntry] Closing JSON ..."
            $file.Close()
            
            while (-not (Test-Path $jsonFilePath)) {
                Write-Verbose "[Add-LMEntry] Waiting for: ${jsonFilePath}"
                Start-Sleep -Milliseconds 100
            }
            Write-Verbose "[Add-LMEntry] Confirmed JSON exists"
        }
    } else {
        Write-Verbose "[Add-LMEntry] No Change Made; nothing new to write."
    }
}