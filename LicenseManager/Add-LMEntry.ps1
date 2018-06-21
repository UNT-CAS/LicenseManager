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
    Write-Verbose "[Add-LMEntry] Bound Parameters: $($MyInvocation.BoundParameters | Out-String)"
    Write-Verbose "[Add-LMEntry] Unbound Parameters: $($MyInvocation.UnboundParameters | Out-String)"
    
    [IO.FileInfo] $jsonFilePath = "$($LicenseManager.DirectoryPath)\${ProcessName}.json"
    Write-Verbose "[Add-LMEntry] JSON File: ${jsonFilePath}"
    
    if (Test-Path $jsonFilePath) {
        Write-Verbose "[Add-LMEntry] JSON file does exists."
        
        $jsonInfo = Get-Content -LiteralPath $jsonFilePath | Out-String | ConvertFrom-Json
        Write-Verbose "[Add-LMEntry] JSON: $($jsonInfo | Out-String)"
        
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
                $currentJsonInfo.TimeStamp = (Get-Date).DateTime

                Write-Verbose "[Add-LMEntry] Relevant JSON Info Updated: $($currenJsonInfo | Out-String)"
                $currenJsonInfo
            } else {
                $currentJsonInfo
            }
        }
        Write-Verbose "[Add-LMEntry] New JSON: $($newJsonInfo | Out-String)"

        Write-Verbose "[Add-LMEntry] Updating JSON file..."
        $newJsonInfo | Out-File -Encoding ascii -LiteralPath $jsonFilePath
    } else {
        Write-Verbose "[Add-LMEntry] JSON file does NOT exist."

        $jsonInfo = @{
            ComputerName = $env:COMPUTERNAME
            UserName = $ProcessUserName
            ProcessId = @($ProcessId)
            TimeStamp = (Get-Date).DateTime
        } | ConvertTo-Json
        Write-Verbose "[Add-LMEntry] JSON: [$($jsonInfo | Out-String)]"

        Write-Verbose "[Add-LMEntry] Creating JSON file..."
        "[${jsonInfo}]" | Out-File -Encoding ascii -LiteralPath $jsonFilePath
    }
}