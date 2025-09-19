# 접근성 가이드 (Accessibility Guide)

## 📋 개요
경비 관리 시스템의 모든 사용자가 접근할 수 있는 포용적 디자인을 위한 접근성 가이드입니다.

## 🎯 접근성 목표

### WCAG 2.1 AA 준수
- **인식 가능성 (Perceivable)**: 모든 사용자가 정보를 인식할 수 있어야 함
- **운용 가능성 (Operable)**: 모든 사용자가 인터페이스를 조작할 수 있어야 함  
- **이해 가능성 (Understandable)**: 정보와 UI 조작이 이해 가능해야 함
- **견고성 (Robust)**: 다양한 기술과 호환되어야 함

## 🎨 색상 접근성

### 색상 대비 비율
```css
/* WCAG AA 기준 준수 (4.5:1 이상) */
--text-primary: #111827;    /* 대비 비율: 15.8:1 */
--text-secondary: #374151;  /* 대비 비율: 10.7:1 */
--text-muted: #6b7280;      /* 대비 비율: 4.6:1 */

/* 큰 텍스트 (18px+) WCAG AA 기준 (3:1 이상) */
--heading-color: #1f2937;   /* 대비 비율: 12.6:1 */

/* 색맹 고려 색상 조합 */
--success: #059669;    /* 녹색 */
--warning: #d97706;    /* 주황색 */  
--danger: #dc2626;     /* 빨간색 */
--info: #2563eb;       /* 파란색 */
```

### 색상에만 의존하지 않는 정보 전달
```erb
<!-- ❌ 색상에만 의존 -->
<span class="text-red-500">오류</span>

<!-- ✅ 아이콘과 텍스트 함께 사용 -->
<span class="text-red-500 flex items-center">
  <svg class="w-4 h-4 mr-1" aria-hidden="true">
    <path d="M..."/>  <!-- 오류 아이콘 -->
  </svg>
  오류: 필수 항목을 입력해주세요
</span>
```

## ⌨️ 키보드 네비게이션

### Tab 순서 관리
```erb
<!-- 논리적 tab 순서 설정 -->
<form>
  <input type="text" tabindex="1" aria-label="이름">
  <input type="email" tabindex="2" aria-label="이메일">
  <button type="submit" tabindex="3">제출</button>
  
  <!-- 부수적인 요소는 tab에서 제외 -->
  <div tabindex="-1" aria-hidden="true">장식용 요소</div>
</form>
```

### 키보드 이벤트 지원
```javascript
// 모든 인터랙티브 요소에 키보드 지원
document.addEventListener('keydown', function(e) {
  // Enter 키로 버튼 활성화
  if (e.key === 'Enter' && e.target.matches('[role="button"]')) {
    e.target.click();
  }
  
  // Escape 키로 모달 닫기
  if (e.key === 'Escape' && document.querySelector('.modal.show')) {
    closeModal();
  }
  
  // 방향키로 메뉴 네비게이션
  if (e.target.matches('[role="menuitem"]')) {
    handleMenuNavigation(e);
  }
});
```

### Focus 관리
```erb
<!-- 명확한 focus 스타일 -->
<style>
.focus-visible:focus {
  outline: 2px solid #2563eb;
  outline-offset: 2px;
}

.focus-visible:focus:not(:focus-visible) {
  outline: none;
}
</style>

<!-- Skip to content 링크 -->
<a href="#main-content" class="sr-only focus:not-sr-only focus:absolute focus:top-4 focus:left-4 bg-blue-600 text-white px-4 py-2 rounded">
  메인 콘텐츠로 건너뛰기
</a>

<main id="main-content" tabindex="-1">
  <!-- 메인 콘텐츠 -->
</main>
```

## 🔊 스크린 리더 지원

### ARIA 레이블과 설명
```erb
<!-- 적절한 ARIA 레이블 -->
<button aria-label="경비 항목 삭제" aria-describedby="delete-help">
  <svg aria-hidden="true"><!-- 삭제 아이콘 --></svg>
</button>
<div id="delete-help" class="sr-only">
  이 작업은 되돌릴 수 없습니다
</div>

<!-- 폼 필드 레이블 연결 -->
<label for="expense-amount">경비 금액 (원)</label>
<input type="number" 
       id="expense-amount" 
       aria-required="true"
       aria-describedby="amount-help amount-error">
<div id="amount-help">숫자만 입력해주세요</div>
<div id="amount-error" aria-live="polite" class="sr-only">
  <!-- 에러 메시지가 동적으로 표시됨 -->
</div>
```

### 의미 있는 구조
```erb
<!-- 적절한 헤딩 구조 -->
<h1>경비 관리 시스템</h1>
  <h2>이번 달 경비 요약</h2>
    <h3>승인 대기 중</h3>
    <h3>승인 완료</h3>
  <h2>경비 항목 목록</h2>
    <h3>필터 옵션</h3>

<!-- 랜드마크 역할 정의 -->
<header role="banner">
  <nav role="navigation" aria-label="주 메뉴">
    <!-- 네비게이션 메뉴 -->
  </nav>
</header>

<main role="main">
  <!-- 메인 콘텐츠 -->
</main>

<aside role="complementary" aria-label="부가 정보">
  <!-- 사이드바 콘텐츠 -->
</aside>

<footer role="contentinfo">
  <!-- 푸터 정보 -->
</footer>
```

