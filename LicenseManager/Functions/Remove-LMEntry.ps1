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
function Remove-LMEntry {
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
    Write-Verbose "[Remove-LMEntry] Bound Parameters: $($MyInvocation.BoundParameters | Out-String)"
    Write-Verbose "[Remove-LMEntry] Unbound Parameters: $($MyInvocation.UnboundParameters | Out-String)"

    [IO.FileInfo] $jsonFilePath = "$($LicenseManager.DirectoryPath)\${ProcessName}.json"
    Write-Verbose "[Remove-LMEntry] JSON File: ${jsonFilePath}"
    
    if (Test-Path $jsonFilePath) {
        Write-Verbose "[Remove-LMEntry] JSON file does exists."
        
        $jsonInfo = Get-Content -LiteralPath $jsonFilePath | Out-String | ConvertFrom-Json
        Write-Verbose "[Remove-LMEntry] JSON: $($jsonInfo | ConvertTo-Json)"
        
        Write-Verbose "[Remove-LMEntry] Updating JSON: $($jsonInfo | ConvertTo-Json)"
        $newJsonInfo = $jsonInfo | Foreach-Object {
            $currentJsonInfo = $_
            if (($currentJsonInfo.ComputerName -eq $env:COMPUTERNAME) -and ($currentJsonInfo.ProcessId -contains $ProcessId)) {
                Write-Verbose "[Remove-LMEntry] Relevant JSON Info Found: $($currenJsonInfo | Out-String)"
                if (($currentJsonInfo.ProcessId | Measure-Object).Count -eq 1) {
                    continue
                } else {
                    [System.Collections.ArrayList] $tempProcessIds = $currentJsonInfo.ProcessId
                    $tempProcessIds.Remove($ProcessId)
                    $currentJsonInfo.ProcessId = $tempProcessIds
                }
            } else {
                Write-Output $currentJsonInfo
            }
        }
        Write-Verbose "[Remove-LMEntry] New JSON: $($newJsonInfo | Out-String)"

        Write-Verbose "[Remove-LMEntry] Quick check for Race Conditions ..."
        if ((Get-ItemProperty $jsonFilePath).Length -ne $jsonFilePath.Length) {
            Write-Verbose "[Remove-LMEntry] Race Condition: File Size has changed. Restart Remove-LMEntry"
            Remove-LMEntry @PSBoundParameters
        } else {
            Write-Verbose "[Remove-LMEntry] NO Race Conditions found."
            Write-Verbose "[Remove-LMEntry] Opening JSON file for write (locking) ..."
            while ($true) {
                try {
                    # $file = [System.IO.File]::Open($jsonFilePath, 'OpenOrCreate', 'Write', 'None')
                    $file = [System.IO.StreamWriter] ([string] $jsonFilePath)
                    Write-Verbose "[Remove-LMEntry] JSON File Opened and Locked."
                    break
                } catch {
                    Write-Warning "[Remove-LMEntry] Error Opening/Locking JSON File: $($Error[0].Exception.InnerException.Message)"
                    Write-Verbose "[Remove-LMEntry] Trying again ..."
                    Start-Sleep -Milliseconds 100
                }
            }

            $file.WriteLine(($newJsonInfo | ConvertTo-Json))
            $file.Close()
        }
    } else {
        Write-Warning "[Remove-LMEntry] JSON file does NOT exist; odd. :|"
    }
}