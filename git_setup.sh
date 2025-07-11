#!/bin/bash

# Oodaa Messenger - Git Repository Setup Script
# This script helps you create and push the repository to GitHub

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

echo "🚀 Oodaa Messenger - Git Repository Setup"
echo "=========================================="
echo ""

# Check if git is installed
if ! command -v git &> /dev/null; then
    print_error "Git is not installed. Please install Git first."
    exit 1
fi

print_success "Git is installed"

# Check if we're in the right directory
if [ ! -f "pubspec.yaml" ]; then
    print_error "This doesn't appear to be the Flutter project directory."
    print_status "Please run this script from the oodaa_messenger directory."
    exit 1
fi

print_success "Found Flutter project"

# Get GitHub username
echo ""
print_status "Setting up GitHub repository..."
read -p "Enter your GitHub username: " GITHUB_USERNAME

if [ -z "$GITHUB_USERNAME" ]; then
    print_error "GitHub username is required"
    exit 1
fi

# Repository name
REPO_NAME="oodaa-messenger"
GITHUB_URL="https://github.com/$GITHUB_USERNAME/$REPO_NAME.git"

print_status "Repository will be created at: $GITHUB_URL"

# Check if git repo already exists
if [ -d ".git" ]; then
    print_warning "Git repository already exists"
    read -p "Do you want to continue? This will add a new remote. (y/N): " CONTINUE
    if [[ ! $CONTINUE =~ ^[Yy]$ ]]; then
        print_status "Aborted by user"
        exit 0
    fi
else
    print_status "Initializing Git repository..."
    git init
    print_success "Git repository initialized"
fi

# Copy README for GitHub
print_status "Preparing repository files..."
cp README_GITHUB.md README.md

# Create config template if it doesn't exist
if [ ! -f "lib/config.dart" ]; then
    if [ -f "config.template.dart" ]; then
        cp config.template.dart lib/config.dart
        print_warning "Created lib/config.dart from template - please update with your settings"
    fi
fi

# Add all files
print_status "Adding files to Git..."
git add .

# Check if there are any changes to commit
if git diff --staged --quiet; then
    print_warning "No changes to commit"
else
    # Create commit
    print_status "Creating initial commit..."
    git commit -m "Initial commit: Complete Oodaa Messenger implementation

🔐 Private P2P messaging with Signal-level encryption

Features:
- End-to-end encrypted messaging using Signal protocol (X3DH + Double Ratchet)
- Peer-to-peer communication via WebRTC (no message servers)
- QR code contact sharing (no phone numbers required)
- Offline messaging via Bluetooth/Wi-Fi Direct
- Encrypted file sharing and media transfer
- Disappearing messages with expiration
- PIN/biometric app lock with auto-lock
- Secure local storage with Hive + Flutter Secure Storage

Security:
- AES-256-GCM encryption for all messages
- Curve25519 key pairs for identity
- Perfect forward secrecy
- Zero data collection
- No cloud storage or servers storing messages
- Local-only contact lists and message history

Tech Stack:
- Flutter app with Material Design 3
- Node.js signaling server (for peer discovery only)
- WebRTC for P2P communication
- Signal Protocol for encryption
- Hive + Flutter Secure Storage for local data

Ready for production deployment!"

    print_success "Initial commit created"
fi

# Set main branch
git branch -M main

# Add remote origin
print_status "Adding GitHub remote..."
if git remote get-url origin &> /dev/null; then
    print_warning "Remote 'origin' already exists"
    git remote set-url origin $GITHUB_URL
    print_status "Updated remote origin URL"
else
    git remote add origin $GITHUB_URL
    print_success "Added remote origin"
fi

echo ""
print_status "Repository setup complete!"
echo ""
print_warning "NEXT STEPS:"
echo "1. Go to GitHub.com and create a new repository named '$REPO_NAME'"
echo "2. Choose Public or Private visibility"
echo "3. DON'T initialize with README (we have our own)"
echo "4. After creating the repository, run:"
echo ""
echo "   git push -u origin main"
echo ""
print_status "Or run this command now if you've already created the GitHub repository:"
echo ""
echo -e "${GREEN}git push -u origin main${NC}"
echo ""

# Ask if user wants to push now
read -p "Have you created the GitHub repository? Push now? (y/N): " PUSH_NOW

if [[ $PUSH_NOW =~ ^[Yy]$ ]]; then
    print_status "Pushing to GitHub..."
    
    if git push -u origin main; then
        print_success "Successfully pushed to GitHub!"
        echo ""
        print_success "🎉 Your repository is now available at:"
        echo "   https://github.com/$GITHUB_USERNAME/$REPO_NAME"
        echo ""
        print_status "Next steps:"
        echo "- Update lib/config.dart with your server settings"
        echo "- Deploy the signaling server (see DEPLOYMENT_GUIDE.md)"
        echo "- Test the app on your devices"
        echo "- Submit to app stores when ready"
    else
        print_error "Failed to push to GitHub"
        print_status "Make sure you've created the repository on GitHub first"
        print_status "Then run: git push -u origin main"
    fi
else
    print_status "Repository prepared but not pushed"
    print_status "Run 'git push -u origin main' when you're ready"
fi

echo ""
print_success "Git setup complete! 🚀"
