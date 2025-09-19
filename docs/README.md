# 경비 관리 시스템 - 문서 모음

## 📋 개요
경비 관리 시스템의 UI/UX 디자인 시스템 및 개발 가이드 문서 모음입니다.

## 📚 문서 목록

### 🎨 디자인 시스템
- **[DESIGN_SYSTEM.md](./DESIGN_SYSTEM.md)** - 전체 디자인 시스템 개요
  - 디자인 토큰 (색상, 타이포그래피, 스페이싱)
  - 컴포넌트 아키텍처 (Atomic Design)
  - 디렉토리 구조 및 규칙

### 🧩 컴포넌트 관리
- **[COMPONENT_LIBRARY.md](./COMPONENT_LIBRARY.md)** - 컴포넌트 라이브러리
  - 기존 118개 partial 컴포넌트 현황
  - Atoms, Molecules, Organisms, Templates 분류
  - 사용법 및 매개변수 가이드
  - 마이그레이션 우선순위

### 🎯 UI 패턴
- **[UI_PATTERNS.md](./UI_PATTERNS.md)** - UI 패턴 가이드
  - 레이아웃 패턴 (Dashboard, Form, List)
  - 인터랙션 패턴 (Modal, Toast, Loading)
  - 반응형 패턴
  - 상태 및 애니메이션 패턴

### 🔄 마이그레이션
- **[MIGRATION_GUIDE.md](./MIGRATION_GUIDE.md)** - 컴포넌트 마이그레이션 가이드
  - 4단계 마이그레이션 전략
  - 자동화 도구 및 스크립트
  - 롤백 계획
  - 성공 지표

### ♿ 접근성
- **[ACCESSIBILITY.md](./ACCESSIBILITY.md)** - 접근성 가이드
  - WCAG 2.1 AA 준수 기준
  - 색상, 키보드, 스크린 리더 지원
  - 컴포넌트별 접근성 구현
  - 테스트 방법론

## 🚀 시작하기

### 1. 현재 상황 파악
```bash
# 기존 컴포넌트 개수 확인
find app/views -name "_*.html.erb" | wc -l
# 결과: 118개

# 주요 레이아웃 파일 확인
ls app/views/layouts/
# application.html.erb, admin.html.erb, mailer.html.erb
```

### 2. 디자인 시스템 구축 순서
1. **[DESIGN_SYSTEM.md](./DESIGN_SYSTEM.md)** 읽고 전체 구조 이해
2. **[COMPONENT_LIBRARY.md](./COMPONENT_LIBRARY.md)** 참고하여 현재 컴포넌트 파악
3. **[MIGRATION_GUIDE.md](./MIGRATION_GUIDE.md)** 따라 단계별 마이그레이션
4. **[UI_PATTERNS.md](./UI_PATTERNS.md)** 활용하여 일관된 패턴 적용
5. **[ACCESSIBILITY.md](./ACCESSIBILITY.md)** 기준으로 접근성 확보

### 3. 개발 워크플로우
```erb
<!-- 1. 새로운 컴포넌트 생성 시 -->
<%= atom('buttons/primary', text: '저장', href: '#') %>

<!-- 2. 복합 컴포넌트 조합 시 -->
<%= molecule('forms/field', 
    form: form, 
    field: :name, 
    label: '이름', 
    required: true) %>

<!-- 3. 페이지 레벨 조합 시 -->
<%= organism('layout/header', user: current_user) %>
```

## 📊 현재 프로젝트 현황

### 기술 스택
- **Backend**: Rails 8.0.2, Ruby 3.3.9
- **Frontend**: Turbo/Stimulus, Tailwind CSS v4.1.11
- **Database**: SQLite
- **UI Framework**: Tremor (부분적 사용)

### 현재 UI 구조
```
app/views/
├── layouts/
│   ├── application.html.erb    # 메인 레이아웃
│   ├── admin.html.erb          # 관리자 레이아웃  
│   └── mailer.html.erb         # 이메일 레이아웃
├── shared/                     # 공통 컴포넌트들
├── [module]/                   # 모듈별 뷰 파일들
│   ├── index.html.erb
│   ├── _form.html.erb
│   └── _[component].html.erb   # Partial 컴포넌트들
└── ...
```

### 마이그레이션 목표
- **118개 → 50개 이하**로 컴포넌트 수 감소
- **아토믹 디자인** 원칙 적용
- **일관된 네이밍** 규칙 적용
- **재사용성** 80% 이상 확보

## 🎯 다음 단계

### Phase 1: 분석 (1주)
- [ ] 기존 118개 컴포넌트 사용 빈도 분석
- [ ] 중복 기능 컴포넌트 식별
- [ ] 우선순위 매트릭스 작성

### Phase 2: 기반 구축 (1주)  
- [ ] 새로운 디렉토리 구조 생성
- [ ] 헬퍼 메서드 구현
- [ ] 기본 Atoms 컴포넌트 구축

### Phase 3: 마이그레이션 (2주)
- [ ] 고빈도 컴포넌트 우선 마이그레이션
- [ ] Molecules, Organisms 순차 적용
- [ ] 기존 사용처 업데이트

### Phase 4: 최적화 (1주)
- [ ] 성능 테스트 및 최적화
- [ ] 접근성 검증
- [ ] 문서 최종 업데이트

## 📞 문의 및 지원

### 개발팀 연락처
- **UI/UX 디자이너**: [여기에 연락처 추가]
- **프론트엔드 개발자**: [여기에 연락처 추가]
- **백엔드 개발자**: [여기에 연락처 추가]

### 이슈 트래킹
- GitHub Issues: [프로젝트 이슈 페이지]
- 슬랙 채널: #design-system
- 회의 일정: 매주 수요일 14:00

## 📝 변경 이력

### 2024-01-01
- ✅ 초기 디자인 시스템 문서 작성
- ✅ 현재 상황 분석 완료
- ✅ 마이그레이션 계획 수립

### 다음 업데이트 예정
- [ ] Phase 1 분석 결과 업데이트
- [ ] 컴포넌트 우선순위 확정
- [ ] 자동화 도구 개발 완료

---

💡 **Tip**: 각 문서는 서로 연관되어 있으므로 순서대로 읽으시는 것을 권장합니다. 궁금한 점이 있으시면 언제든 문의해 주세요!