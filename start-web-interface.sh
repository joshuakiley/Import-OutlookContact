#!/bin/bash

# Import-OutlookContact Web Interface Startup Script
# Builds and serves the Svelte + TypeScript + TailwindCSS web interface

set -e

echo "🚀 Import-OutlookContact Web Interface"
echo "======================================"

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "❌ Node.js is required but not installed."
    echo "💡 Please install Node.js 18+ from https://nodejs.org/"
    exit 1
fi

# Check Node.js version
NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 18 ]; then
    echo "❌ Node.js version 18+ is required (current: $(node -v))"
    exit 1
fi

echo "✅ Node.js $(node -v) detected"

# Navigate to web-ui directory
cd "$(dirname "$0")/web-ui"

# Install dependencies if needed
if [ ! -d "node_modules" ]; then
    echo "📦 Installing dependencies..."
    npm install
fi

echo "🔨 Building web interface..."
npm run build

echo "🌐 Starting web server..."
echo "🔗 Access the dashboard at: http://localhost:5000"
echo "🛡️ Security features: XSS prevention, CSRF protection, input validation"
echo "📱 Technology stack: Svelte + TailwindCSS + TypeScript"
echo ""
echo "Press Ctrl+C to stop the server..."

# Start the preview server
npm run preview
