#!/bin/bash

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 스크립트 실행 디렉토리 (프로덕션 환경에서는 경로 수정 필요)
DEPLOY_DIR="$(cd "$(dirname "$0")" && pwd)"

# 옵션 파싱
FORCE_MODE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--force)
            FORCE_MODE=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [options]"
            echo ""
            echo "Options:"
            echo "  -f, --force    원격 리포지토리로 강제 초기화 (로컬 변경사항 삭제)"
            echo "  -h, --help     이 도움말 표시"
            echo ""
            echo "Example:"
            echo "  $0             # 일반 배포"
            echo "  $0 --force     # 원격 내용으로 강제 덮어쓰기"
            exit 0
            ;;
        *)
            echo -e "${RED}알 수 없는 옵션: $1${NC}"
            echo "사용법을 보려면 '$0 --help' 실행"
            exit 1
            ;;
    esac
done

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}   Production Deployment Script${NC}"
if [ "$FORCE_MODE" = true ]; then
    echo -e "${RED}   [강제 모드 활성화]${NC}"
fi
echo -e "${GREEN}========================================${NC}"

# 디렉토리 이동
cd $DEPLOY_DIR

# 강제 모드 처리
if [ "$FORCE_MODE" = true ]; then
    echo -e "\n${RED}⚠️  경고: 강제 모드가 활성화되었습니다!${NC}"
    echo -e "${RED}로컬의 모든 변경사항이 삭제되고 원격 리포지토리 내용으로 덮어씌워집니다.${NC}"
    read -p "정말로 계속하시겠습니까? (yes/no) " -r
    echo
    if [[ ! $REPLY =~ ^[Yy][Ee][Ss]$ ]]; then
        echo -e "${YELLOW}강제 배포가 취소되었습니다.${NC}"
        exit 1
    fi
    
    echo -e "\n${YELLOW}원격 리포지토리로 강제 초기화 중...${NC}"
    
    # 원격 업데이트 가져오기
    git fetch origin main
    
    # 로컬 변경사항 모두 삭제하고 원격으로 리셋
    git reset --hard origin/main
    
    # 추적되지 않은 파일과 디렉토리 정리 (설정 파일 제외)
    echo -e "${YELLOW}추적되지 않은 파일 정리 중...${NC}"
    git clean -fd --exclude=.env --exclude=config/master.key --exclude=storage/
    
    echo -e "${GREEN}✓ 원격 리포지토리 내용으로 강제 초기화 완료${NC}"
    
    # 강제 모드 후 일반 배포 프로세스 계속
    echo -e "\n${YELLOW}이제 일반 배포 프로세스를 진행합니다...${NC}"
fi

# 1. Git 변경사항 확인
echo -e "\n${YELLOW}[1/8] Checking git status...${NC}"
git fetch origin main
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse origin/main)

if [ $LOCAL = $REMOTE ]; then
    echo -e "${GREEN}Already up to date.${NC}"
    read -p "Continue deployment anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${RED}Deployment cancelled.${NC}"
        exit 1
    fi
fi

# 2. 데이터베이스 백업
echo -e "\n${YELLOW}[2/8] Backing up database...${NC}"
BACKUP_DIR="$DEPLOY_DIR/storage/backups"
mkdir -p $BACKUP_DIR
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
if [ -f "$DEPLOY_DIR/storage/production.sqlite3" ]; then
    cp "$DEPLOY_DIR/storage/production.sqlite3" "$BACKUP_DIR/production_${TIMESTAMP}.sqlite3"
    echo -e "${GREEN}Database backed up to: production_${TIMESTAMP}.sqlite3${NC}"
    
    # 7일 이상된 백업 삭제
    find $BACKUP_DIR -name "production_*.sqlite3" -mtime +7 -delete
else
    echo -e "${YELLOW}No database file found to backup.${NC}"
fi

# 3. Git pull
echo -e "\n${YELLOW}[3/8] Pulling latest code...${NC}"
git pull origin main
if [ $? -ne 0 ]; then
    echo -e "${RED}Git pull failed! Aborting deployment.${NC}"
    exit 1
fi

# 4. Bundle install
echo -e "\n${YELLOW}[4/8] Installing dependencies...${NC}"
bundle install --deployment --without development test
if [ $? -ne 0 ]; then
    echo -e "${RED}Bundle install failed! Aborting deployment.${NC}"
    exit 1
