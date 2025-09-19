# UI 패턴 가이드

## 📋 개요
경비 관리 시스템에서 자주 사용되는 UI 패턴과 인터랙션 가이드입니다.

## 🎨 레이아웃 패턴

### 1. Dashboard Layout
```erb
<!-- 대시보드 레이아웃 패턴 -->
<div class="min-h-screen bg-gray-50">
  <!-- 헤더 -->
  <header class="bg-white shadow">
    <%= render 'components/organisms/layout/header' %>
  </header>
  
  <!-- 메인 콘텐츠 -->
  <div class="flex">
    <!-- 사이드바 -->
    <aside class="w-64 bg-white shadow-sm">
      <%= render 'components/organisms/layout/sidebar' %>
    </aside>
    
    <!-- 콘텐츠 영역 -->
    <main class="flex-1 p-6">
      <!-- 페이지 헤더 -->
      <div class="mb-6">
        <%= render 'components/molecules/navigation/breadcrumb' %>
        <h1 class="text-2xl font-bold text-gray-900">페이지 제목</h1>
      </div>
      
      <!-- 콘텐츠 그리드 -->
      <div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
        <%= yield %>
      </div>
    </main>
  </div>
</div>
```

### 2. Form Layout
```erb
<!-- 폼 레이아웃 패턴 -->
<div class="max-w-3xl mx-auto py-6">
  <!-- 폼 헤더 -->
  <div class="mb-8">
    <h1 class="text-2xl font-bold text-gray-900">폼 제목</h1>
    <p class="mt-2 text-gray-600">폼 설명</p>
  </div>
  
  <!-- 폼 카드 -->
  <div class="bg-white rounded-lg shadow p-6">
    <%= form_with model: @model, local: true do |form| %>
      <!-- 폼 섹션들 -->
      <div class="space-y-6">
        <%= render 'components/molecules/forms/section', title: '기본 정보' do %>
          <%= render 'components/molecules/forms/field', 
              form: form, field: :name, label: '이름', required: true %>
        <% end %>
      </div>
      
      <!-- 폼 액션 -->
      <div class="mt-8 flex justify-end space-x-3">
        <%= render 'components/atoms/buttons/secondary', text: '취소', href: :back %>
        <%= render 'components/atoms/buttons/primary', text: '저장', type: 'submit' %>
      </div>
    <% end %>
  </div>
</div>
```

### 3. List Layout
```erb
<!-- 리스트 레이아웃 패턴 -->
<div class="space-y-6">
  <!-- 리스트 헤더 -->
  <div class="flex justify-between items-center">
    <h1 class="text-2xl font-bold text-gray-900">목록 제목</h1>
    <%= render 'components/atoms/buttons/primary', text: '새로 만들기', href: '#' %>
  </div>
  
  <!-- 필터 및 검색 -->
  <div class="bg-white rounded-lg shadow p-4">
    <%= render 'components/organisms/forms/filter_panel' %>
  </div>
  
  <!-- 데이터 테이블 또는 카드 그리드 -->
  <div class="bg-white rounded-lg shadow">
    <%= render 'components/organisms/tables/data_table', items: @items %>
  </div>
  
  <!-- 페이지네이션 -->
  <div class="flex justify-center">
    <%= render 'components/molecules/navigation/pagination', items: @items %>
  </div>
</div>
```

## 🎯 인터랙션 패턴

### 1. Modal 패턴
```erb
<!-- 모달 트리거 -->
<%= render 'components/atoms/buttons/primary', 
    text: '모달 열기',
    data: { 
      action: 'click->modal#show',
      modal_target: 'trigger'
    } %>

<!-- 모달 컴포넌트 -->
<div data-controller="modal" 
     data-modal-target="container"
     class="hidden fixed inset-0 z-50">
  <!-- 백드롭 -->
  <div class="fixed inset-0 bg-black bg-opacity-50" 
       data-action="click->modal#hide"></div>
  
  <!-- 모달 콘텐츠 -->
  <div class="fixed top-1/2 left-1/2 transform -translate-x-1/2 -translate-y-1/2 
              bg-white rounded-lg shadow-xl max-w-md w-full mx-4">
    <%= render 'components/molecules/modals/content' %>
  </div>
</div>
```