### 동적 콘텐츠 알림
```erb
<!-- 상태 변경 알림 -->
<div aria-live="polite" aria-atomic="true" class="sr-only" id="status-message">
  <!-- 상태 메시지가 동적으로 업데이트됨 -->
</div>

<div aria-live="assertive" class="sr-only" id="error-message">
  <!-- 중요한 에러 메시지 -->
</div>

<!-- 로딩 상태 표시 -->
<button aria-describedby="loading-state">
  저장
</button>
<div id="loading-state" aria-live="polite" class="sr-only">
  <!-- 로딩 중일 때: "저장 중입니다..." -->
</div>
```

## 📱 모바일 접근성

### 터치 대상 크기
```css
/* 최소 44px × 44px 터치 대상 */
.touch-target {
  min-height: 44px;
  min-width: 44px;
  padding: 12px 16px;
}

/* 인접한 터치 대상 간 충분한 간격 */
.touch-list > * + * {
  margin-top: 8px;
}
```

### 모바일 스크린 리더 지원
```erb
<!-- iOS VoiceOver / Android TalkBack 지원 -->
<button type="button" 
        aria-label="메뉴 열기"
        aria-expanded="false"
        aria-controls="mobile-menu">
  <span aria-hidden="true">☰</span>
</button>

<div id="mobile-menu" 
     role="menu" 
     aria-hidden="true"
     aria-labelledby="menu-button">
  <!-- 메뉴 항목들 -->
</div>
```

## 🎯 컴포넌트별 접근성 가이드

### 버튼 컴포넌트
```erb
<!-- app/views/components/atoms/buttons/_primary.html.erb -->
<%
  button_tag = link ? 'a' : 'button'
  button_type = link ? nil : (type || 'button')
  button_href = link ? href : nil
  button_role = link ? 'button' : nil
%>

<%= content_tag button_tag, 
    href: button_href,
    type: button_type,
    role: button_role,
    disabled: disabled,
    aria: {
      label: aria_label,
      describedby: aria_describedby,
      expanded: aria_expanded,
      controls: aria_controls
    },
    class: css_classes('btn', 'btn-primary', custom_class),
    data: data_attributes do %>
  
  <% if loading %>
    <span aria-hidden="true" class="spinner"></span>
    <span class="sr-only">로딩 중...</span>
  <% end %>
  
  <% if icon %>
    <%= icon_component(icon, aria_hidden: true) %>
  <% end %>
  
  <span><%= text %></span>
<% end %>
```

### 폼 필드 컴포넌트
```erb
<!-- app/views/components/molecules/forms/_field.html.erb -->
<div class="form-field <%= 'has-error' if errors.present? %>">
  <%= form.label field, label, class: 'form-label' do %>
    <%= label %>
    <% if required %>
      <span class="required" aria-label="필수 항목">*</span>
    <% end %>
  <% end %>
  
  <%= form.text_field field,
      class: css_classes('form-input', { 'is-invalid' => errors.present? }),
      aria: {
        required: required,
        describedby: [help_id, error_id].compact.join(' '),
        invalid: errors.present?
      } %>
  
  <% if help_text %>
    <div id="<%= help_id %>" class="form-help">
      <%= help_text %>
    </div>
  <% end %>
  
  <% if errors.present? %>
    <div id="<%= error_id %>" 
         class="form-error" 
         aria-live="polite"
         role="alert">
      <%= errors.first %>
    </div>
  <% end %>
</div>
```

### 테이블 컴포넌트
```erb
<!-- app/views/components/organisms/tables/_data_table.html.erb -->
<div class="table-container" role="region" aria-label="<%= caption %>">
  <table class="data-table" 
         aria-label="<%= caption %>"
         aria-describedby="table-summary">
    
    <caption class="sr-only">
      <%= caption %>
      <%= "총 #{items.count}개 항목" if items.respond_to?(:count) %>
    </caption>
    
    <thead>
      <tr>
        <% columns.each do |column| %>
          <th scope="col" 
              <%= 'aria-sort="ascending"' if sorted_column == column[:key] && sort_direction == 'asc' %>
              <%= 'aria-sort="descending"' if sorted_column == column[:key] && sort_direction == 'desc' %>>
            
            <% if column[:sortable] %>
              <%= link_to column[:label], 
                  sort_url(column[:key]), 
                  aria: { label: "#{column[:label]}로 정렬" } %>
            <% else %>
              <%= column[:label] %>
            <% end %>
          </th>
        <% end %>
      </tr>
    </thead>
    
    <tbody>
      <% items.each_with_index do |item, index| %>
        <tr <%= 'aria-selected="true"' if selected_items.include?(item.id) %>>
          <% columns.each do |column| %>
            <td>
              <% if column[:key] == columns.first[:key] %>
                <th scope="row"><%= render_cell_content(item, column) %></th>
              <% else %>
                <%= render_cell_content(item, column) %>
              <% end %>
            </td>
          <% end %>
        </tr>
      <% end %>
    </tbody>
  </table>
  
  <div id="table-summary" class="sr-only">
    데이터 테이블: <%= items.count %>개 행, <%= columns.count %>개 열
  </div>
</div>
```

