# Builds Doppel.exe with the C# compiler that ships with Windows (.NET Framework 4.x).
# No SDK or Visual Studio needed.
# Usage (from the repository root):  powershell -ExecutionPolicy Bypass -File windows\build.ps1
# Output: windows\build\Doppel.exe
$ErrorActionPreference = 'Stop'
$root = $PSScriptRoot
$out  = Join-Path $root 'build'
New-Item -ItemType Directory -Force $out | Out-Null

$ico = Join-Path $out 'Doppel.ico'
& (Join-Path $root 'make-icon.ps1') -OutFile $ico   # from ..\assets\doppel-icon-1024.png

$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
if (-not (Test-Path $csc)) { throw "C# compiler not found at $csc (.NET Framework 4.x is part of Windows 10/11)" }
& $csc /nologo /target:winexe /optimize+ /platform:anycpu `
    /win32icon:"$ico" /reference:System.Windows.Forms.dll /reference:System.Management.dll `
    /out:"$(Join-Path $out 'Doppel.exe')" "$(Join-Path $root 'Doppel.cs')"
if ($LASTEXITCODE -ne 0) { throw "csc failed ($LASTEXITCODE)" }
Get-Item (Join-Path $out 'Doppel.exe') | Select-Object FullName, Length
