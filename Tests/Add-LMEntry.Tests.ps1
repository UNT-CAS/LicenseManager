[string]           $projectDirectoryName = 'LicenseManager'
[IO.FileInfo]      $pesterFile           = [io.fileinfo] ([string] (Resolve-Path -Path $MyInvocation.MyCommand.Path))
[IO.DirectoryInfo] $projectRoot          = Split-Path -Parent $pesterFile.Directory
[IO.DirectoryInfo] $projectDirectory     = Join-Path -Path $projectRoot -ChildPath $projectDirectoryName -Resolve
[IO.FileInfo]      $testFile             = Join-Path -Path $projectDirectory -ChildPath (Join-Path -Path 'Functions' -ChildPath ($pesterFile.Name -replace '\.Tests\.', '.')) -Resolve
. $testFile

$script:defaultLMEntry = @{
    LicenseManager = '{"DirectoryPath":"", "Processes": {"notepad.exe":5, "Calculator.exe":10}}' | ConvertFrom-Json
    ProcessName     = 'notepad.exe'
    ProcessId       = 7
    ProcessUserName = 'Test\Pester'
}
$script:defaultLMEntry.LicenseManager.DirectoryPath = Join-Path -Path $projectRoot -ChildPath 'dev' -Resolve

[System.Collections.ArrayList] $tests = @()
foreach ($example in (Get-ChildItem (Join-Path -Path $projectRoot -ChildPath 'Examples' -Resolve) -Filter '*.psd1' -File)) {
    [hashtable] $test = @{
        Name = $example.BaseName.Replace('_', ' ')
    }
    Write-Verbose "Test: $($test | ConvertTo-Json)"
    
    foreach ($exampleData in (Import-PowerShellDataFile -LiteralPath $example.FullName).GetEnumerator()) {
        if ($exampleData.Name -eq 'StartingJson') {
            $jsonTemp = $exampleData.Value | ConvertFrom-Json
            foreach ($entry in $jsonTemp) {
                if (($entry.PSObject.Properties.Name -contains 'ComputerName') -and ([string]::IsNullOrEmpty($entry.ComputerName))) {
                    $entry.ComputerName = $env:ComputerName
                }
            }
            $test.Add($exampleData.Name, ($jsonTemp | ConvertTo-Json))
        } else {
            $test.Add($exampleData.Name, $exampleData.Value)
        }
    }
    
    Write-Verbose "Test: $($test | ConvertTo-Json)"
    $tests.Add($test) | Out-Null
}

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

            foreach ($item in $confirmJson) {
                if ($item.ComputerName -eq $env:ComputerName) {
                    It "Confirm JSON UserName: $($lmEntry.ProcessUserName)" {
                        $item.UserName | Should Be $lmEntry.ProcessUserName
                    }
        
                    It "Confirm JSON ComputerName: ${env:ComputerName}" {
                        $item.ComputerName | Should Be $env:ComputerName
                    }
        
                    It "Confirm JSON TimeStamp is recent: $($item.TimeStamp)" {
                        (Get-Date $item.TimeStamp) -gt ([datetime]::Now).AddMinutes(-1) | Should Be $true
                    }
        
                    It "Confirm JSON Process Id: $($test.ProcessIdFinalAdd -join ', ')" {
                        Compare-Object $item.ProcessId $test.ProcessIdFinalAdd | Should BeNullOrEmpty
                    }
        
                    It "Confirm JSON Process Id Count: $($test.ProcessIdFinalAdd.Count)" {
                        ($item.ProcessId | Measure-Object).Count | Should Be $test.ProcessIdFinalAdd.Count
                    }
                }
            }

            Write-Verbose "Removing temp JSON file."
            Remove-Item -LiteralPath $jsonFilePath -Force
        }
    }
}