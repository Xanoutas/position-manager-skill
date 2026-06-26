#!/bin/bash
set -e

echo "📦 Installing position-manager-skill..."

# Check Node.js
if ! command -v node &> /dev/null; then
  echo "❌ Node.js not found. Install Node.js >= 18 first."
  exit 1
fi

NODE_VERSION=$(node -v | cut -d'v' -f2 | cut -d'.' -f1)
if [ "$NODE_VERSION" -lt 18 ]; then
  echo "❌ Node.js >= 18 required. Found: $(node -v)"
  exit 1
fi

# Install dependencies
npm install

# Create DB directory
mkdir -p "$HOME/.position-manager"

# Copy env example if not exists
if [ ! -f .env ]; then
  cp .env.example .env
  echo "📝 Created .env — please fill in RPC_URL and WALLET_ADDRESS"
fi

# Build
npm run build 2>/dev/null || echo "⚠️ Build step skipped (TypeScript not configured yet)"

echo ""
echo "✅ Installation complete!"
echo ""
echo "Next steps:"
echo "  1. Edit .env with your RPC_URL and WALLET_ADDRESS"
echo "  2. Run: npm run positions"
echo ""
