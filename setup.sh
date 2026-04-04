#!/bin/bash
# ================================================================
# SathChalo — Project Setup Script
# ================================================================
set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${GREEN}"
echo "  ███████╗ █████╗ ████████╗██╗  ██╗ ██████╗██╗  ██╗ █████╗ ██╗      ██████╗ "
echo "  ██╔════╝██╔══██╗╚══██╔══╝██║  ██║██╔════╝██║  ██║██╔══██╗██║     ██╔═══██╗"
echo "  ███████╗███████║   ██║   ███████║██║     ███████║███████║██║     ██║   ██║"
echo "  ╚════██║██╔══██║   ██║   ██╔══██║██║     ██╔══██║██╔══██║██║     ██║   ██║"
echo "  ███████║██║  ██║   ██║   ██║  ██║╚██████╗██║  ██║██║  ██║███████╗╚██████╔╝"
echo "  ╚══════╝╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝ ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝ ╚═════╝ "
echo -e "${NC}"
echo -e "${BLUE}  Peer-to-Peer Ride Sharing — साथ चलो${NC}"
echo ""

echo -e "${YELLOW}Step 1: Installing Flutter dependencies...${NC}"
flutter pub get
echo -e "${GREEN}✓ Dependencies installed${NC}"
echo ""

echo -e "${YELLOW}Step 2: Checking Flutter doctor...${NC}"
flutter doctor --no-version-check
echo ""

echo -e "${YELLOW}Step 3: iOS setup (if on macOS)...${NC}"
if [[ "$OSTYPE" == "darwin"* ]]; then
  echo "Running pod install..."
  cd ios && pod install && cd ..
  echo -e "${GREEN}✓ iOS pods installed${NC}"
else
  echo "Skipping iOS setup (not macOS)"
fi
echo ""

echo -e "${GREEN}✅ Setup complete!${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo "  1. Go to Supabase dashboard → Database → Extensions → Enable PostGIS"
echo "  2. Run SQL: supabase/migrations/001_initial_schema.sql"
echo "  3. Run: flutter run"
echo ""
echo -e "${YELLOW}⚡ Make sure Google Maps APIs are enabled in Google Cloud Console:${NC}"
echo "   - Maps SDK for Android"
echo "   - Maps SDK for iOS"
echo "   - Directions API"
echo "   - Places API"
echo "   - Geocoding API"
echo ""
