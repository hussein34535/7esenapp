# deploy.ps1
param (
    [Parameter(Mandatory=$true)]
    [string]$ServerIP,

    [Parameter(Mandatory=$true)]
    [string]$SshKeyPath,

    [string]$RemoteUser = "ubuntu"
)

$RemotePath = "/var/www/hesen_app"
$LocalBuildPath = "..\build\web"

Write-Host "🚧 Building Flutter Web App..." -ForegroundColor Cyan
cd ..
flutter build web --release
if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Build failed!" -ForegroundColor Red
    exit 1
}
cd deployment

Write-Host "🚀 Preparing Server Directory..." -ForegroundColor Cyan
ssh -i $SshKeyPath -o StrictHostKeyChecking=no "$RemoteUser@$ServerIP" "sudo mkdir -p $RemotePath && sudo chown -R $RemoteUser:$RemoteUser $RemotePath"

Write-Host "Ep Uploading Build Files..." -ForegroundColor Cyan
scp -i $SshKeyPath -r "$LocalBuildPath\*" "$RemoteUser@$ServerIP:$RemotePath"

Write-Host "🔧 Configuring Nginx..." -ForegroundColor Cyan
scp -i $SshKeyPath "nginx.conf" "$RemoteUser@$ServerIP:/tmp/hesen_app.conf"
ssh -i $SshKeyPath "$RemoteUser@$ServerIP" "sudo mv /tmp/hesen_app.conf /etc/nginx/sites-available/hesen_app && sudo ln -sf /etc/nginx/sites-available/hesen_app /etc/nginx/sites-enabled/ && sudo nginx -t && sudo systemctl restart nginx"

Write-Host "✅ Deployment Complete! Visit http://$ServerIP" -ForegroundColor Green
