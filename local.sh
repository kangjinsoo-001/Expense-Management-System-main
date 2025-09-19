#!/bin/bash

# 사용법:
#   ./restart_local.sh          # 일반 모드 (대화형)
#   ./restart_local.sh --quick   # 빠른 모드 (시드 없음, bin/dev 자동 실행)
#   ./restart_local.sh -q        # 빠른 모드 (단축 옵션)
#   ./restart_local.sh --seed    # 시드만 실행 후 bin/dev 자동 실행 (기존 데이터 유지)
#   ./restart_local.sh -s        # 시드만 실행 후 bin/dev 자동 실행 (단축 옵션)
#   ./restart_local.sh --reset   # DB 완전 리셋 후 시드 실행, bin/dev 자동 실행
#   ./restart_local.sh -r        # DB 완전 리셋 후 시드 실행 (단축 옵션)
#   ./restart_local.sh -q -s     # 빠른 모드 + 시드만 실행

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 옵션 파싱
QUICK_MODE=false
SEED_MODE=false
RESET_MODE=false
for arg in "$@"; do
    if [ "$arg" = "--quick" ] || [ "$arg" = "-q" ]; then
        QUICK_MODE=true
    fi
    if [ "$arg" = "--seed" ] || [ "$arg" = "-s" ]; then
        SEED_MODE=true
        QUICK_MODE=true  # 시드 모드는 자동으로 빠른 모드 활성화
    fi
    if [ "$arg" = "--reset" ] || [ "$arg" = "-r" ]; then
        RESET_MODE=true
        QUICK_MODE=true  # 리셋 모드도 자동으로 빠른 모드 활성화
    fi
done

# 로그 함수
log_info() {
    echo -e "${BLUE}[정보]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[성공]${NC} $1"
}

log_error() {
    echo -e "${RED}[오류]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[경고]${NC} $1"
}

# 단계별 확인 함수
pause_and_check() {
    if [ "$QUICK_MODE" = false ]; then
        echo -e "\n${YELLOW}계속 진행하려면 Enter를 누르세요. 문제가 있다면 Ctrl+C로 중단하세요.${NC}"
        read -r
    fi
}

# 에러 발생 시 도움말
show_error_help() {
    echo -e "\n${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}에러가 발생했습니다!${NC}"
    echo -e "${YELLOW}다음 사항을 확인하세요:${NC}"
    echo -e "1. 위의 에러 메시지 전체"
    echo -e "2. 실행 중이던 단계: $1"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

# 시작
echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}로컬 개발 환경 재시작 스크립트${NC}"
if [ "$RESET_MODE" = true ]; then
    echo -e "${RED}[리셋 모드]${NC} DB 완전 리셋 후 시드 실행, bin/dev로 자동 실행"
elif [ "$SEED_MODE" = true ]; then
    echo -e "${YELLOW}[시드 모드]${NC} 시드만 실행 후 bin/dev로 자동 실행"
elif [ "$QUICK_MODE" = true ]; then
    echo -e "${YELLOW}[빠른 모드]${NC} 시드 없음, bin/dev로 자동 실행"
fi
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# 현재 디렉토리 확인
CURRENT_DIR=$(pwd)
log_info "현재 디렉토리: $CURRENT_DIR"

# Rails 프로젝트 디렉토리인지 확인
if [ ! -f "Gemfile" ]; then
    log_error "Rails 프로젝트 디렉토리가 아닙니다. tlxkr 디렉토리로 이동 후 실행하세요."
    exit 1
fi

log_success "Rails 프로젝트 확인됨"

# 1단계: 기존 서버 프로세스 종료
echo -e "\n${BLUE}[1/8] 기존 서버 프로세스 종료${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# Rails 서버 프로세스 찾기 및 종료
RAILS_PID=$(ps aux | grep "[r]ails server" | awk '{print $2}')
if [ -n "$RAILS_PID" ]; then
    log_info "Rails 서버 프로세스를 종료합니다 (PID: $RAILS_PID)"
    kill -9 $RAILS_PID 2>/dev/null
    log_success "Rails 서버 종료됨"
else
    log_info "실행 중인 Rails 서버가 없습니다."
