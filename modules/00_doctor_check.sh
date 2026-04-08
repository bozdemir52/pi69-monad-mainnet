#!/bin/bash
set -e
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

echo -e "${YELLOW}🔍 Scanning the system for Mainnet standards...${NC}"

KERNEL_VER=$(uname -r)
if [[ "$KERNEL_VER" == *"6.8.0-56"* || "$KERNEL_VER" == *"6.8.0-57"* || "$KERNEL_VER" == *"6.8.0-58"* || "$KERNEL_VER" == *"6.8.0-59"* ]]; then
    echo -e "${RED}❌ CRITICAL ERROR: You are on a banned Kernel version ($KERNEL_VER). Installation aborted!${NC}"
    exit 1
fi

CPU_CORES=$(nproc)
if [ "$CPU_CORES" -lt 16 ]; then
    echo -e "${RED}❌ CRITICAL ERROR: Only $CPU_CORES CPU cores found. A minimum of 16 is required!${NC}"
    exit 1
fi

echo -e "${GREEN}🎯 System check-up passed successfully.${NC}"
