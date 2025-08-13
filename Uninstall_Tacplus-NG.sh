#!/bin/bash

# Uninstall script for tac_plus-ng
# Removes binary files and libraries but preserves /etc/tacplus-ng/ configuration

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== tac_plus-ng Uninstall Script ===${NC}"
echo ""

# Check if running as root or with sudo
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root or with sudo${NC}" 
   exit 1
fi

# Files and directories to remove
BINARIES=(
    "/usr/local/sbin/tac_plus-ng"
    "/usr/local/sbin/ldapmavis-mt"
)

DIRECTORIES=(
    "/usr/local/lib/mavis"
)

# Show what will be removed
echo "The following files and directories will be removed:"
echo ""
for bin in "${BINARIES[@]}"; do
    if [[ -f "$bin" ]]; then
        echo -e "  ${RED}[FILE]${NC} $bin"
    fi
done

for dir in "${DIRECTORIES[@]}"; do
    if [[ -d "$dir" ]]; then
        echo -e "  ${RED}[DIR]${NC}  $dir"
    fi
done

echo ""
echo -e "${GREEN}The following will be PRESERVED:${NC}"
echo -e "  ${GREEN}[DIR]${NC}  /etc/tacplus-ng/ (if it exists)"
echo ""

# Confirmation prompt
read -p "Do you want to proceed with the uninstallation? (y/N): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Uninstallation cancelled."
    exit 0
fi

echo ""
echo "Starting uninstallation..."

# Remove binary files
for bin in "${BINARIES[@]}"; do
    if [[ -f "$bin" ]]; then
        echo -n "Removing $bin... "
        rm -f "$bin"
        echo -e "${GREEN}done${NC}"
    else
        echo -e "Skipping $bin... ${YELLOW}not found${NC}"
    fi
done

# Remove directories
for dir in "${DIRECTORIES[@]}"; do
    if [[ -d "$dir" ]]; then
        echo -n "Removing $dir... "
        rm -rf "$dir"
        echo -e "${GREEN}done${NC}"
    else
        echo -e "Skipping $dir... ${YELLOW}not found${NC}"
    fi
done

# Run ldconfig to update library cache
echo -n "Updating library cache... "
ldconfig
echo -e "${GREEN}done${NC}"

echo ""
echo -e "${GREEN}=== Uninstallation Complete ===${NC}"

# Check if config directory exists and notify user
if [[ -d "/etc/tacplus-ng" ]]; then
    echo ""
    echo -e "${YELLOW}Note:${NC} Configuration directory /etc/tacplus-ng/ has been preserved."
    echo "      Remove it manually if you want to completely purge the installation:"
    echo "      sudo rm -rf /etc/tacplus-ng"
fi

echo ""
echo "tac_plus-ng has been successfully uninstalled."

