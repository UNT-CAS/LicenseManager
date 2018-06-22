[string]           $projectDirectoryName = 'LicenseManager'
[IO.FileInfo]      $pesterFile           = [io.fileinfo] ([string] (Resolve-Path -Path $MyInvocation.MyCommand.Path))
[IO.DirectoryInfo] $projectRoot          = Split-Path -Parent $pesterFile.Directory
[IO.DirectoryInfo] $projectDirectory     = Join-Path -Path $projectRoot -ChildPath $projectDirectoryName -Resolve
[IO.FileInfo]      $testFile             = Join-Path -Path $projectDirectory -ChildPath ($pesterFile.Name -replace '\.Tests\.', '.') -Resolve
. $testFile

$script:defaultLMEntry = @{
    LicenseManager = '{"DirectoryPath":"", "Processes": {"notepad.exe":5, "Calculator.exe":10}}' | ConvertFrom-Json
    ProcessName     = 'notepad.exe'
    ProcessId       = 7
    ProcessUserName = 'Test\Pester'
}
$script:defaultLMEntry.LicenseManager.DirectoryPath = Join-Path -Path $projectRoot -ChildPath 'dev' -Resolve

$tests = @(
    @{
        Name                      = 'Test JSON does not exist.'
        JsonInitiallyDoesNotExist = $true
        ProcessIdFinal            = @(7)
    },
    @{
        Name                = 'Test JSON exists, but is empty.'
        ProcessIdFinal = @(7)
    },
    @{
        Name                = 'Test JSON exists, but is empty.'
        ProcessIdFinal = @(7)
        StartingJson = @'
{
    "UserName":  "Test\\Pester",
    "ProcessId":  [
                      7
                  ],
    "ComputerName":  "V-ASUSM32",
    "TimeStamp":  "Friday, June 22, 2017 5:43:33 PM"
}
'@
    }
    @{
        Name                = 'Test JSON exists, but is empty.'
        ProcessIdFinal = @(7,77)
        StartingJson        = @'
{
    "UserName":  "Test\\Pester",
    "ProcessId":  [
                      77
                  ],
    "ComputerName":  "V-ASUSM32",
    "TimeStamp":  "Friday, June 22, 2017 5:43:33 PM"
}
'@
    }
)

Describe $testFile.Name {
    foreach ($test in $tests) {
        Context $test.Name {
            $lmEntry = $script:defaultLMEntry.Clone()
            $fakeProcessName = (New-Guid).Guid
            $lmEntry.LicenseManager.Processes | Add-Member -NotePropertyName $fakeProcessName -NotePropertyValue 2
            $lmEntry.ProcessName = $fakeProcessName
            # Write-Host "LM Entry: $($lmEntry | ConvertTo-Json)"
    
            $jsonFilePath = Join-Path -Path $lmEntry.LicenseManager.DirectoryPath -ChildPath "${fakeProcessName}.json"
    
            if ($test.JsonInitiallyDoesNotExist) {
                $jsonFilePathShouldInitiallyExist = $false
            } else {
                New-Item -ItemType File -Path $jsonFilePath
                $jsonFilePathShouldInitiallyExist = $true
            }

            if ($test.StartingJson) {
                $test.StartingJson | Out-File -Encoding ascii -LiteralPath $jsonFilePath -Force
            }
    
            It "Confirm JSON exists (${jsonFilePathShouldInitiallyExist}): ${jsonFilePath}" {
                Test-Path $jsonFilePath | Should Be $jsonFilePathShouldInitiallyExist
            }
    
            It "Add-LMEntry" {
                { Add-LMEntry @lmEntry -Verbose } | Should Not Throw
            }
    
            It "Confirm JSON exists: ${jsonFilePath}" {
                Test-Path $jsonFilePath | Should Be $true
            }

            $confirmJson = Get-Content $jsonFilePath | Out-String | ConvertFrom-Json

            It "Confirm JSON UserName: $($lmEntry.ProcessUserName)" {
                $confirmJson.UserName | Should Be $lmEntry.ProcessUserName
            }

            It "Confirm JSON ComputerName: ${env:ComputerName}" {
                $confirmJson.ComputerName | Should Be $env:ComputerName
            }

            It "Confirm JSON TimeStamp is recent: $($confirmJson.TimeStamp)" {
                (Get-Date $confirmJson.TimeStamp) -gt ([datetime]::Now).AddMinutes(-1) | Should Be $true
            }

            It "Confirm JSON Process Id: $($test.ProcessIdFinal -join ', ')" {
                Compare-Object $confirmJson.ProcessId $test.ProcessIdFinal | Should BeNullOrEmpty
            }

            It "Confirm JSON Process Id Count: $($test.ProcessIdFinal.Count)" {
                ($confirmJson.ProcessId | Measure-Object).Count | Should Be $test.ProcessIdFinal.Count
            }
    
            Write-Verbose "Removing temp JSON file."
            # Remove-Item -LiteralPath $jsonFilePath -Force
        }
    }
}