# 시드 데이터 가이드

## 시드 파일 번호 체계

시드 파일들은 10 단위 번호 체계로 구성되어 있으며, 각 범위별로 다른 목적을 가집니다.

### 번호 범위별 구분

- **000-090**: 기본 설정 (조직, 사용자, 시스템 설정)
- **100-190**: 샘플 데이터
- **900-990**: 특수 목적 (성능 테스트 등, 수동 실행)

## 시드 파일 구조

### 000번대 - 기본 설정
- `010_organizations.rb` - 조직 구조
- `020_users.rb` - 사용자 계정
- `030_approver_groups.rb` - 승인자 그룹
- `040_cost_centers.rb` - 비용 센터
- `050_expense_codes.rb` - 경비 코드 및 승인 규칙
- `060_attachment_requirements.rb` - 첨부파일 요구사항
- `070_request_categories_and_templates.rb` - 신청서 카테고리/템플릿
- `080_rooms.rb` - 회의실 설정
- `090_approval_lines.rb` - 기본 결재선 (모든 사용자에게 자동 생성)

### 100번대 - 샘플 데이터
- `100_expense_samples.rb` - 경비 샘플 데이터
- `110_request_form_samples.rb` - 신청서 샘플
- `120_room_reservation_samples.rb` - 회의실 예약 샘플
- `130_approval_samples.rb` - 승인 샘플 데이터

### 900번대 - 특수 목적 (수동 실행)
- `900_performance_test_data.rb` - 성능 테스트용 대량 데이터

## 실행 방법

### 기본 시드 실행 (000-199)
```bash
rails db:seed
```
- 기본 설정과 샘플 데이터가 자동으로 로드됩니다
- 900번대 파일은 자동 실행에서 제외됩니다

### 특수 목적 시드 실행
```bash
# 성능 테스트 데이터 (약 180만건)
ALLOW_PERFORMANCE_SEED=true rails runner "load 'db/seeds/900_performance_test_data.rb'"
```

### 개별 시드 파일 실행
```bash
# 특정 파일만 실행
rails runner "load 'db/seeds/040_cost_centers.rb'"
```

## 파일 추가 가이드

10 단위 번호 체계를 사용하므로 각 카테고리 내에서 새로운 파일 추가가 용이합니다:

- 새로운 기본 설정: 사용되지 않은 번호 사용 (예: `035_`, `045_`, `055_`...)
- 새로운 샘플 데이터: `140_`, `150_`, `160_`... 사용
- 새로운 특수 목적: `910_`, `920_`, `930_`... 사용

## 주요 특징

### 실행 순서 (중요)
1. **조직 구조** (010) - 가장 먼저 실행
2. **사용자** (020) - 조직 이후 실행
3. **기타 설정** (030-080) - 순차적으로 실행
4. **결재선** (090) - 모든 설정 완료 후 실행
5. **샘플 데이터** (100-130) - 기본 설정 완료 후 실행

### 040_cost_centers.rb
- 조직 데이터를 직접 조회하여 코스트 센터 생성
- 각 사업부별 예산 할당
- 프로젝트별, 공통 코스트 센터 포함

### 090_approval_lines.rb
- 모든 사용자에게 "기본" 결재선 자동 생성
- 조직 계층을 따라 상위자 → 대표이사까지 승인 라인 구성
- CEO를 제외한 모든 사용자에게 적용

### 100_expense_samples.rb
- 최효진 승인 대기 경비 항목 포함
- 다양한 상태의 경비 샘플 생성 (승인/반려/대기)
- ApprovalRequest와 ApprovalHistory 자동 생성

### 900_performance_test_data.rb
- 개발 환경에서만 실행 가능
- `ALLOW_PERFORMANCE_SEED=true` 환경변수 필요
- 18개월간 월 10만건, 총 180만건 생성 목표

## 샘플 로그인 계정

시드 실행 후 사용 가능한 계정:
- 대표이사: jaypark@tlx.kr / hcghcghcg
- CPO: sabaek@tlx.kr / hcghcghcg
- hunel COO: ymkim@tlx.kr / hcghcghcg
- Admin: hjlee@tlx.kr / hcghcghcg
- talenx BU 직원: jjbaek@tlx.kr / hcghcghcg

## 데이터 초기화

시드 실행 시 기존 데이터는 자동으로 삭제됩니다:
1. 신청서 관련 데이터
2. 첨부파일 관련 데이터
3. 승인 관련 데이터
4. 경비 관련 데이터
5. 사용자 및 조직 데이터

## 주의사항

- 시드 실행은 개발 환경에서만 권장됩니다
- 프로덕션 환경에서는 별도의 시드 파일 사용을 권장합니다
- 900번대 파일은 성능에 영향을 줄 수 있으므로 주의해서 실행하세요

## 파일명 규칙

- 모두 소문자 사용
- 단어는 언더스코어(_)로 구분
- 복수형 사용 (예: expense_samples, room_reservation_samples)
- 일관된 명명 규칙 적용