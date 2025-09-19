# 컴포넌트 라이브러리

## 📋 개요
경비 관리 시스템의 재사용 가능한 UI 컴포넌트 라이브러리입니다.

## 🔍 기존 컴포넌트 현황 분석

### 현재 Partial 컴포넌트 (118개)
```bash
# 컴포넌트 분석 명령어
find app/views -name "_*.html.erb" | sort
```

### 컴포넌트 분류 체계

## 🧩 Atoms (원자)

### Buttons
| 컴포넌트 | 파일 위치 | 용도 | 상태 |
|---------|-----------|------|------|
| Primary Button | `components/atoms/buttons/_primary.html.erb` | 주요 액션 | 🔄 마이그레이션 필요 |
| Secondary Button | `components/atoms/buttons/_secondary.html.erb` | 보조 액션 | 🔄 마이그레이션 필요 |
| Icon Button | `components/atoms/buttons/_icon.html.erb` | 아이콘 액션 | 🔄 마이그레이션 필요 |

**사용 예시:**
```erb
<%= render 'components/atoms/buttons/primary', 
    text: '저장', 
    href: '#', 
    class: 'w-full' %>
```

### Form Elements
| 컴포넌트 | 파일 위치 | 용도 | 상태 |
|---------|-----------|------|------|
| Text Input | `components/atoms/inputs/_text.html.erb` | 텍스트 입력 | 🔄 마이그레이션 필요 |
| Select | `components/atoms/inputs/_select.html.erb` | 선택 입력 | 🔄 마이그레이션 필요 |
| Textarea | `components/atoms/inputs/_textarea.html.erb` | 긴 텍스트 입력 | 🔄 마이그레이션 필요 |
| Checkbox | `components/atoms/inputs/_checkbox.html.erb` | 체크박스 | 🔄 마이그레이션 필요 |

### Status Indicators
| 컴포넌트 | 파일 위치 | 용도 | 상태 |
|---------|-----------|------|------|
| Status Badge | `components/atoms/badges/_status.html.erb` | 상태 표시 | 🔄 마이그레이션 필요 |
| Loading Spinner | `components/atoms/indicators/_spinner.html.erb` | 로딩 표시 | 🔄 마이그레이션 필요 |

## 🧪 Molecules (분자)

### Form Groups
| 컴포넌트 | 파일 위치 | 용도 | 상태 |
|---------|-----------|------|------|
| Form Field | `components/molecules/forms/_field.html.erb` | 레이블+입력+에러 | 🔄 마이그레이션 필요 |
| Search Box | `components/molecules/forms/_search.html.erb` | 검색 입력 | 🔄 마이그레이션 필요 |

### Cards
| 컴포넌트 | 파일 위치 | 용도 | 상태 |
|---------|-----------|------|------|
| Basic Card | `components/molecules/cards/_basic.html.erb` | 기본 카드 | 🔄 마이그레이션 필요 |
| Expense Card | `components/molecules/cards/_expense.html.erb` | 경비 항목 카드 | 🔄 마이그레이션 필요 |
| Stats Card | `components/molecules/cards/_stats.html.erb` | 통계 카드 | 🔄 마이그레이션 필요 |

### Navigation
| 컴포넌트 | 파일 위치 | 용도 | 상태 |
|---------|-----------|------|------|
| Breadcrumb | `components/molecules/navigation/_breadcrumb.html.erb` | 경로 표시 | 🔄 마이그레이션 필요 |
| Pagination | `components/molecules/navigation/_pagination.html.erb` | 페이지네이션 | 🔄 마이그레이션 필요 |
| Tab Menu | `components/molecules/navigation/_tabs.html.erb` | 탭 메뉴 | 🔄 마이그레이션 필요 |

## 🦠 Organisms (유기체)

### Layout Components
| 컴포넌트 | 파일 위치 | 용도 | 상태 |
|---------|-----------|------|------|
| Header | `components/organisms/layout/_header.html.erb` | 페이지 헤더 | 🔄 마이그레이션 필요 |
| Sidebar | `components/organisms/layout/_sidebar.html.erb` | 사이드 네비게이션 | 🔄 마이그레이션 필요 |
| Footer | `components/organisms/layout/_footer.html.erb` | 페이지 푸터 | 🔄 마이그레이션 필요 |

