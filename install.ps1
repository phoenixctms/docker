# Download Phoenix CTMS Compose and start it with the published images.
$ErrorActionPreference = 'Stop'

$Ref = if ($env:PHOENIX_REF) { $env:PHOENIX_REF } else { 'master' }
$Dest = if ($env:PHOENIX_HOME) { $env:PHOENIX_HOME } else { Join-Path $env:USERPROFILE 'phoenixctms' }
$Url = "https://github.com/phoenixctms/docker/archive/refs/heads/$Ref.zip"

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
  Write-Error 'Install WSL2 and Docker Desktop, then run this again.'
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

  # PHOENIX_SIGNUP is the switch. Compose itself only honors COMPOSE_PROFILES.
  $lines = [System.IO.File]::ReadAllLines($envFile)
  $signupFlag = $env:PHOENIX_SIGNUP
  if (-not $env:PHOENIX_SIGNUP) {
    $match = $lines | Where-Object { $_ -match '^PHOENIX_SIGNUP=' } | Select-Object -Last 1
    if ($match) { $signupFlag = ($match -replace '^PHOENIX_SIGNUP=', '').Trim() }
  }
  $lines = @($lines | Where-Object { $_ -notmatch '^COMPOSE_PROFILES=' })
  if (-not $signupFlag -or $signupFlag -eq 'true' -or $signupFlag -eq '1') {
    $lines += 'COMPOSE_PROFILES=signup'
    Write-Host 'Signup is enabled.'
  } else {
    Write-Host "Signup is off (PHOENIX_SIGNUP=$signupFlag)."
  }
  $utf8 = New-Object System.Text.UTF8Encoding $false
  [System.IO.File]::WriteAllLines($envFile, $lines, $utf8)

  Write-Host "Starting in $Dest"
  Write-Host 'db-init prints the UI URL and the phoenix password.'
  docker compose pull
  # Signup waits for db-init to exit, so a plain `up -d` hides the init log until that container is done.
  $upServices = @('db', 'db-migrate', 'ctsms')
  if (-not $signupFlag -or $signupFlag -eq 'true' -or $signupFlag -eq '1') {
    $upServices += 'redis'
  }
  docker compose up -d --no-build @upServices
  docker compose up -d --no-build --no-deps db-init
  $initId = @(docker compose ps -aq db-init) | Select-Object -First 1
  if (-not $initId) { throw 'db-init did not start.' }
  docker logs -f $initId.Trim()
  $initStatus = (docker inspect -f '{{.State.ExitCode}}' $initId.Trim()).Trim()
  if ($initStatus -ne '0') { throw "db-init exited with status $initStatus." }
  if (-not $signupFlag -or $signupFlag -eq 'true' -or $signupFlag -eq '1') {
    docker compose up -d --no-build signup
    $signupPort = ($lines | Where-Object { $_ -match '^PHOENIX_SIGNUP_HTTP_PORT=' } | Select-Object -Last 1)
    if ($signupPort) { $signupPort = ($signupPort -replace '^PHOENIX_SIGNUP_HTTP_PORT=', '').Trim() }
    if (-not $signupPort) { $signupPort = '3000' }
    Write-Host "Signup: http://localhost:$signupPort"
  }
} finally {
  if (Test-Path $tmp) { Remove-Item -Recurse -Force $tmp }
}
