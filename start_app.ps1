# Oodaa Messenger Startup Script
Write-Host "🚀 Starting Oodaa Messenger Full Stack..." -ForegroundColor Green

# Function to start a process in a new window
function Start-ProcessInNewWindow {
    param(
        [string]$FilePath,
        [string[]]$ArgumentList,
        [string]$WorkingDirectory = $PWD,
        [string]$WindowTitle
    )
    
    $processParams = @{
        FilePath = $FilePath
        ArgumentList = $ArgumentList
        WorkingDirectory = $WorkingDirectory
        PassThru = $true
    }
    
    if ($WindowTitle) {
        Write-Host "📡 Starting $WindowTitle..." -ForegroundColor Yellow
    }
    
    return Start-Process @processParams
}

try {
    # Start signaling server
    Write-Host "📡 Starting signaling server..." -ForegroundColor Yellow
    $signalingServer = Start-ProcessInNewWindow -FilePath "node" -ArgumentList @("server.js") -WorkingDirectory ".\signaling_server" -WindowTitle "Signaling Server"
    
    # Wait for signaling server to start
    Start-Sleep -Seconds 3
    
    # Start Flutter app
    Write-Host "📱 Starting Flutter app..." -ForegroundColor Yellow
    $flutterApp = Start-ProcessInNewWindow -FilePath "flutter" -ArgumentList @("run", "-d", "chrome", "--web-port=3000") -WindowTitle "Flutter App"
    
    Write-Host ""
    Write-Host "✨ Both services are starting..." -ForegroundColor Green
    Write-Host "🌐 Signaling Server: http://localhost:3001" -ForegroundColor Cyan
    Write-Host "📱 Flutter App: http://localhost:3000" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "💡 Press any key to stop all services..." -ForegroundColor Gray
    
    # Wait for user input
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    
    # Cleanup
    Write-Host ""
    Write-Host "🛑 Shutting down services..." -ForegroundColor Red
    
    if ($signalingServer -and !$signalingServer.HasExited) {
        Write-Host "📡 Stopping signaling server..." -ForegroundColor Yellow
        Stop-Process -Id $signalingServer.Id -Force -ErrorAction SilentlyContinue
    }
    
    if ($flutterApp -and !$flutterApp.HasExited) {
        Write-Host "📱 Stopping Flutter app..." -ForegroundColor Yellow
        Stop-Process -Id $flutterApp.Id -Force -ErrorAction SilentlyContinue
    }
    
    # Also kill any remaining node or flutter processes
    Get-Process -Name "node" -ErrorAction SilentlyContinue | Where-Object { $_.MainWindowTitle -like "*server*" } | Stop-Process -Force -ErrorAction SilentlyContinue
    Get-Process -Name "flutter" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    
    Write-Host "✅ All services stopped." -ForegroundColor Green
}
catch {
    Write-Host "❌ Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "💡 Make sure Node.js and Flutter are installed and in your PATH." -ForegroundColor Gray
}

Write-Host ""
Write-Host "Press any key to exit..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
