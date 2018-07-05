<#
    .Synopsis
        Prepare this machine; *installing* this module in a location accessible by DSC.

    .Description
        Uses [psake](https://github.com/psake/psake) to prepare this machine; *installing* this module in a location accessible by DSC.

        May do different tasks depending on the environment it's running in. Read the code for the details on that.
    .Example
        # Run this Build Script:
        
        Invoke-psake .\.build.ps1
    .Example
        # Skip Bootstrap

        Invoke-psake .\.build.ps1 -Properties @{'SkipBootstrap'=$true}
    .Example
        # Run this Build Script with different parameters/properties 'thisModuleName':

        Invoke-psake .\.build.ps1 -Properties @{'thisModuleName'='OtherModuleName'}
    .Example
        # Run this Build Script with a parameters/properties that's not otherwise defined:
        
        Invoke-psake .\.build.ps1 -Properties @{'Version'=[version]'1.2.3'}
#>
$ErrorActionPreference = 'Stop'

$script:thisModuleName = 'LicenseManager'
$script:PSScriptRootParent = Split-Path $PSScriptRoot -Parent
$script:ManifestJsonFile = "${PSScriptRootParent}\${thisModuleName}\Manifest.json"
$script:BuildOutput = "${PSScriptRootParent}\dev\BuildOutput"

$script:Manifest = @{}
$Manifest_obj = Get-Content $script:ManifestJsonFile | ConvertFrom-Json
$Manifest_obj | Get-Member -MemberType Properties | ForEach-Object { $script:Manifest.Set_Item($_.Name, $Manifest_obj.($_.Name)) }

$script:Manifest_ModuleName = $null
$script:ParentModulePath = $null
$script:ResourceModulePath = $null
$script:SystemModuleLocation = $null
$script:DependsBootstrap = if ($Properties.Keys -contains 'SkipBootstrap' -and $Properties.SkipBootstrap) { $null } else { 'Bootstrap' }
$script:VersionBuild = $null

if (-not $env:CI) {
    Get-Module $Manifest.ModuleName -ListAvailable -Refresh | Uninstall-Module -Force -ErrorAction 'SilentlyContinue'
    (Get-Module $Manifest.ModuleName -ListAvailable -Refresh).ModuleBase | Remove-Item -Recurse -Force -ErrorAction 'SilentlyContinue'
}

if (($env:CI -ne 'True') -and ($env:APPVEYOR -ne 'True')) {
    function Push-AppveyorArtifact { param($FileName) Write-Host "[BUILD Push-AppveyorArtifact] Not in AppVeyor; skipping ..." -ForegroundColor Magenta }
    function Add-AppveyorMessage { param($Message) Write-Host "[BUILD Add-AppveyorMessage] ${Message}" -ForegroundColor Magenta }
}

Add-AppveyorMessage "[BUILD] Properties Keys: $($Properties.Keys -join ', ')"
Add-AppveyorMessage "[BUILD] Properties.SkipBootstrap: $($Properties.SkipBootstrap)"
Add-AppveyorMessage "[BUILD] DependsBootstrap: ${script:DependsBootstrap}"

# Parameters:
Properties {
    $thisModuleName = $script:thisModuleName
    $PSScriptRootParent = $script:PSScriptRootParent
    $ManifestJsonFile = $script:ManifestJsonFile
    $BuildOutput = $script:BuildOutput

    # Manipulate the Parameters for usage:
    
    $script:Manifest.Copyright = $script:Manifest.Copyright -f [DateTime]::Now.Year

    $script:Manifest_ModuleName = $script:Manifest.ModuleName
    $script:Manifest.Remove('ModuleName')

    $script:ParentModulePath = "${script:BuildOutput}\${script:Manifest_ModuleName}"

    $PSModulePath1 = $env:PSModulePath.Split(';')[1]
    $script:SystemModuleLocation = "${PSModulePath1}\${script:Manifest_ModuleName}"

    $script:Version = [string](& "${PSScriptRootParent}\.scripts\version.ps1")
}

# Start psake builds
Task default -Depends Compress-Archive

<#
    Bootstrap PSDepend:
        - https://github.com/RamblingCookieMonster/PSDepend
    Install Dependencies
#>
Task Bootstrap -Description "Bootstrap & Run PSDepend" {
    $PSDepend = Get-Module -Name 'PSDepend'
    Add-AppveyorMessage "[BUILD Bootstrap] PSDepend: $($PSDepend.Version)"
    if ($PSDepend)
    {
        Add-AppveyorMessage "[BUILD Bootstrap] PSDepend: Updating..."
        $PSDepend | Update-Module -Force
    }
    else
    {
        Add-AppveyorMessage "[BUILD Bootstrap] PSDepend: Installing..."
        Install-Module -Name 'PSDepend' -Force
    }

    Add-AppveyorMessage "[BUILD Bootstrap] PSDepend: Installing..."
    $PSDepend = Import-Module -Name 'PSDepend' -PassThru
    Add-AppveyorMessage "[BUILD Bootstrap] PSDepend: $($PSDepend.Version)"

    Add-AppveyorMessage "[BUILD Bootstrap] PSDepend: Invoking '${PSScriptRootParent}\REQUIREMENTS.psd1'"
    Push-Location $PSScriptRootParent
    Invoke-PSDepend -Path "${PSScriptRootParent}\REQUIREMENTS.psd1" -Force
    Pop-Location
}

<#
    Preperation and Setup:
        - Import Manifest.json to create the PDS1 file.
        - Modify Manifest information; keeping purged information.
        - Establish Module/Resource Locations/Paths.
#>
Task SetupModule -Description "Prepare and Setup Module" -Depends $DependsBootstrap {
    New-Item -ItemType Directory -Path $script:ParentModulePath -Force

    $script:Manifest.Path = "${script:ParentModulePath}\${script:Manifest_ModuleName}.psd1"
    $script:Manifest.ModuleVersion = $script:Version
    Add-AppveyorMessage "[BUILD SetupModule] New-ModuleManifest: $($script:Manifest | ConvertTo-Json -Compress)"
    New-ModuleManifest @script:Manifest

    $copyItem = @{
        LiteralPath = "${PSScriptRootParent}\${script:thisModuleName}\${script:thisModuleName}.psm1"
        Destination = $script:ParentModulePath
        Force       = $true
    }
    Add-AppveyorMessage "[BUILD SetupModule] Copy-Item: $($copyItem | ConvertTo-Json -Compress)"
    Copy-Item @copyItem

    foreach ($directory in (Get-ChildItem "${PSScriptRootParent}\${thisModuleName}" -Directory)) {
        $copyItem = @{
            LiteralPath = $directory.FullName
            Destination = $script:ParentModulePath
            Recurse     = $true
            Force       = $true
        }
        Add-AppveyorMessage "[BUILD SetupModule] Copy-Item: $($copyItem | ConvertTo-Json -Compress)"
        Copy-Item @copyItem
    }
}

<#
    Put Module/Resource in locations accessible by DSC:
        - Create the PSD1 files from Manifest.
        - Copy PSM1 to location.
        - Copy Module to System Location; for testing.
#>
Task InstallModule -Description "Prepare and Setup/Install Module" -Depends SetupModule {
    $New_Item = @{
        ItemType = 'Directory'
        Path     = $script:SystemModuleLocation
        Force    = $true
    }
    Add-AppveyorMessage "[BUILD InstallModule] New-Item: $($New_Item | ConvertTo-Json -Compress)"
    New-Item @New_Item | Out-Null

    $Copy_Item = @{
        Path        = "${script:BuildOutput}\*"
        Destination = $script:SystemModuleLocation
        Recurse     = $true
        Force       = $true
    }
    Add-AppveyorMessage "[BUILD InstallModule] Copy-Item: $($Copy_Item | ConvertTo-Json -Compress)"
    Copy-Item @Copy_Item
}

<#
    Tests
        - Pester
        - CodeCov
#>
Task TestModule -Description "Run Pester Tests and CoeCoverage" -Depends InstallModule {
    Add-AppveyorMessage "[BUILD TestModule] Import-Module ${env:Temp}\CodeCovIo.psm1"
    Import-Module ${env:Temp}\CodeCovIo.psm1
    
    $invokePester = @{
        Path = "${PSScriptRootParent}\Tests"
        CodeCoverage = (Get-ChildItem "${PSScriptRootParent}\${thisModuleName}" -Recurse -Include '*.psm1', '*.ps1').FullName
        PassThru = $true
        OutputFormat = 'NUnitXml'
        OutputFile   = ([IO.FileInfo] '{0}\dev\CodeCoverage.xml' -f $PSScriptRootParent)
    }
    Add-AppveyorMessage "[BUILD TestModule] Invoke-Pester $($invokePester | ConvertTo-Json)"
    $res = Invoke-Pester @invokePester
    Add-AppveyorMessage "[BUILD TestModule] Pester Result: $($res | ConvertTo-Json)"
    
    Add-AppveyorMessage "[BUILD TestModule] Adding Results to Artifacts..."
    # (New-Object 'System.Net.WebClient').UploadFile("https://ci.appveyor.com/api/testresults/nunit/${env:APPVEYOR_JOB_ID}", (Resolve-Path $invokePester.OutputFile))
    Push-AppveyorArtifact -FileName (Resolve-Path $invokePester.OutputFile)
    
    $exportCodeCovIoJson = @{
        CodeCoverage = $res.CodeCoverage
        RepoRoot     = $PSScriptRootParent
        Path         = ([string] $invokePester.OutputFile).Replace('.xml', '.json')
    }
    Add-AppveyorMessage "[BUILD TestModule] Export-CodeCovIoJson: $($exportCodeCovIoJson | ConvertTo-Json)"
    Export-CodeCovIoJson @exportCodeCovIoJson

    Add-AppveyorMessage "[BUILD TestModule] Adding Results to Artifacts..."
    Push-AppveyorArtifact -FileName (Resolve-Path $exportCodeCovIoJson.Path)
    
    Add-AppveyorMessage "[BUILD TestModule] Uploading CodeCov.io Report ..."
    & "${env:Temp}\Codecov\codecov.exe" -f .\dev\CodeCoverage.json

    if ($res.FailedCount -gt 0) {
        Throw "$($res.FailedCount) tests failed."
    }
}

<#
    Compress things for releasing
#>
Task CompressModule -Description "Compress module for easy download from GitHub" -Depends InstallModule {
    Add-AppveyorMessage "[BUILD CompressModule] Import-Module ${env:Temp}\CodeCovIo.psm1"
    Compress-Archive -Path $script:ParentModulePath -DestinationPath "${script:ParentModulePath}.zip"

    Push-AppveyorArtifact -FileName (Resolve-Path "${script:ParentModulePath}.zip")
}
