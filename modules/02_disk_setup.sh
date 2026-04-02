#!/bin/bash
set -e
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

echo -e "${YELLOW}💾 NVMe Diskler Monad İçin Optimize Ediliyor...${NC}"
NVME_DRIVES=$(lsblk -d -o NAME | grep nvme || true)

for DRIVE in $NVME_DRIVES; do
    SCHEDULER_PATH="/sys/block/$DRIVE/queue/scheduler"
    if [ -f "$SCHEDULER_PATH" ]; then
        echo none | sudo tee "$SCHEDULER_PATH" > /dev/null 2>&1 || echo noop | sudo tee "$SCHEDULER_PATH" > /dev/null 2>&1
    fi
    NR_REQUESTS_PATH="/sys/block/$DRIVE/queue/nr_requests"
    if [ -f "$NR_REQUESTS_PATH" ]; then
        echo 1023 | sudo tee "$NR_REQUESTS_PATH" > /dev/null 2>&1
    fi
done
echo -e "${GREEN}✅ Disk optimizasyonları tamamlandı!${NC}"
