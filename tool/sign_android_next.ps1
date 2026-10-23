param(
 [Parameter(Mandatory=$true)][string]$InputApk,
 [Parameter(Mandatory=$true)][string]$OutputApk,
 [Parameter(Mandatory=$true)][string]$SigningDirectory,
 [Parameter(Mandatory=$true)][string]$AndroidBuildTools
)
$ErrorActionPreference = 'Stop'
$taskKey = Join-Path $SigningDirectory 'release.p12'
$taskPassword = Join-Path $SigningDirectory 'signing.password'
if (!(Test-Path -LiteralPath $InputApk)) { throw 'Input APK missing' }
if ((Test-Path -LiteralPath $taskKey) -ne (Test-Path -LiteralPath $taskPassword)) { throw 'Incomplete signing identity. Restore its matching key and password; do not replace it.' }
New-Item -ItemType Directory -Path $SigningDirectory -Force | Out-Null
if (!(Test-Path -LiteralPath $taskKey)) {
 $taskBytes = [byte[]]::new(48)
 [Security.Cryptography.RandomNumberGenerator]::Fill($taskBytes)
 [IO.File]::WriteAllText($taskPassword, [Convert]::ToBase64String($taskBytes))
 & "$env:JAVA_HOME/bin/keytool.exe" -genkeypair -keystore $taskKey -storetype PKCS12 -alias barknote-next -keyalg RSA -keysize 3072 -validity 10000 -dname 'CN=Bark Note Next, OU=Local Builds, O=Bark Note, C=KR' -storepass:file $taskPassword -keypass:file $taskPassword
 if ($LASTEXITCODE -ne 0) { throw 'Key creation failed; preserve the signing directory for inspection.' }
}
& (Join-Path $AndroidBuildTools 'apksigner.bat') sign --ks $taskKey --ks-key-alias barknote-next --ks-pass "file:$taskPassword" --key-pass "file:$taskPassword" --out $OutputApk $InputApk
if ($LASTEXITCODE -ne 0) { throw 'Signing failed' }
& (Join-Path $AndroidBuildTools 'apksigner.bat') verify --verbose --print-certs $OutputApk
if ($LASTEXITCODE -ne 0) { throw 'Signature verification failed' }