### 2. Toast Notification 패턴
```erb
<!-- Toast 컨테이너 -->
<div id="toast-container" 
     class="fixed top-4 right-4 z-50 space-y-2"
     data-controller="toast">
  <!-- Toast 메시지들이 여기에 동적으로 추가됨 -->
</div>

<!-- Toast 템플릿 -->
<template data-toast-target="template">
  <div class="bg-white border-l-4 border-green-400 rounded-r-lg shadow-lg p-4 max-w-sm">
    <div class="flex items-center">
      <div class="flex-1">
        <p class="text-sm font-medium text-gray-900" data-toast-target="message"></p>
      </div>
      <button data-action="click->toast#dismiss" 
              class="ml-3 text-gray-400 hover:text-gray-600">
        <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
          <path d="M6.28 5.22a.75.75 0 00-1.06 1.06L8.94 10l-3.72 3.72a.75.75 0 101.06 1.06L10 11.06l3.72 3.72a.75.75 0 101.06-1.06L11.06 10l3.72-3.72a.75.75 0 00-1.06-1.06L10 8.94 6.28 5.22z"/>
        </svg>
      </button>
    </div>
  </div>
</template>
```

### 3. Loading States 패턴
```erb
<!-- 버튼 로딩 상태 -->
<button data-controller="loading-button"
        data-action="click->loading-button#submit"
        class="btn btn-primary">
  <span data-loading-button-target="text">저장</span>
  <span data-loading-button-target="spinner" class="hidden">
    <%= render 'components/atoms/indicators/spinner', size: 'sm' %>
    처리중...
  </span>
</button>

<!-- 페이지 로딩 상태 -->
<div data-controller="page-loader">
  <!-- 로딩 오버레이 -->
  <div data-page-loader-target="overlay" 
       class="hidden fixed inset-0 bg-white bg-opacity-75 z-50">
    <div class="flex items-center justify-center h-full">
      <%= render 'components/atoms/indicators/spinner', size: 'lg' %>
    </div>
  </div>
  
  <!-- 페이지 콘텐츠 -->
  <div data-page-loader-target="content">
    <%= yield %>
  </div>
</div>
```

## 📱 반응형 패턴

### 1. Mobile Navigation
```erb
<!-- 모바일 네비게이션 패턴 -->
<nav data-controller="mobile-nav">
  <!-- 데스크톱 네비게이션 -->
  <div class="hidden md:block">
    <%= render 'components/organisms/navigation/desktop_nav' %>
  </div>
  
  <!-- 모바일 헤더 -->
  <div class="md:hidden flex items-center justify-between p-4">
    <h1 class="text-lg font-semibold">앱 이름</h1>
    <button data-action="click->mobile-nav#toggle"
            data-mobile-nav-target="trigger">
      <svg class="w-6 h-6" fill="none" stroke="currentColor">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" 
              d="M4 6h16M4 12h16M4 18h16"/>
      </svg>
    </button>
  </div>
  
  <!-- 모바일 사이드 메뉴 -->
  <div data-mobile-nav-target="menu" 
       class="hidden md:hidden fixed inset-0 z-50">
    <!-- 백드롭 -->
    <div class="fixed inset-0 bg-black bg-opacity-50" 
         data-action="click->mobile-nav#close"></div>
    
    <!-- 메뉴 패널 -->
    <div class="fixed left-0 top-0 h-full w-64 bg-white shadow-xl">
      <%= render 'components/organisms/navigation/mobile_nav' %>
    </div>
  </div>
</nav>
```

