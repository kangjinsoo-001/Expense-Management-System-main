# 경비 관리 시스템 - 디자인 시스템

## 📋 개요
이 문서는 경비 관리 시스템의 일관된 UI/UX를 위한 디자인 시스템 가이드입니다.

## 🎨 디자인 토큰

### 컬러 시스템
```css
/* Primary Colors */
--primary-50: #eff6ff;
--primary-100: #dbeafe;
--primary-500: #3b82f6;
--primary-600: #2563eb;
--primary-700: #1d4ed8;

/* Gray Scale */
--gray-50: #f9fafb;
--gray-100: #f3f4f6;
--gray-200: #e5e7eb;
--gray-300: #d1d5db;
--gray-400: #9ca3af;
--gray-500: #6b7280;
--gray-600: #4b5563;
--gray-700: #374151;
--gray-800: #1f2937;
--gray-900: #111827;

/* Semantic Colors */
--success: #10b981;
--warning: #f59e0b;
--danger: #ef4444;
--info: #3b82f6;
```

### 타이포그래피
```css
/* Font Sizes */
--text-xs: 0.75rem;     /* 12px */
--text-sm: 0.875rem;    /* 14px */
--text-base: 1rem;      /* 16px */
--text-lg: 1.125rem;    /* 18px */
--text-xl: 1.25rem;     /* 20px */
--text-2xl: 1.5rem;     /* 24px */
--text-3xl: 1.875rem;   /* 30px */

/* Font Weights */
--font-normal: 400;
--font-medium: 500;
--font-semibold: 600;
--font-bold: 700;
```

### 스페이싱
```css
/* Spacing Scale */
--space-1: 0.25rem;   /* 4px */
--space-2: 0.5rem;    /* 8px */
--space-3: 0.75rem;   /* 12px */
--space-4: 1rem;      /* 16px */
--space-5: 1.25rem;   /* 20px */
--space-6: 1.5rem;    /* 24px */
--space-8: 2rem;      /* 32px */
--space-10: 2.5rem;   /* 40px */
--space-12: 3rem;     /* 48px */
--space-16: 4rem;     /* 64px */
```

### 브레이크포인트
```css
/* Responsive Breakpoints */
--breakpoint-sm: 640px;
--breakpoint-md: 768px;
--breakpoint-lg: 1024px;
--breakpoint-xl: 1280px;
--breakpoint-2xl: 1536px;
```

## 🧩 컴포넌트 아키텍처

### 컴포넌트 분류
1. **Atoms** (원자): 가장 기본적인 UI 요소
2. **Molecules** (분자): 여러 원자가 결합된 단순한 UI 그룹
3. **Organisms** (유기체): 복잡한 UI 섹션
4. **Templates** (템플릿): 페이지 레벨 레이아웃
5. **Pages** (페이지): 실제 콘텐츠가 있는 페이지

### 디렉토리 구조
```
app/views/
├── components/           # 공통 컴포넌트
│   ├── atoms/           # 기본 요소들
│   │   ├── buttons/
│   │   ├── inputs/
│   │   ├── badges/
│   │   └── icons/
│   ├── molecules/       # 조합된 요소들
│   │   ├── forms/
│   │   ├── cards/
│   │   ├── modals/
│   │   └── navigation/
│   ├── organisms/       # 복잡한 섹션들
│   │   ├── headers/
│   │   ├── footers/
│   │   ├── sidebars/
│   │   └── tables/
│   └── templates/       # 레이아웃 템플릿
│       ├── admin/
│       ├── auth/
│       └── dashboard/
├── shared/              # 기존 공유 컴포넌트
└── pages/               # 페이지별 뷰
```

## 📚 참고 문서
- [컴포넌트 라이브러리](./COMPONENT_LIBRARY.md)
- [UI 패턴 가이드](./UI_PATTERNS.md)
- [접근성 가이드](./ACCESSIBILITY.md)
- [마이그레이션 가이드](./MIGRATION_GUIDE.md)

## 🔄 업데이트 이력
- 2024-01-01: 초기 디자인 시스템 구축
- 현재: 기존 118개 partial 컴포넌트 분석 및 정리 필요

## 🎯 다음 단계
1. 기존 컴포넌트 분석 및 분류
2. 아토믹 디자인 원칙에 따른 재구성
3. 스토리북 도입 검토
4. 디자인 토큰 시스템 구현