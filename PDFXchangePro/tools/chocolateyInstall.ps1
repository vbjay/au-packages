﻿$ErrorActionPreference = 'Stop'; # stop on all errors
$packageName = 'PDFXchangePro' 
$toolsDir   = "$(Split-Path -parent $MyInvocation.MyCommand.Definition)"
$version    = [version] $env:ChocolateyPackageVersion

if ( $version.Revision -gt 20210101 ) {
    $version = New-Object version $version.Major, $version.Minor, $version.Build, 0
    Write-Warning "'Package fix version notation' detected. Assuming original build version was .0"
}

$filename   = 'ProV9.x86.msi'
$filename64 = 'ProV9.x64.msi'
$primaryDownloadUrl = "https://downloads.pdf-xchange.com/$filename"
$primaryDownloadUrl64 = "https://downloads.pdf-xchange.com/$filename64"
$url        = "https://builds-archive.tracker-software.com/$version/$filename"
$url64      = "https://builds-archive.tracker-software.com/$version/$filename64"
$checksum   = 'FC617CCE3BA15DAA0BFEE22224C450E9CDEC0D5E29A79A3B2F3B031423D4BB16'
$checksum64 = '37C756078823029670EB09CDFDFC2F424C4AACB55C7B5C8191B14D12D5C53F18'
$lastModified32 = New-Object -TypeName DateTimeOffset 2023, 3, 7, 6, 35, 30, 0 # Last modified time corresponding to this package version
$lastModified64 = New-Object -TypeName DateTimeOffset 2023, 3, 7, 6, 35, 53, 0 # Last modified time corresponding to this package version

# Tracker Software have fixed download URLs, but if the binary changes we can fall back to their alternate (but slower) download site
# so the package doesn't break.
function CheckDownload($url, $primaryDownloadUrl, [DateTimeOffset] $packageVersionLastModified)
{
    $headers = Get-WebHeaders -url $primaryDownloadUrl
    $lastModifiedHeader = $headers.'Last-Modified'

    $lastModified = [DateTimeOffset]::Parse($lastModifiedHeader, [Globalization.CultureInfo]::InvariantCulture)

    Write-Verbose "Package LastModified: $packageVersionLastModified"
    # The extra space is not a typo, but to mitigate Chocolatey 4 Business Package Internalizer regex accidentally matching the next line as a URL!
    Write-Verbose "HTT P Last Modified  : $lastModified"

    if ($lastModified -ne $packageVersionLastModified) {
        Write-Warning "The download available at $primaryDownloadUrl has changed from what this package was expecting. Falling back to $url for version-specific URL"
        $url
    } else {
        Write-Verbose "Primary URL matches package expectation"
        $primaryDownloadUrl
    }
}

$url = CheckDownload $url $primaryDownloadUrl $lastModified32
$url64 = CheckDownload $url64 $primaryDownloadUrl64 $lastModified64

$packageArgs = @{
  packageName   = $packageName
  unzipLocation = $toolsDir
  fileType      = 'MSI'
  url           = $url
  url64bit      = $url64
  silentArgs = '/quiet /norestart'
  validExitCodes= @(0, 3010, 1641)

  softwareName  = 'PDF-XChange Pro'

  checksum = $checksum
  checksumType  = 'sha256' 
  checksum64 = $checksum64
  checksumType64= 'sha256' 
}

$packageParameters = Get-PackageParameters

$customArguments = @{}

if ($packageParameters) {
    # http://help.tracker-software.com/EUM/default.aspx?pageid=PDFXEdit3:switches_for_msi_installers

    if ($packageParameters.ContainsKey("NoDesktopShortcuts")) {
        Write-Host "You want NoDesktopShortcuts"
        $customArguments.Add("DESKTOP_SHORTCUTS", "0")
    }

    if ($packageParameters.ContainsKey("NoUpdater")) {
        Write-Host "You want NoUpdater"
        $customArguments.Add("NOUPDATER", "1")
    }

    if ($packageParameters.ContainsKey("NoViewInBrowsers")) {
        Write-Host "You want NoViewInBrowsers"
        $customArguments.Add("VIEW_IN_BROWSERS", "0")
    }

    if ($packageParameters.ContainsKey("NoSetAsDefault")) {
        Write-Host "You want NoSetAsDefault"
        $customArguments.Add("SET_AS_DEFAULT", "0")
    }

    if ($packageParameters.ContainsKey("NoProgramsMenuShortcuts")) {
        Write-Host "You want NoProgramsMenuShortcuts"
        $customArguments.Add("PROGRAMSMENU_SHORTCUTS", "0")
    }

    if ($packageParameters.ContainsKey("KeyFile")) {
        if ($packageParameters["KeyFile"] -eq "") {
          Throw 'KeyFile needs a colon-separated argument; try something like this: --params "/KeyFile:C:\Users\foo\Temp\PDFXChangeEditor.xcvault".'
        } else {
          Write-Host "You want a KeyFile named $($packageParameters["KeyFile"])"
          $customArguments.Add("KEYFILE", $packageParameters["KeyFile"])
        }
    }

} else {
    Write-Debug "No Package Parameters Passed in"
}

if ($customArguments.Count) { 
    $packageArgs.silentArgs += " " + (($customArguments.GetEnumerator() | ForEach-Object { "$($_.Name)=$($_.Value)" } ) -join " ")
}

Install-ChocolateyPackage @packageArgs