fi

# 5. Database migrations
echo -e "\n${YELLOW}[5/8] Running database migrations...${NC}"
RAILS_ENV=production bundle exec rails db:migrate
if [ $? -ne 0 ]; then
    echo -e "${RED}Migration failed! Rolling back...${NC}"
    git reset --hard $LOCAL
    bundle install --deployment --without development test
    echo -e "${RED}Deployment aborted and rolled back.${NC}"
    exit 1
fi

# 6. Assets precompile
echo -e "\n${YELLOW}[6/8] Precompiling assets...${NC}"
RAILS_ENV=production bundle exec rails assets:precompile
if [ $? -ne 0 ]; then
    echo -e "${RED}Asset precompilation failed!${NC}"
    exit 1
fi

# 7. 캐시 클리어
echo -e "\n${YELLOW}[7/8] Clearing cache...${NC}"
RAILS_ENV=production bundle exec rails tmp:clear
RAILS_ENV=production bundle exec rails log:clear

# 8. 서비스 재시작
echo -e "\n${YELLOW}[8/8] Restarting services...${NC}"

# Puma 서비스 재시작
if systemctl list-units --full -all | grep -Fq "testexp-puma.service"; then
    sudo systemctl restart testexp-puma
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Puma service restarted successfully.${NC}"
    else
        echo -e "${RED}Failed to restart Puma service!${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}No Puma systemd service found. Please restart Puma manually.${NC}"
fi

# Worker 서비스 재시작
if systemctl list-units --full -all | grep -Fq "testexp-worker.service"; then
    sudo systemctl restart testexp-worker
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}Worker service restarted successfully.${NC}"
    else
        echo -e "${RED}Failed to restart Worker service!${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}No Worker systemd service found. Please start worker manually.${NC}"
fi

# Nginx reload (설정 변경이 있을 수 있으므로)
if command -v nginx &> /dev/null; then
    sudo systemctl reload nginx
    echo -e "${GREEN}Nginx reloaded.${NC}"
fi

# 서비스 상태 확인
echo -e "\n${YELLOW}Checking service status...${NC}"
sleep 3

if systemctl list-units --full -all | grep -Fq "testexp-puma.service"; then
    echo -e "${YELLOW}Puma service:${NC}"
    sudo systemctl status testexp-puma --no-pager | head -n 10
fi

if systemctl list-units --full -all | grep -Fq "testexp-worker.service"; then
    echo -e "\n${YELLOW}Worker service:${NC}"
    sudo systemctl status testexp-worker --no-pager | head -n 10
fi

# 헬스 체크
echo -e "\n${YELLOW}Running health check...${NC}"
sleep 2

# 웹 애플리케이션 확인
PORT=${PORT:-3001}
HTTP_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://localhost:$PORT 2>/dev/null)
if [ $HTTP_STATUS -eq 200 ] || [ $HTTP_STATUS -eq 302 ] || [ $HTTP_STATUS -eq 301 ]; then
    echo -e "${GREEN}✓ Application is responding (HTTP $HTTP_STATUS)${NC}"
else
    echo -e "${RED}✗ Application health check failed (HTTP $HTTP_STATUS)${NC}"
fi

# Solid Queue 워커 프로세스 확인
echo -e "\n${YELLOW}Checking background workers...${NC}"
RAILS_ENV=production bundle exec rails runner "
  processes = SolidQueue::Process.all
  jobs_pending = SolidQueue::Job.where(finished_at: nil).count
  if processes.any?
    puts '✓ Worker processes: ' + processes.count.to_s + ' active'
    puts '  Pending jobs: ' + jobs_pending.to_s
  else
    puts '✗ No worker processes found!'
    puts '  Pending jobs: ' + jobs_pending.to_s
  end
" 2>/dev/null || echo -e "${YELLOW}Could not check worker status${NC}"

# 완료
echo -e "\n${GREEN}========================================${NC}"
echo -e "${GREEN}   Deployment completed successfully!${NC}"
echo -e "${GREEN}========================================${NC}"

# 로그 파일 위치 안내
echo -e "\n${YELLOW}Log files:${NC}"
echo "  Application: $DEPLOY_DIR/log/production.log"
echo "  Puma: $DEPLOY_DIR/log/puma.stdout.log"
echo "  Worker: $DEPLOY_DIR/log/worker.log"