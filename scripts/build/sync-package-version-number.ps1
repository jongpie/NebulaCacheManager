# This script is used to automatically sync the package version numbers for Nebula Cache Manager's 2 unlocked packages
# (stored in sfdx-project.json) and update other files - package.json and CacheManager.cls - to ensure that all 3 files have the same version number

$sfdxProjectJsonPath = "./sfdx-project.json"
$packageJsonPath = "./package.json"
$readmeClassPath = "./README.md"
$cacheManagerClassPath = "./nebula-cache-manager/core/classes/CacheManager.cls"

function Get-SFDX-Project-JSON {
    Get-Content -Path $sfdxProjectJsonPath | ConvertFrom-Json
}

function Get-Version-Number {
    $projectJSON = Get-SFDX-Project-JSON
    $versionNumber = ($projectJSON).packageDirectories[0].versionNumber
    $versionNumber = $versionNumber.substring(0, $versionNumber.LastIndexOf('.'))
    return $versionNumber
}

function Get-Package-JSON {
    Get-Content -Raw -Path $packageJsonPath | ConvertFrom-Json
}

function Update-Package-JSON {
    param (
        $versionNumber
    )
    $packageJson = Get-Package-JSON
    Write-Output "Bumping package.json version number to: $versionNumber"

    $packageJson.version = $versionNumber
    ConvertTo-Json -InputObject $packageJson | Set-Content -Path $packageJsonPath -NoNewline
    npx prettier --write $packageJsonPath
    git add $packageJsonPath
}

function Get-README {
    Get-Content -Raw -Path $readmeClassPath
}

function Update-README {
    param (
        $versionNumber
    )
    $versionNumber = "v" + $versionNumber
    $readmeContents = Get-README
    Write-Output "Bumping README unlocked package version numbers to: $versionNumber"

    $targetRegEx = "(.+ Namespace - )(.+)"
    $replacementRegEx = '$1' + $versionNumber
    $readmeContents -replace $targetRegEx, $replacementRegEx | Set-Content -Path $readmeClassPath -NoNewline
    npx prettier --write $readmeClassPath
    git add $readmeClassPath
}

function Get-Cache-Manager-Class {
    Get-Content -Raw -Path $cacheManagerClassPath
}

function Update-Cache-Manager-Class {
    param (
        $versionNumber
    )
    $versionNumber = "v" + $versionNumber
    $cacheManagerClassContents = Get-Cache-Manager-Class
    Write-Output "Bumping CacheManager.cls version number to: $versionNumber"

    $targetRegEx = "(.+CURRENT_VERSION_NUMBER = ')(.+)(';)"
    $replacementRegEx = '$1' + $versionNumber + '$3'
    $cacheManagerClassContents -replace $targetRegEx, $replacementRegEx | Set-Content -Path $cacheManagerClassPath -NoNewline
    npx prettier --write $cacheManagerClassPath
    git add $cacheManagerClassPath
}

$versionNumber = Get-Version-Number
Write-Output "Target Version Number: $versionNumber"

Update-Package-JSON $versionNumber
Update-README $versionNumber
Update-Cache-Manager-Class $versionNumber
