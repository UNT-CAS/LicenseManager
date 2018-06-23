<#
    Deployed with PSDeploy
        - https://github.com/RamblingCookieMonster/PSDeploy
#>
$PSScriptRootParent = Split-Path $PSScriptRoot -Parent
Write-Host "[Deploy] PSScriptRootParent: ${PSScriptRootParent}" -Foregroundcolor 'Blue' -BackgroundColor 'Magenta'
Write-Host "[Deploy] APPVEYOR_PROJECT_NAME: ${env:APPVEYOR_PROJECT_NAME}" -Foregroundcolor 'Blue' -BackgroundColor 'Magenta'

Deploy Module {
    By PSGalleryModule OneDriveDsc {
        FromSource "${PSScriptRootParent}\BuildOutput\OneDriveDsc"
        To PSGallery
        # Tagged Testing
        WithOptions @{
            ApiKey = $env:PSGalleryApiKey
        }
    }
}