﻿# Line break for readability in AppVeyor console
Write-Host -Object ''

# Make sure we're using the Master branch and that it's not a pull request
# Environmental Variables Guide: https://www.appveyor.com/docs/environment-variables/
if ($env:APPVEYOR_REPO_BRANCH -eq 'master' -and $env:APPVEYOR_PULL_REQUEST_NUMBER -eq 0)
{
    # We're going to add 1 to the revision value since a new commit has been merged to Master
    # This means that the major / minor / build values will be consistent across GitHub and the Gallery
    Try 
    {
        # This is where the module manifest lives
        $manifestPath = '.\Rubrik\Rubrik.psd1'

        # Start by importing the manifest to determine the version, then add 1 to the revision
        $manifest = Test-ModuleManifest -Path $manifestPath
        [System.Version]$version = $manifest.Version
        [String]$newVersion = New-Object -TypeName System.Version -ArgumentList ($version.Major, $version.Minor, $version.Build, ($version.Revision+1))

        # Update the manifest with the new version value and fix the weird string replace bug
        Update-ModuleManifest -Path $manifestPath -ModuleVersion $newVersion
        (Get-Content -Path $manifestPath) -replace 'PSGet_Rubrik', 'Rubrik' | Set-Content -Path $manifestPath
    }
    catch
    {
        throw $_
    }

    # Publish the new version to the PowerShell Gallery
    Try 
    {
        # Build a splat containing the required details and make sure to Stop for errors which will trigger the catch
        $PM = @{
            Path        = '.\Rubrik'
            NuGetApiKey = $env:NuGetApiKey
            ErrorAction = 'Stop'
        }
        Publish-Module @PM
        Write-Host "Rubrik PowerShell Module version $version published to the PowerShell Gallery." -ForegroundColor Cyan
    }
    Catch 
    {
        # Sad panda; it broke
        throw "Publishing update $version to the PowerShell Gallery failed."
    }

    # Publish the new version back to Master on GitHub
    Try 
    {
        # Set up a path to the git.exe cmd, import posh-git to give us control over git, and then push changes to GitHub
        # Note that "update version" is included in the appveyor.yml file's "skip a build" regex to avoid a loop
        $env:Path += ";$env:ProgramFiles\Git\cmd"
        Import-Module posh-git -ErrorAction Stop
        git add .
        git commit -s -m "Update version to $version"
        git push
        Write-Host "Rubrik PowerShell Module version $version published to GitHub." -ForegroundColor Cyan
    }
    Catch 
    {
        # Sad panda; it broke
        throw "Publishing update $version to GitHub failed."
    }
}