### 모달 컴포넌트
```erb
<!-- app/views/components/molecules/modals/_content.html.erb -->
<div class="modal-backdrop" 
     aria-hidden="true"
     data-action="click->modal#close">
</div>

<div class="modal-container" 
     role="dialog" 
     aria-modal="true"
     aria-labelledby="modal-title"
     aria-describedby="modal-description"
     data-modal-target="content">
  
  <div class="modal-header">
    <h2 id="modal-title" class="modal-title">
      <%= title %>
    </h2>
    
    <button type="button" 
            class="modal-close"
            aria-label="모달 닫기"
            data-action="click->modal#close">
      <span aria-hidden="true">&times;</span>
    </button>
  </div>
  
  <div class="modal-body">
    <% if description %>
      <p id="modal-description" class="sr-only">
        <%= description %>
      </p>
    <% end %>
    
    <%= yield %>
  </div>
  
  <div class="modal-footer">
    <%= render 'components/atoms/buttons/secondary', 
        text: '취소', 
        data: { action: 'click->modal#close' } %>
    <%= render 'components/atoms/buttons/primary', 
        text: '확인',
        data: { action: 'click->modal#confirm' } %>
  </div>
</div>
```

## 🧪 접근성 테스트

### 자동화된 테스트
```ruby
# test/system/accessibility_test.rb
require 'test_helper'

class AccessibilityTest < ApplicationSystemTestCase
  test "page has proper heading structure" do
    visit root_path
    
    # 헤딩 구조 검증
    assert_selector 'h1', count: 1
    assert_no_selector 'h3', text: /.+/ do |h3|
      h2_before = page.all('h2').any? { |h2| h2['data-order'].to_i < h3['data-order'].to_i }
      assert h2_before, "h3 found before h2: #{h3.text}"
    end
  end
  
  test "all interactive elements are keyboard accessible" do
    visit root_path
    
    # 모든 버튼이 키보드로 접근 가능한지 확인
    page.all('button, [role="button"], a').each do |element|
      element.send_keys(:tab)
      assert element.matches_css?(':focus'), "Element not focusable: #{element.tag_name}"
    end
  end
  
  test "forms have proper labels" do
    visit new_expense_path
    
    # 모든 입력 필드가 레이블을 가지는지 확인
    page.all('input, select, textarea').each do |input|
      label_text = find_label_for(input)
      assert label_text.present?, "Input has no label: #{input['name']}"
    end
  end
  
  private
  
  def find_label_for(input)
    # aria-label, aria-labelledby, or associated label 찾기
    input['aria-label'] || 
    find_by_id(input['aria-labelledby'])&.text ||
    page.find("label[for='#{input['id']}']", wait: 0)&.text
  rescue Capybara::ElementNotFound
    nil
  end
end
```

### 수동 테스트 체크리스트
```markdown
## 키보드 네비게이션 테스트
- [ ] Tab 키로 모든 인터랙티브 요소 접근 가능
- [ ] Shift+Tab으로 역순 탐색 가능  
- [ ] Enter/Space 키로 버튼 활성화 가능
- [ ] Escape 키로 모달/드롭다운 닫기 가능
- [ ] 방향키로 메뉴 탐색 가능

## 스크린 리더 테스트 (NVDA/JAWS/VoiceOver)
- [ ] 페이지 제목 읽기
- [ ] 헤딩 구조로 탐색 가능
- [ ] 폼 레이블 정확히 읽기
- [ ] 에러 메시지 알림
- [ ] 상태 변경 알림
- [ ] 테이블 헤더와 셀 연결

## 시각적 접근성 테스트
- [ ] 색상 대비 비율 확인 (WebAIM Contrast Checker)
- [ ] 색맹 시뮬레이션 테스트
- [ ] 200% 확대 시 사용성 확인
- [ ] Focus 표시기 명확하게 보임

## 모바일 접근성 테스트
- [ ] 터치 대상 크기 충분함 (44px+)
- [ ] 인접 요소 간 충분한 간격
- [ ] iOS VoiceOver 동작 확인
- [ ] Android TalkBack 동작 확인
```

## 📋 접근성 체크리스트

### 개발 단계
- [ ] 의미 있는 HTML 구조 사용
- [ ] 적절한 ARIA 속성 추가
- [ ] 키보드 탐색 지원
- [ ] 색상 대비 비율 확인
- [ ] 대체 텍스트 제공

### 테스트 단계  
- [ ] 자동화된 접근성 테스트 통과
- [ ] 스크린 리더 테스트 수행
- [ ] 키보드 전용 탐색 테스트
- [ ] 모바일 접근성 테스트
- [ ] 다양한 사용자 환경 테스트

### 배포 단계
- [ ] WCAG 2.1 AA 준수 확인
- [ ] 접근성 문서 업데이트
- [ ] 팀 교육 완료
- [ ] 사용자 피드백 수집 계획