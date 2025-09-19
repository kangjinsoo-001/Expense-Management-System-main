#!/bin/bash

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}   Seed Data Loader${NC}"
echo -e "${BLUE}========================================${NC}"

# 환경 확인
if [ "$RAILS_ENV" = "production" ]; then
    SEED_TYPE="staging"
    SEED_FILE="db/seeds_staging.rb"
else
    SEED_TYPE="development"
    SEED_FILE="standard db:seed"
fi

echo -e "\n${YELLOW}Environment: ${RAILS_ENV:-development}${NC}"
echo -e "${YELLOW}Seed type: ${SEED_TYPE}${NC}"

# 옵션 파싱
RESET_DB=false
STAGING=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --reset|-r)
            RESET_DB=true
            shift
            ;;
        --staging|-s)
            STAGING=true
            shift
            ;;
        --help|-h)
            echo -e "\n${GREEN}Usage:${NC}"
            echo "  ./load_seeds.sh [options]"
            echo ""
            echo -e "${GREEN}Options:${NC}"
            echo "  -r, --reset    Reset database before seeding"
            echo "  -s, --staging  Use staging seeds (minimal data)"
            echo "  -h, --help     Show this help message"
            echo ""
            echo -e "${GREEN}Examples:${NC}"
            echo "  ./load_seeds.sh           # Load development seeds"
            echo "  ./load_seeds.sh -r        # Reset DB and load development seeds"
            echo "  ./load_seeds.sh -s        # Load staging seeds (minimal)"
            echo "  ./load_seeds.sh -r -s     # Reset DB and load staging seeds"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# DB 리셋 옵션
if [ "$RESET_DB" = true ]; then
    echo -e "\n${YELLOW}Resetting database...${NC}"
    rails db:drop
    rails db:create
    rails db:migrate
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}Database reset failed!${NC}"
        exit 1
    fi
    echo -e "${GREEN}Database reset completed.${NC}"
fi

# 시드 로드
if [ "$STAGING" = true ]; then
    echo -e "\n${YELLOW}Loading STAGING seeds (minimal data)...${NC}"
    rails runner "load Rails.root.join('db/seeds_staging.rb')"
else
    echo -e "\n${YELLOW}Loading DEVELOPMENT seeds (full data with samples)...${NC}"
    rails db:seed
fi

if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}========================================${NC}"
    echo -e "${GREEN}   Seed loading completed!${NC}"
    echo -e "${GREEN}========================================${NC}"
    
    # 데이터 요약 표시
    echo -e "\n${BLUE}Data Summary:${NC}"
    rails runner "
        puts '- Organizations: ' + Organization.count.to_s
        puts '- Users: ' + User.count.to_s
        puts '- Expense Codes: ' + ExpenseCode.count.to_s
        puts '- Cost Centers: ' + CostCenter.count.to_s
        puts '- Expense Sheets: ' + ExpenseSheet.count.to_s
        puts '- Expense Items: ' + ExpenseItem.count.to_s
    "
else
    echo -e "${RED}Seed loading failed!${NC}"
    exit 1
fi