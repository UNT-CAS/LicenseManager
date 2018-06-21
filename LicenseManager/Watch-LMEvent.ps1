#Requires -RunAsAdministrator
<#
    .Synopsis

        This is the MAIN script. This script watches for events and sends found events to Invoke-LMEvent for handling.
    .Parameter LicenseManager
        
        A JSON hashtable of processes to concurrency maximum.

        Example: '{"DirectoryPath":"\\\\license\\LicenseManager","Processes":{"notepad.exe":5,"Calculator.exe":10}}'

        Done this way so we can use the default of setting this as an Environment Variable for the system. Here's the example, but a little easier to read:

            {
                "DirectoryPath":  "\\\\license\\LicenseManager",
                "Processes":  {
                                "notepad.exe":  5,
                                "Calculator.exe":  10
                            }
            }

        The number with the process name is the concurrency count.
#>
[CmdletBinding()]
[OutputType([void])]
Param(
    [Parameter()]
    [array]
    $LicenseManager = $env:LicenseManager
)
Write-Verbose "[Watch-LMEvent] Bound Parameters: $($MyInvocation.BoundParameters | Out-String)"
Write-Verbose "[Watch-LMEvent] Unbound Parameters: $($MyInvocation.UnboundParameters | Out-String)"

if (-not $LicenseManager) {
    Throw [System.Management.Automation.ParameterBindingException] ''
}
$LicenseManager = $LicenseManager | ConvertFrom-Json

$jobScriptBlock = {
    param(
        [Parameter(Mandatory = $true)]
        [string]
        $Action,

        [Parameter(Mandatory = $true)]
        [IO.DirectoryInfo]
        $ScriptRoot,
        
        [Parameter(Mandatory = $true)]
        [array]
        $LicenseManager
    )
    . "${ScriptRoot}\Invoke-LMEvent.ps1"
    . "${ScriptRoot}\Add-LMEntry.ps1"
    . "${ScriptRoot}\Assert-LMEntry.ps1"
    . "${ScriptRoot}\Remove-LMEntry.ps1"
    
    $processes = $LicenseManager.Processes.PSObject.Properties.Name | ForEach-Object { "ProcessName = '${_}'" }
    $processQuery = "SELECT * FROM Win32_Process${Action}Trace WHERE $($Processes -join ' OR ')"
    
    $SourceIdentifier = "LicenseManager_Process${Action}_$(New-Guid)"
    Register-CimIndicationEvent -Query $processQuery -SourceIdentifier $SourceIdentifier
    
    while ($true) {
        $lmEvent = Wait-Event -SourceIdentifier $SourceIdentifier
        Write-Verbose "[Watch-LMEvent] LM ${Action} Event: $($lmEvent | Out-String)" -Verbose
        
        Remove-Event -EventIdentifier $lmEvent.EventIdentifier
        
        Invoke-LMEvent -Action $Action -LicenseManager $LicenseManager -LMEvent $lmEvent -Verbose
    }
}

<#
    Check for currently running processes a get them added.
    This should really only be needed if the script is being restarted, but let's cover our basis.
#>
foreach ($process in $LicenseManager.Processes.PSObject.Properties.Name) {
    [IO.FileInfo] $process = $process
    
    $lmEntry = @{
        LicenseManager  = $LicenseManager
        ProcessName     = $process.Name
    }
    Initialize-LMEntry @lmEntry
}

<#
    Start the Background Job to watch for Processes STARTING.
#>
$jobProcessStart = Start-Job -Name 'LM_ProcStart' -ScriptBlock $jobScriptBlock -ArgumentList 'Start',$PSScriptRoot,$LicenseManager
Write-Verbose "[Watch-LMEvent] Started Job: LM_ProcStart (${jobProcessStart})" -Verbose

<#
    Start the Background Job to watch for Processes STOPPING
#>
$jobProcessStop = Start-Job -Name 'LM_ProcStop' -ScriptBlock $jobScriptBlock -ArgumentList 'Stop',$PSScriptRoot,$LicenseManager
Write-Verbose "[Watch-LMEvent] Started Job: LM_ProcStop (${jobProcessStop})" -Verbose

<#
    This is here whil developing.
    Delete everything under here before going to production.
#>
Write-Verbose "[Watch-LMEvent] Running notepad in 1 second ..." -Verbose
Start-Sleep -Seconds 1
notepad

while ($true) { $jobProcessStart | Receive-Job; $jobProcessStop | Receive-Job; Start-Sleep -Seconds 1 }