### 2. Responsive Grid
```erb
<!-- 반응형 그리드 패턴 -->
<div class="grid gap-4 
            grid-cols-1 
            sm:grid-cols-2 
            md:grid-cols-3 
            lg:grid-cols-4 
            xl:grid-cols-6">
  <% @items.each do |item| %>
    <div class="col-span-1 
                sm:col-span-1 
                md:col-span-1 
                lg:col-span-2 
                xl:col-span-2">
      <%= render 'components/molecules/cards/responsive_card', item: item %>
    </div>
  <% end %>
</div>
```

## 🎨 상태 패턴

### 1. Form Validation States
```erb
<!-- 폼 필드 상태 패턴 -->
<div class="form-field" data-controller="field-validation">
  <label class="block text-sm font-medium text-gray-700 mb-1">
    필드 라벨 <span class="text-red-500">*</span>
  </label>
  
  <input type="text" 
         data-field-validation-target="input"
         data-action="blur->field-validation#validate"
         class="w-full px-3 py-2 border rounded-md
                border-gray-300 
                focus:border-blue-500 focus:ring-blue-500
                invalid:border-red-500 invalid:ring-red-500">
  
  <!-- 에러 메시지 -->
  <div data-field-validation-target="error" 
       class="hidden mt-1 text-sm text-red-600">
    에러 메시지가 여기에 표시됩니다
  </div>
  
  <!-- 성공 메시지 -->
  <div data-field-validation-target="success" 
       class="hidden mt-1 text-sm text-green-600">
    ✓ 올바른 형식입니다
  </div>
</div>
```

### 2. Data Loading States
```erb
<!-- 데이터 로딩 상태 패턴 -->
<div data-controller="data-loader">
  <!-- 로딩 스켈레톤 -->
  <div data-data-loader-target="skeleton" class="animate-pulse">
    <div class="space-y-4">
      <div class="h-4 bg-gray-200 rounded w-3/4"></div>
      <div class="h-4 bg-gray-200 rounded w-1/2"></div>
      <div class="h-4 bg-gray-200 rounded w-5/6"></div>
    </div>
  </div>
  
  <!-- 실제 콘텐츠 -->
  <div data-data-loader-target="content" class="hidden">
    <%= yield %>
  </div>
  
  <!-- 에러 상태 -->
  <div data-data-loader-target="error" class="hidden">
    <%= render 'components/molecules/alerts/error', 
        message: '데이터를 불러오는데 실패했습니다.' %>
  </div>
  
  <!-- 빈 상태 -->
  <div data-data-loader-target="empty" class="hidden">
    <%= render 'components/molecules/empty_states/no_data' %>
  </div>
</div>
```

## 🔄 애니메이션 패턴

### 1. Slide Transitions
```css
/* CSS 트랜지션 클래스 */
.slide-enter {
  transform: translateX(-100%);
  opacity: 0;
}

.slide-enter-active {
  transform: translateX(0);
  opacity: 1;
  transition: all 0.3s ease-out;
}

.slide-leave {
  transform: translateX(0);
  opacity: 1;
}

.slide-leave-active {
  transform: translateX(-100%);
  opacity: 0;
  transition: all 0.3s ease-in;
}
```

### 2. Fade Transitions
```css
.fade-enter {
  opacity: 0;
}

.fade-enter-active {
  opacity: 1;
  transition: opacity 0.2s ease-in;
}

.fade-leave {
  opacity: 1;
}

.fade-leave-active {
  opacity: 0;
  transition: opacity 0.2s ease-out;
}
```

## 📋 체크리스트

### UI 패턴 구현 시 확인사항
- [ ] 반응형 디자인 지원
- [ ] 키보드 네비게이션 가능
- [ ] 스크린 리더 접근성
- [ ] 로딩 상태 처리
- [ ] 에러 상태 처리
- [ ] 빈 상태 처리
- [ ] 터치 디바이스 지원
- [ ] 브라우저 호환성
- [ ] 성능 최적화
- [ ] 일관된 시각적 언어