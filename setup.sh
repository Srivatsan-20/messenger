#!/bin/bash

# Oodaa Messenger Setup Script
# This script sets up the development environment for the Oodaa Messenger app

set -e

echo "🚀 Setting up Oodaa Messenger..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if Flutter is installed
check_flutter() {
    print_status "Checking Flutter installation..."
    if command -v flutter &> /dev/null; then
        FLUTTER_VERSION=$(flutter --version | head -n 1)
        print_success "Flutter found: $FLUTTER_VERSION"
    else
        print_error "Flutter is not installed or not in PATH"
        print_status "Please install Flutter from https://flutter.dev/docs/get-started/install"
        exit 1
    fi
}

# Check if Node.js is installed
check_node() {
    print_status "Checking Node.js installation..."
    if command -v node &> /dev/null; then
        NODE_VERSION=$(node --version)
        print_success "Node.js found: $NODE_VERSION"
    else
        print_error "Node.js is not installed or not in PATH"
        print_status "Please install Node.js from https://nodejs.org/"
        exit 1
    fi
}

# Install Flutter dependencies
install_flutter_deps() {
    print_status "Installing Flutter dependencies..."
    flutter pub get
    print_success "Flutter dependencies installed"
}

# Generate Hive adapters
generate_hive_adapters() {
    print_status "Generating Hive adapters..."
    flutter packages pub run build_runner build --delete-conflicting-outputs
    print_success "Hive adapters generated"
}

# Setup signaling server
setup_signaling_server() {
    print_status "Setting up signaling server..."
    cd signaling_server
    
    if [ ! -d "node_modules" ]; then
        print_status "Installing Node.js dependencies..."
        npm install
        print_success "Node.js dependencies installed"
    else
        print_status "Node.js dependencies already installed"
    fi
    
    cd ..
}

# Create necessary directories
create_directories() {
    print_status "Creating necessary directories..."
    
    # Create assets directories
    mkdir -p assets/images
    mkdir -p assets/icons
    mkdir -p assets/fonts
    
    # Create platform-specific directories if they don't exist
    mkdir -p android/app/src/main/res/mipmap-hdpi
    mkdir -p android/app/src/main/res/mipmap-mdpi
    mkdir -p android/app/src/main/res/mipmap-xhdpi
    mkdir -p android/app/src/main/res/mipmap-xxhdpi
    mkdir -p android/app/src/main/res/mipmap-xxxhdpi
    
    mkdir -p ios/Runner/Assets.xcassets/AppIcon.appiconset
    
    print_success "Directories created"
}

# Check Android setup
check_android() {
    print_status "Checking Android setup..."
    
    if command -v adb &> /dev/null; then
        print_success "Android Debug Bridge (adb) found"
    else
        print_warning "Android Debug Bridge (adb) not found"
        print_status "Make sure Android SDK is installed and adb is in PATH"
    fi
    
    # Check for connected devices
    DEVICES=$(adb devices | grep -v "List of devices" | grep "device$" | wc -l)
    if [ $DEVICES -gt 0 ]; then
        print_success "$DEVICES Android device(s) connected"
    else
        print_warning "No Android devices connected"
    fi
}

# Check iOS setup (macOS only)
check_ios() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        print_status "Checking iOS setup..."
        
        if command -v xcrun &> /dev/null; then
            print_success "Xcode command line tools found"
        else
            print_warning "Xcode command line tools not found"
            print_status "Install Xcode from the App Store"
        fi
        
        if command -v pod &> /dev/null; then
            print_success "CocoaPods found"
        else
            print_warning "CocoaPods not found"
            print_status "Install CocoaPods: sudo gem install cocoapods"
        fi
    else
        print_status "Skipping iOS setup (not on macOS)"
    fi
}

# Run Flutter doctor
run_flutter_doctor() {
    print_status "Running Flutter doctor..."
    flutter doctor
}

# Create configuration template
create_config_template() {
    print_status "Creating configuration template..."
    
    cat > config.template.dart << EOF
// Configuration Template for Oodaa Messenger
// Copy this file to lib/config.dart and update the values

class AppConfig {
  // Signaling Server Configuration
  static const String signalingServerUrl = 'ws://your-server.com:3001';
  
  // STUN/TURN Server Configuration
  static const List<Map<String, dynamic>> iceServers = [
    {'urls': 'stun:stun.l.google.com:19302'},
    {'urls': 'stun:stun1.l.google.com:19302'},
    // Add your TURN servers here:
    // {
    //   'urls': 'turn:your-turn-server.com:3478',
    //   'username': 'your-username',
    //   'credential': 'your-password'
    // }
  ];
  
  // App Configuration
  static const String appName = 'Oodaa Messenger';
  static const String appVersion = '1.0.0';
  
  // Security Configuration
  static const int autoLockTimeoutSeconds = 300; // 5 minutes
  static const bool biometricAuthEnabled = true;
  
  // Feature Flags
  static const bool enableOfflineMessaging = true;
  static const bool enableVoiceMessages = false; // Coming soon
  static const bool enableVideoMessages = false; // Coming soon
  static const bool enableGroupMessaging = false; // Coming soon
}
EOF
    
    print_success "Configuration template created: config.template.dart"
    print_warning "Copy config.template.dart to lib/config.dart and update the values"
}

# Main setup function
main() {
    echo "🔐 Oodaa Messenger - Private P2P Messaging App"
    echo "=============================================="
    echo ""
    
    check_flutter
    check_node
    create_directories
    install_flutter_deps
    generate_hive_adapters
    setup_signaling_server
    check_android
    check_ios
    create_config_template
    
    echo ""
    print_success "Setup completed successfully! 🎉"
    echo ""
    echo "📋 Next Steps:"
    echo "1. Copy config.template.dart to lib/config.dart and update configuration"
    echo "2. Deploy the signaling server: cd signaling_server && npm start"
    echo "3. Update signaling server URL in lib/config.dart"
    echo "4. Add app icons to assets/icons/"
    echo "5. Configure STUN/TURN servers for better connectivity"
    echo "6. Run the app: flutter run"
    echo ""
    echo "📖 Documentation:"
    echo "- README.md - Complete setup and deployment guide"
    echo "- signaling_server/README.md - Signaling server documentation"
    echo ""
    echo "🔧 Development Commands:"
    echo "- flutter run - Run the app"
    echo "- flutter test - Run tests"
    echo "- flutter build apk - Build Android APK"
    echo "- flutter build ios - Build iOS app"
    echo ""
    
    run_flutter_doctor
}

# Run main function
main "$@"
