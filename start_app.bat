@echo off
echo 🚀 Starting Oodaa Messenger Full Stack...
echo.

echo 📡 Starting signaling server...
start "Signaling Server" cmd /k "cd signaling_server && node server.js"

echo 📱 Waiting 3 seconds for signaling server to start...
timeout /t 3 /nobreak >nul

echo 📱 Starting Flutter app...
start "Flutter App" cmd /k "flutter run -d chrome --web-port=3000"

echo.
echo ✨ Both services are starting...
echo 🌐 Signaling Server: http://localhost:3001
echo 📱 Flutter App: http://localhost:3000
echo.
echo 💡 Close the command windows to stop the services
echo Press any key to exit this launcher...
pause >nul
