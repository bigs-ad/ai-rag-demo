param(
    [string]$HostName = "124.220.42.2",
    [string]$User = "ubuntu",
    [string]$JarPath = "target/ai-rag-demo-0.0.1-SNAPSHOT.jar",
    [string]$EnvPath = ".env",
    [string]$AppName = "ai-rag-demo",
    [string]$RemoteDir = "/opt/ai-rag-demo"
)

$ErrorActionPreference = "Stop"

function Require-File {
    param([string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "File not found: $Path"
    }
}

Require-File $JarPath
Require-File $EnvPath

$deployDir = Join-Path $PSScriptRoot "..\target\deploy"
New-Item -ItemType Directory -Force -Path $deployDir | Out-Null

$servicePath = Join-Path $deployDir "$AppName.service"
$remoteScriptPath = Join-Path $deployDir "$AppName-remote-deploy.sh"
@"
[Unit]
Description=$AppName Spring Boot service
After=network-online.target
Wants=network-online.target

[Service]
User=$User
WorkingDirectory=$RemoteDir
EnvironmentFile=/etc/$AppName.env
ExecStart=/usr/bin/java -jar $RemoteDir/$AppName.jar
SuccessExitStatus=143
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
"@ | Set-Content -LiteralPath $servicePath -Encoding ascii

@"
set -euo pipefail

if ! command -v java >/dev/null 2>&1; then
  sudo apt-get update
  sudo apt-get install -y openjdk-17-jre-headless
fi

sudo mkdir -p "$RemoteDir"
sudo install -o "$User" -g "$User" -m 755 /tmp/$AppName.jar "$RemoteDir/$AppName.jar"
sudo install -o root -g root -m 600 /tmp/$AppName.env /etc/$AppName.env
sudo install -o root -g root -m 644 /tmp/$AppName.service /etc/systemd/system/$AppName.service

sudo systemctl daemon-reload
sudo systemctl enable $AppName
sudo systemctl restart $AppName

sleep 3
sudo systemctl --no-pager --full status $AppName
"@ -replace "`r`n", "`n" | Set-Content -LiteralPath $remoteScriptPath -Encoding ascii -NoNewline

$remote = "$User@$HostName"
$remoteTmp = "${remote}:/tmp"

Write-Host "Uploading jar to $remoteTmp/$AppName.jar ..."
scp -o StrictHostKeyChecking=accept-new $JarPath "$remoteTmp/$AppName.jar"

Write-Host "Uploading environment file to $remoteTmp/$AppName.env ..."
scp -o StrictHostKeyChecking=accept-new $EnvPath "$remoteTmp/$AppName.env"

Write-Host "Uploading systemd service to $remoteTmp/$AppName.service ..."
scp -o StrictHostKeyChecking=accept-new $servicePath "$remoteTmp/$AppName.service"

Write-Host "Uploading remote deploy script to $remoteTmp/$AppName-remote-deploy.sh ..."
scp -o StrictHostKeyChecking=accept-new $remoteScriptPath "$remoteTmp/$AppName-remote-deploy.sh"

Write-Host "Configuring and starting service on $remote ..."
ssh -t -o StrictHostKeyChecking=accept-new $remote "bash /tmp/$AppName-remote-deploy.sh"

Write-Host ""
Write-Host "Deployment finished."
Write-Host "Health check: http://$HostName`:8080/stream/health"
Write-Host "Page:         http://$HostName`:8080/"
