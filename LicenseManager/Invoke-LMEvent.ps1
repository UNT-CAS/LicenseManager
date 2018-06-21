<#
    .Synopsis
    
        This is the handler for each detected event (start/stop of watched process).

    .Parameter Action

        The action (Start Event or Stop Event) that we're watching for.
        This just makes it easier than eveluating the LMEvent parameter for this information.

    .Parameter LMEvent

        Event object of the event triggered by the starting or stopping of a watched process.

    .Parameter LicenseManager
        
        An object, as converted from `Watch-LMEvent`'s LicenseManager Parameter.
#>
function Invoke-LMEvent {
    [CmdletBinding()]
    [OutputType([void])]
    Param(
        [Parameter(Mandatory = $true)]
        [ValidateSet('Start', 'Stop')]
        [string]
        $Action,

        [Parameter(Mandatory = $true)]
        [System.Management.Automation.PSEventArgs]
        $LMEvent,
        
        [Parameter(Mandatory = $true)]
        [array]
        $LicenseManager
    )
    Write-Verbose "[Invoke-LMEvent] Bound Parameters: $($MyInvocation.BoundParameters | Out-String)"
    Write-Verbose "[Invoke-LMEvent] Unbound Parameters: $($MyInvocation.UnboundParameters | Out-String)"

    Write-Verbose "[Invoke-LMEvent] LMEvent: $($LMEvent | Out-String)" -Verbose
    
    $ProcessName = $LMEvent.SourceEventArgs.NewEvent.ProcessName
    Write-Verbose "[Invoke-LMEvent] ProcessName:  ${ProcessName}" -Verbose
    $ProcessId = $LMEvent.SourceEventArgs.NewEvent.ProcessId
    Write-Verbose "[Invoke-LMEvent] ProcessId:  ${ProcessId}" -Verbose

    if ($Action -eq 'Start') {
        $ProcessUserName = (Get-Process -Id $ProcessId -IncludeUserName).UserName
        Write-Verbose "[Invoke-LMEvent] ProcessUserName:  ${ProcessUserName}" -Verbose
    } else {
        $ProcessUserName = $null
        Write-Verbose "[Invoke-LMEvent] ProcessUserName is UNAVAILABLE; Process Stopped." -Verbose
    }
    
    $lmEntry = @{
        LicenseManager  = $LicenseManager
        ProcessName     = $ProcessName
        ProcessId       = $ProcessId
        ProcessUserName = $ProcessUserName
    }

    if ($Action = 'Start') {
        if (Assert-LMEntry @lmEntry) {
            Add-LMEntry @lmEntry
        } else {
            Deny-LMEntry @lmEntry
        }
    } else { # Stop
        Remove-LMEntry @lmEntry
    }
}