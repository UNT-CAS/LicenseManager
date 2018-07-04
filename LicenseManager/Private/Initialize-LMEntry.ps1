#Requires -RunAsAdministrator
<#
    .Synopsis

        This script will just do a bunch of calls to Add-Entry; initializing the tracking.

    .Description

        This script only gets run when the main watcher is initially started.
        
        This adds any currently running processes to the JSON file. This may cause the JSON count to exceed the concurrency maximum.
        I don't expect this to ever really be an issue since the watcher should stay running from the time the server starts; assuming this script was implemented the way it was designed to be. See README for usage instructions.
    
    .Parameter LicenseManager
        
        An object, as converted from `Watch-LMEvent`'s LicenseManager Parameter.
    
    .Parameter ProcessName

        The name of the Process, with the extension.

#>
function Initialize-LMEntry {
    [CmdletBinding()]
    [OutputType([void])]
    param(
        [Parameter(Mandatory = $true)]
        [array]
        $LicenseManager,

        [Parameter(Mandatory = $true)]
        [IO.FileInfo]
        $ProcessName
    )
    Write-Verbose "[Initialize-LMEntry] Bound Parameters: $($MyInvocation.BoundParameters | Out-String)"
    Write-Verbose "[Initialize-LMEntry] Unbound Parameters: $($MyInvocation.UnboundParameters | Out-String)"
    
    <#
        The if statements are required for Pester testing.
    #>
    if (-not (Get-Command 'Add-LMEntry' -ErrorAction SilentlyContinue)) {
        . "${PSScriptRoot}\Add-LMEntry.ps1"
    }

    Write-Verbose "[Initialize-LMEntry] Ensure LicenseManager DirectoryPath Exists: $($LicenseManager.DirectoryPath)"
    New-Item -ItemType Directory -Path $LicenseManager.DirectoryPath -Force | Write-Verbose

    Write-Verbose "[Initialize-LMEntry] ProcessName: ${ProcessName}"

    $processes = Get-Process $ProcessName.BaseName -IncludeUserName -ErrorAction SilentlyContinue
    Write-Verbose "[Initialize-LMEntry] Processes: $($processes | Out-String)"
    
    if ($processes) {
        foreach ($process in $processes) {
            Write-Verbose "[Initialize-LMEntry] Process: $($process | Out-String)"
            
            $lmEntry = @{
                LicenseManager  = $LicenseManager
                ProcessName     = $ProcessName
                ProcessId       = $process.Id
                ProcessUserName = $process.UserName
            }
            Write-Verbose "[Initialize-LMEntry] Add-LMEntry: $($lmEntry | ConvertTo-Json)"
            Add-LMEntry @lmEntry
        }
    }
}