#!/bin/bash

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 스크립트 실행 디렉토리
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}   Staging Database Reset Script${NC}"
echo -e "${YELLOW}========================================${NC}"

# 스테이징 환경 확인
echo -e "\n${RED}⚠️  WARNING: This will DELETE ALL DATA in the staging database!${NC}"
echo -e "${YELLOW}This script is intended for staging environment only.${NC}"
read -p "Are you sure you want to reset the staging database? (yes/no): " confirmation

if [ "$confirmation" != "yes" ]; then
    echo -e "${RED}Database reset cancelled.${NC}"
    exit 0
fi

# 디렉토리 이동
cd $SCRIPT_DIR

# 1. 데이터베이스 백업 (안전을 위해)
echo -e "\n${YELLOW}[1/4] Backing up current database...${NC}"
BACKUP_DIR="$SCRIPT_DIR/storage/backups"
mkdir -p $BACKUP_DIR
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

if [ -f "$SCRIPT_DIR/storage/production.sqlite3" ]; then
    cp "$SCRIPT_DIR/storage/production.sqlite3" "$BACKUP_DIR/staging_reset_${TIMESTAMP}.sqlite3"
    echo -e "${GREEN}Database backed up to: staging_reset_${TIMESTAMP}.sqlite3${NC}"
else
    echo -e "${YELLOW}No existing database file found.${NC}"
fi

# 2. 데이터베이스 삭제 및 재생성
echo -e "\n${YELLOW}[2/4] Resetting database...${NC}"
# Rails 프로덕션 환경 보호 비활성화
export DISABLE_DATABASE_ENVIRONMENT_CHECK=1
RAILS_ENV=production bundle exec rails db:drop 2>/dev/null
RAILS_ENV=production bundle exec rails db:create
RAILS_ENV=production bundle exec rails db:migrate

if [ $? -ne 0 ]; then
    echo -e "${RED}Database migration failed!${NC}"
    exit 1
fi

# 3. 시드 데이터 로드 (스테이징용 시드 사용)
echo -e "\n${YELLOW}[3/4] Loading staging seed data...${NC}"
RAILS_ENV=production bundle exec rails runner "load Rails.root.join('db/seeds_staging.rb')"

if [ $? -ne 0 ]; then
    echo -e "${RED}Seed data loading failed!${NC}"
    exit 1
fi

# 4. 서비스 재시작
echo -e "\n${YELLOW}[4/4] Restarting application service...${NC}"

# systemd 서비스가 있는지 확인
if systemctl list-units --full -all | grep -Fq "testexp-puma.service"; then
    sudo systemctl restart testexp-puma
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Puma service restarted successfully.${NC}"
        
        # 서비스 상태 확인
        sleep 3
        echo -e "\n${YELLOW}Service status:${NC}"
        sudo systemctl status testexp-puma --no-pager | head -n 10
    else
        echo -e "${RED}Failed to restart Puma service!${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}No systemd service found. Please restart Puma manually.${NC}"
fi

# 헬스 체크
echo -e "\n${YELLOW}Running health check...${NC}"
sleep 2

PORT=${PORT:-3001}
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$PORT 2>/dev/null)
if [ $HTTP_STATUS -eq 200 ] || [ $HTTP_STATUS -eq 302 ] || [ $HTTP_STATUS -eq 301 ]; then
    echo -e "${GREEN}✓ Application is responding (HTTP $HTTP_STATUS)${NC}"
else
    echo -e "${RED}✗ Application health check failed (HTTP $HTTP_STATUS)${NC}"
fi

# 완료
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}   Database reset completed!${NC}"
echo -e "${GREEN}========================================${NC}"

echo -e "\n${YELLOW}Sample login credentials:${NC}"
echo "- 대표이사: jaypark@tlx.kr / hcghcghcg"
echo "- CPO: sabaek@tlx.kr / hcghcghcg"
echo "- hunel COO: ymkim@tlx.kr / hcghcghcg"
echo "- Admin: hjlee@tlx.kr / hcghcghcg"
echo "- talenx BU 직원: jjbaek@tlx.kr / hcghcghcg"