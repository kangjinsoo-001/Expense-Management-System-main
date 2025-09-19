# 시드 데이터 가이드

## 개요
시드 데이터는 개발 환경과 스테이징 환경에 따라 다르게 구성되어 있습니다.

## 시드 파일 구조

### 개발 환경 (db/seeds.rb)
전체 샘플 데이터를 포함한 완전한 시드 데이터:
- 조직 및 사용자
- 승인자 그룹
- 비용 센터
- 승인 라인
- 경비 코드
- **경비 신청 샘플 데이터** (승인/반려/진행중 등 다양한 상태)
- **테스트용 경비 항목들**

### 스테이징 환경 (db/seeds_staging.rb)
기본 설정 데이터만 포함:
- 조직 및 사용자
- 승인자 그룹
- 비용 센터
- 승인 라인
- 경비 코드
- ~~경비 신청 데이터 없음~~ (실제 테스트로 생성)

## 사용 방법

### 로컬 개발 환경

```bash
# 기본 시드 로드 (전체 데이터)
rails db:seed

# 헬퍼 스크립트 사용
./load_seeds.sh           # 개발용 전체 시드
./load_seeds.sh -r        # DB 리셋 후 전체 시드
./load_seeds.sh -s        # 스테이징용 최소 시드 (로컬에서 테스트)
./load_seeds.sh -r -s     # DB 리셋 후 스테이징 시드

# 로컬 서버 시작 스크립트와 함께 사용
./local.sh -r             # DB 리셋, 시드, 서버 시작
./local.sh -s             # 시드만 실행 후 서버 시작
```

### 스테이징 환경 (test.exp.tlx.kr)

```bash
# 스테이징 DB 리셋 및 시드
./reset_staging_db.sh

# 수동으로 스테이징 시드만 실행
RAILS_ENV=production bundle exec rails runner "load Rails.root.join('db/seeds_staging.rb')"
```

## 시드 파일 목록

| 파일명 | 설명 | 개발 | 스테이징 |
|--------|------|------|----------|
| 001_organizations.rb | 조직 구조 | ✅ | ✅ |
| 002_users.rb | 사용자 계정 | ✅ | ✅ |
| 003_approver_groups.rb | 승인자 그룹 | ✅ | ✅ |
| 004_cost_centers.rb | 비용 센터 | ✅ | ✅ |
| 005_approval_lines.rb | 승인 라인 | ✅ | ✅ |
| 006_expense_codes.rb | 경비 코드 | ✅ | ✅ |
| 007_approval_sample_data.rb | 승인 샘플 데이터 | ✅ | ❌ |
| 008_sample_expense_data.rb | 경비 샘플 데이터 | ✅ | ❌ |

## 테스트 계정

모든 환경에서 동일한 테스트 계정 사용:
- **대표이사**: jaypark@tlx.kr / hcghcghcg
- **CPO**: sabaek@tlx.kr / hcghcghcg
- **hunel COO**: ymkim@tlx.kr / hcghcghcg
- **Admin**: hjlee@tlx.kr / hcghcghcg
- **talenx BU 직원**: jjbaek@tlx.kr / hcghcghcg

## 주의사항

1. **스테이징 환경**에서는 경비 신청 샘플 데이터가 없으므로 실제 테스트를 통해 데이터를 생성해야 합니다.

2. **첨부파일 검증**: 시드 로드 중에는 `ENV['SEEDING'] = 'true'` 플래그로 첨부파일 검증을 일시적으로 무시합니다.

3. **프로덕션 환경**: 실제 프로덕션에서는 시드 데이터를 사용하지 않습니다. 필요한 경우 마이그레이션이나 별도의 데이터 임포트 프로세스를 사용하세요.

## 문제 해결

### 시드 로드 실패 시
```bash
# 로그 확인
tail -f log/development.log

# DB 완전 초기화 후 재시도
rails db:drop db:create db:migrate db:seed

# 스테이징에서는
./reset_staging_db.sh
```

### 특정 시드 파일만 실행
```bash
rails runner "load Rails.root.join('db/seeds/001_organizations.rb')"
```