fi

# Puma 프로세스 종료
PUMA_PID=$(ps aux | grep "[p]uma" | grep -v grep | awk '{print $2}')
if [ -n "$PUMA_PID" ]; then
    log_info "Puma 프로세스를 종료합니다"
    kill -9 $PUMA_PID 2>/dev/null
fi

# bin/dev 프로세스 종료
DEV_PID=$(ps aux | grep "[b]in/dev" | awk '{print $2}')
if [ -n "$DEV_PID" ]; then
    log_info "bin/dev 프로세스를 종료합니다"
    kill -9 $DEV_PID 2>/dev/null
fi

sleep 2

# 2단계: 임시 파일 및 캐시 정리
echo -e "\n${BLUE}[2/8] 임시 파일 및 캐시 정리${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

log_info "캐시 및 임시 파일을 삭제합니다..."
rm -rf tmp/cache/*
rm -rf tmp/pids/*
rm -rf public/assets/*
rm -rf app/assets/builds/*

if rails tmp:clear; then
    log_success "임시 파일 정리 완료"
else
    log_warning "임시 파일 정리 중 일부 경고가 있었지만 계속 진행합니다."
    pause_and_check
fi

# 3단계: Bundle install
echo -e "\n${BLUE}[3/8] Bundle install (gem 의존성 설치)${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if bundle install; then
    log_success "Bundle install 완료"
else
    log_error "Bundle install 실패"
    show_error_help "Bundle install"
    exit 1
fi

# 4단계: 데이터베이스 마이그레이션
echo -e "\n${BLUE}[4/8] 데이터베이스 마이그레이션${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if rails db:migrate; then
    log_success "데이터베이스 마이그레이션 완료"
else
    log_warning "마이그레이션 중 문제가 있었습니다. 계속 진행합니다."
    pause_and_check
fi

# 시드 데이터 확인
if [ "$RESET_MODE" = true ]; then
    seed_choice=3  # 리셋 모드에서는 DB 리셋 후 시드 실행
    log_warning "리셋 모드: 모든 데이터를 삭제하고 시드를 실행합니다"
elif [ "$SEED_MODE" = true ]; then
    seed_choice=2  # 시드 모드에서는 시드만 실행
    log_info "시드 모드: 기존 데이터를 유지하고 시드만 실행합니다"
elif [ "$QUICK_MODE" = true ]; then
    seed_choice=1  # 빠른 모드에서는 시드 실행 안 함
    log_info "시드 실행을 건너뜁니다."
else
    echo ""
    log_info "시드 데이터 옵션을 선택하세요:"
    echo "1) 시드 실행 안 함 (기본)"
    echo "2) 시드만 실행 (기존 데이터 유지)"
    echo "3) 모든 데이터 리셋 후 시드 실행 (개발 환경 전용)"
    read -p "선택 (1-3) [1]: " seed_choice
    seed_choice=${seed_choice:-1}
fi

case $seed_choice in
    2)
        log_info "시드 데이터를 실행합니다..."
        if rails db:seed; then
            log_success "시드 데이터 실행 완료"
            echo "생성된 테스트 계정:"
            echo "  - 관리자: admin@tlx.kr / password123"
            echo "  - 승인된 사용자: user@example.com / password123"
            echo "  - 승인 대기 사용자: pending@example.com / password123"
        else
            log_warning "시드 실행 중 경고가 있었지만 계속 진행합니다."
            pause_and_check
        fi
        ;;
    3)
        log_warning "모든 데이터를 삭제하고 시드를 실행합니다!"
        # 리셋 모드에서는 확인 없이 바로 실행, 일반 모드에서는 확인
        if [ "$RESET_MODE" = true ]; then
            confirm="yes"
        else
            read -p "정말로 모든 데이터를 삭제하시겠습니까? (yes/no): " confirm
        fi
        if [ "$confirm" = "yes" ] || [ "$confirm" = "ㅛㄷㄴ" ]; then
            log_info "데이터베이스를 초기화합니다..."
            if rails db:drop db:create db:migrate db:seed; then
                log_success "데이터베이스 초기화 및 시드 실행 완료"
                echo "생성된 테스트 계정:"
                echo "  - 관리자: admin@example.com / password123"
                echo "  - 매니저: manager@example.com / password123"
                echo "  - 직원1: employee1@example.com / password123"
                echo "  - 직원2: employee2@example.com / password123"
            else
                log_error "데이터베이스 초기화 중 오류 발생"
                pause_and_check
            fi
        else
            log_info "데이터 리셋을 취소했습니다."
        fi
        ;;
    *)
        log_info "시드 실행을 건너뜁니다."
        ;;
esac

# 5단계: Tailwind CSS 빌드
echo -e "\n${BLUE}[5/8] Tailwind CSS 빌드${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

log_info "Tailwind CSS를 빌드합니다..."

if rails tailwindcss:build; then
    log_success "Tailwind CSS 빌드 성공"
else
    log_warning "Tailwind 빌드 실패. bin/rails로 다시 시도합니다..."
    if ./bin/rails tailwindcss:build; then
        log_success "Tailwind CSS 빌드 성공"
    else
        log_error "Tailwind CSS 빌드 실패"
        show_error_help "Tailwind CSS build"
        pause_and_check
    fi
fi

# 빌드 파일 확인
if [ -f "app/assets/builds/tailwind.css" ]; then
    FILE_SIZE=$(ls -lh app/assets/builds/tailwind.css | awk '{print $5}')
    log_success "Tailwind CSS 파일 생성 확인 (크기: $FILE_SIZE)"
else
    log_error "Tailwind CSS 파일이 생성되지 않았습니다!"
    pause_and_check
fi

# 6단계: JavaScript/Assets 컴파일
echo -e "\n${BLUE}[6/8] Assets 컴파일${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

log_info "JavaScript와 CSS를 컴파일합니다..."

if rails assets:precompile; then
    log_success "Assets 컴파일 완료"
else
    log_warning "Assets 컴파일 중 경고가 있었지만 계속 진행합니다."
    pause_and_check
fi

# 7단계: 로컬 환경 재시작 완료 메시지
echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}로컬 환경 재시작${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# 8단계: 서버 시작 방법 선택
echo -e "\n${BLUE}[8/8] 서버 시작 방법 선택${NC}"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

if [ "$QUICK_MODE" = true ]; then
    choice=1  # 빠른 모드에서는 bin/dev로 자동 실행
    log_info "빠른 모드: bin/dev로 자동 실행합니다"
else
    echo "서버를 시작할 방법을 선택하세요:"
    echo "1) bin/dev (Foreman으로 Rails + Tailwind watch 동시 실행) [권장]"
    echo "2) rails server (Rails 서버만 실행)"
    echo "3) 수동으로 시작 (스크립트 종료)"
    
    read -p "선택 (1-3) [1]: " choice
    choice=${choice:-1}
fi

echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}로컬 환경 재시작!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

log_info "접속 주소: http://localhost:3000"
log_info "로그 확인: tail -f log/development.log"
echo ""
log_warning "문제가 있다면:"
echo "1. 브라우저 캐시 삭제 (Ctrl+F5)"
echo "2. 다른 터미널에서: rails tailwindcss:watch"
echo ""

case $choice in
    1)
        log_info "bin/dev로 서버를 시작합니다..."
        echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}서버 시작 중...${NC}"
        echo -e "${YELLOW}종료하려면 Ctrl+C를 누르세요${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
        
        ./bin/dev
        ;;
    2)
        log_info "rails server로 서버를 시작합니다..."
        echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}서버 시작 중...${NC}"
        echo -e "${YELLOW}종료하려면 Ctrl+C를 누르세요${NC}"
        echo -e "${YELLOW}주의: Tailwind CSS는 자동으로 리빌드되지 않습니다!${NC}"
        echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
        
        rails server
        ;;
    3)
        log_info "수동으로 서버를 시작하세요."
        echo ""
        echo "서버 시작 명령어:"
        echo "  - ./bin/dev (권장)"
        echo "  - rails server"
        echo ""
        ;;
    *)
        log_error "잘못된 선택입니다. 수동으로 서버를 시작하세요."
        ;;
esac

# 최종 안내
log_info "스크립트 종료"