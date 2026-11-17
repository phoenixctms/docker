# Download Phoenix CTMS Compose and start it with the published images.
$ErrorActionPreference = 'Stop'

$Ref = if ($env:PHOENIX_REF) { $env:PHOENIX_REF } else { 'master' }
$Dest = if ($env:PHOENIX_HOME) { $env:PHOENIX_HOME } else { Join-Path $env:USERPROFILE 'phoenixctms' }
$Url = "https://github.com/phoenixctms/docker/archive/refs/heads/$Ref.zip"

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
  Write-Error 'Install Docker Desktop, then run this again.'
}
docker compose version | Out-Null

$tmp = Join-Path ([System.IO.Path]::GetTempPath()) ("phoenixctms-" + [guid]::NewGuid().ToString('n'))
New-Item -ItemType Directory -Path $tmp | Out-Null
try {
  $zip = Join-Path $tmp 'src.zip'
  Write-Host "Downloading Phoenix CTMS Compose ($Ref)..."
  Invoke-WebRequest -Uri $Url -OutFile $zip
  Expand-Archive -Path $zip -DestinationPath $tmp
  $src = Join-Path $tmp "docker-$Ref"
  if (-not (Test-Path (Join-Path $src 'compose.yaml'))) {
    throw 'Download did not contain compose.yaml.'
  }

  New-Item -ItemType Directory -Force -Path $Dest | Out-Null
  Get-ChildItem -Force $Dest | Where-Object { $_.Name -ne '.env' } | Remove-Item -Recurse -Force
  Get-ChildItem -Force $src | Copy-Item -Destination $Dest -Recurse -Force

  $envFile = Join-Path $Dest '.env'
  if (-not (Test-Path $envFile)) {
    $example = [System.IO.File]::ReadAllLines((Join-Path $Dest '.env.example'))
    $example = $example | ForEach-Object {
      $_ -replace '^# (PHOENIX_CTSMS_IMAGE=)', '$1' -replace '^# (PHOENIX_SIGNUP_IMAGE=)', '$1'
    }
    $utf8 = New-Object System.Text.UTF8Encoding $false
    [System.IO.File]::WriteAllLines($envFile, $example, $utf8)
  }

  Set-Location $Dest
  Write-Host "Starting in $Dest"
  Write-Host 'db-init prints the UI URL and the phoenix password.'
  docker compose pull
  docker compose up -d --no-build
  docker compose logs -f db-init
} finally {
  if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
}
