<#
    .Synopsis

        This script will kill a process and alert the user that concurrent usage has exceeded.

    .Description

        This script will deny the user from using the program/process by:
        - Alerting the user that concurrent usage has exceeded.
        - Killing the running process.
    
    .Parameter LicenseManager
        
        An object, as converted from `Watch-LMEvent`'s LicenseManager Parameter.
    
    .Parameter ProcessName

        The name of the Process, with the extension.

    .Parameter ProcesssId

        The Process ID of the currently running Process.

    .Parameter ProcesssUserName

        The UserName of the user running the aforementioned Process ID.
#>
function Deny-LMEntry {
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
    Write-Verbose "[Deny-LMEntry] Bound Parameters: $($MyInvocation.BoundParameters | Out-String)"
    Write-Verbose "[Deny-LMEntry] Unbound Parameters: $($MyInvocation.UnboundParameters | Out-String)"

    function private:Invoke-AsUser {
        [CmdletBinding()]
        [OutputType([void])]
        param(
            [Parameter(Mandatory = $true)]
            [string]
            $User,
            
            [Parameter(Mandatory = $true)]
            [string]
            $Command
        )
        $sch_name = 'DSC untcasWallpaper UpdatePerUserSystemParameters'

        $encodedCommand = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($command))
        $vbscript = @'
Dim objShell
Set objShell = WScript.CreateObject("WScript.Shell")
objShell.Run """{0}"" {1}", 0
'@
        $vbscript = $vbscript -f @(
            (Get-Command 'powershell').Source,
            "-NonInteractive -ExecutionPolicy ByPass -EncodedCommand ${encodedCommand}"
        )

        $vbscript_file = "${env:SystemRoot}\Debug\$((New-Guid).Guid).vbs"
        Write-Verbose "[Deny-LMEntry][Invoke-AsUser] (Set) Writing VBS (${vbscript_file}): $($vbscript | Out-String)"
        $vbscript | Out-File -Encoding 'ascii' $vbscript_file -Force

        $New_ScheduledTaskAction = @{
            'Execute'  = (Get-Command 'wscript').Source;
            'Argument' = "//NoLogo //E:vbscript ${vbscript_file}";
        }
        Write-Verbose "[Deny-LMEntry][Invoke-AsUser] (Set) New-ScheduledTaskAction: $($New_ScheduledTaskAction | Out-String)"

        $New_ScheduledTask = @{
            'Action'    = (New-ScheduledTaskAction @New_ScheduledTaskAction);
            'Principal' = (New-ScheduledTaskPrincipal -UserId $user);
            'Settings'  = (New-ScheduledTaskSettingsSet -Hidden);
            'Trigger'   = (New-ScheduledTaskTrigger -AtLogOn);
        }
        Write-Verbose "[Deny-LMEntry][Invoke-AsUser] (Set) New-ScheduledTask: $($New_ScheduledTask | Out-String)"

        $Register_ScheduledTask = @{
            'TaskName'    = $sch_name;
            'InputObject' = (New-ScheduledTask @New_ScheduledTask);
        }
        Write-Verbose "[Deny-LMEntry][Invoke-AsUser] (Set) Register-ScheduledTask: $($Register_ScheduledTask | Out-String)"
        Register-ScheduledTask @Register_ScheduledTask | Out-String | Write-Verbose

        Write-Verbose "[Deny-LMEntry][Invoke-AsUser] (Set) Start-ScheduledTask: ${sch_name}"
        Start-ScheduledTask -TaskName $sch_name | Out-String | Write-Verbose

         For ($i = 100; $i -le 10000; $i + 100) {
            $ScheduledTaskInfo = Get-ScheduledTaskInfo -TaskName $sch_name
            Write-Verbose "[Deny-LMEntry][Invoke-AsUser] (Set) Waiting for ScheduledTask to Run; Last Task Result: [$($ScheduledTaskInfo.LastRunTime)] $($ScheduledTaskInfo.LastTaskResult)"
            if ($ScheduledTaskInfo.LastTaskResult -eq 267011) {
                Write-Verbose "[Deny-LMEntry][Invoke-AsUser] (Set) $($ScheduledTaskInfo.LastTaskResult): ScheduledTask *likely* hasn't run yet."
            }
            elseif ($ScheduledTaskInfo.LastTaskResult -eq 267009) {
                Write-Verbose "[Deny-LMEntry][Invoke-AsUser] (Set) $($ScheduledTaskInfo.LastTaskResult): ScheduledTask *likely* is running."
            }
            if ($ScheduledTaskInfo.LastTaskResult -eq 0) {
                break
            }
            else {
                Start-Sleep -Milliseconds $i
            }
        }
        Unregister-ScheduledTask -TaskName $sch_name -Confirm:$false
        Remove-Item $vbscript_file -Force
    }

    $blocked_app_vbs = @'
Dim wshShell: Set wshShell = WScript.CreateObject("WScript.Shell")
WshShell.Popup "{0}", {1}, "{2}", {3}
'@ -f @(
        ($PopupTextStandard.Replace([System.Environment]::NewLine, '"& vbCrLf &"') -f @($PopupTextReason.Replace([System.Environment]::NewLine, '"& vbCrLf &"'), '{0}')),
        $PopupSecondsToWait,
        $PopupTitle,
        $PopupType
    )
}



