#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
IOS_DIR="$SCRIPT_DIR/../apps/ios"
ENV_FILE="$IOS_DIR/.env"
ENV_EXAMPLE="$IOS_DIR/.env.example"

echo "Setting up Fastlane signing for Pomafocus..."
echo ""

# Check if .env file exists
if [ ! -f "$ENV_FILE" ]; then
    echo "Error: .env file not found!"
    echo ""
    echo "Please create apps/ios/.env with your Apple Developer credentials."
    echo "You can copy from the template:"
    echo ""
    echo "  cp apps/ios/.env.example apps/ios/.env"
    echo ""
    echo "Then edit apps/ios/.env with your values."
    exit 1
fi

cd "$IOS_DIR"

# Check if bundler is installed
if ! command -v bundle &> /dev/null; then
    echo "Installing bundler..."
    gem install bundler
fi

# Install Fastlane dependencies
echo "Installing Fastlane..."
bundle install

# Run the signing setup
echo ""
echo "Running signing setup..."
bundle exec fastlane setup_signing

echo ""
echo "Done! Now run: ./Scripts/generate_ios_project.sh"
