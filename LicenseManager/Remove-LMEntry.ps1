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
    [CmdleBinding()]
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
        Write-Verbose "[Remove-LMEntry] JSON: $($jsonInfo | Out-String)"
        
        $newJsonInfo = $jsonInfo | Foreach-Object {
            $currentJsonInfo = $_
            if (($currentJsonInfo.ComputerName -eq $env:COMPUTERNAME) -and ($currentJsonInfo.UserName -eq $ProcessUserName)) {
                Write-Verbose "[Remove-LMEntry] Relevant JSON Info Found: $($currenJsonInfo | Out-String)"
                if ($currentJsonInfo.ProcessId -contains $ProcessId) {
                    Write-Verbose "[Remove-LMEntry] Relevant JSON contains the Process Id (${ProcessId}) we want to Add!"
                    if (($currentJsonInfo.ProcessId | Measure-Object).Count -eq 1) {
                        continue
                    } else {
                        [System.Collections.ArrayList] $tempProcessIds = $currentJsonInfo.ProcessId
                        $tempProcessIds.Remove($ProcessId)
                        $currentJsonInfo.ProcessId = $tempProcessIds
                    }
                } else {
                    Write-Warning "[Remove-LMEntry] Our ProcessId isn't in the file; odd. :|"
                    Write-Output $currenJsonInfo
                }
            } else {
                Write-Output $currentJsonInfo
            }
        }
        Write-Verbose "[Remove-LMEntry] New JSON: $($newJsonInfo | Out-String)"

        Write-Verbose "[Remove-LMEntry] Updating JSON file..."
        $newJsonInfo | Out-File -Encoding ascii -LiteralPath $jsonFilePath
    } else {
        Write-Warning "[Remove-LMEntry] JSON file does NOT exist; odd. :|"
    }
}