### Data Display
| 컴포넌트 | 파일 위치 | 용도 | 상태 |
|---------|-----------|------|------|
| Data Table | `components/organisms/tables/_data_table.html.erb` | 데이터 테이블 | 🔄 마이그레이션 필요 |
| Dashboard Grid | `components/organisms/layout/_dashboard.html.erb` | 대시보드 레이아웃 | 🔄 마이그레이션 필요 |

### Forms
| 컴포넌트 | 파일 위치 | 용도 | 상태 |
|---------|-----------|------|------|
| Expense Form | `components/organisms/forms/_expense.html.erb` | 경비 입력 폼 | 🔄 마이그레이션 필요 |
| Filter Panel | `components/organisms/forms/_filter.html.erb` | 필터링 패널 | 🔄 마이그레이션 필요 |

## 📝 Templates (템플릿)

### Page Layouts
| 템플릿 | 파일 위치 | 용도 | 상태 |
|--------|-----------|------|------|
| Admin Layout | `components/templates/_admin.html.erb` | 관리자 페이지 | 🔄 마이그레이션 필요 |
| Dashboard Layout | `components/templates/_dashboard.html.erb` | 대시보드 페이지 | 🔄 마이그레이션 필요 |
| Form Layout | `components/templates/_form.html.erb` | 폼 페이지 | 🔄 마이그레이션 필요 |

## 🎯 컴포넌트 사용 가이드

### 1. 컴포넌트 명명 규칙
```
_[category]_[variant].html.erb

예시:
_button_primary.html.erb
_card_expense.html.erb
_form_field.html.erb
```

### 2. 매개변수 표준화
```erb
<%# 모든 컴포넌트는 다음 표준 매개변수를 지원해야 함 %>
<%= render 'components/atoms/buttons/primary', {
  # 필수 매개변수
  text: '버튼 텍스트',
  
  # 선택적 매개변수
  href: '#',
  class: 'additional-class',
  id: 'custom-id',
  data: { controller: 'stimulus-controller' },
  disabled: false,
  
  # 컴포넌트별 고유 매개변수
  size: 'md',     # sm, md, lg
  variant: 'solid' # solid, outline, ghost
} %>
```

### 3. Stimulus 컨트롤러 연결
```erb
<%# 컴포넌트에 Stimulus 컨트롤러 자동 연결 %>
<div data-controller="component-name" 
     data-component-name-param-value="<%= param %>">
  <!-- 컴포넌트 내용 -->
</div>
```

## 🔄 마이그레이션 우선순위

### Phase 1: 기본 Atoms (1주차)
- [ ] Buttons (Primary, Secondary, Icon)
- [ ] Form Inputs (Text, Select, Textarea, Checkbox)
- [ ] Status Badges
- [ ] Loading Indicators

### Phase 2: 핵심 Molecules (2주차)
- [ ] Form Fields
- [ ] Basic Cards
- [ ] Navigation Components
- [ ] Search Components

### Phase 3: 복잡한 Organisms (3주차)
- [ ] Data Tables
- [ ] Dashboard Components
- [ ] Form Layouts
- [ ] Header/Navigation

### Phase 4: Templates & Integration (4주차)
- [ ] Page Templates
- [ ] Layout Templates
- [ ] Responsive 최적화
- [ ] Accessibility 개선

## 📊 진행 상황 추적

### 컴포넌트 상태 코드
- 🔄 마이그레이션 필요
- 🚧 작업 중
- ✅ 완료
- 🧪 테스트 필요
- 📚 문서 업데이트 필요

### 품질 체크리스트
- [ ] 반응형 디자인 지원
- [ ] 접근성 (ARIA) 지원
- [ ] Stimulus 컨트롤러 연결
- [ ] 다크모드 지원
- [ ] 브라우저 호환성 테스트
- [ ] 성능 최적화