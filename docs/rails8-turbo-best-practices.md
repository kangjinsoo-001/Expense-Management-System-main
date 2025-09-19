# Rails 8 Turbo 모범 사례

## 1. Turbo Stream 실시간 업데이트 패턴

### 문제가 되는 패턴
```ruby
# ❌ 잘못된 예시 - ID 중복 문제 발생
turbo_stream.after 'flash' do
  render 'shared/turbo_flash', type: :notice, message: '메시지'
end
```

### 올바른 패턴
```ruby
# ✅ 권장 - Stimulus와 함께 사용
# 컨트롤러에서는 데이터만 업데이트
render turbo_stream: [
  turbo_stream.replace("list", partial: "list", locals: { items: @items }),
  turbo_stream.replace("form", partial: "form", locals: { item: Item.new })
]
```

### Turbo Stream과 JavaScript 연동
```javascript
// ❌ 문제: fetch API는 Turbo Stream을 자동 처리하지 못함
fetch(url, {
  method: 'POST',
  headers: { 'Accept': 'text/vnd.turbo-stream.html' },
  body: formData
})

// ✅ 해결: 동적 폼 생성으로 Turbo가 자동 처리하도록 함
const form = document.createElement('form')
form.method = 'POST'
form.action = url
document.body.appendChild(form)
form.requestSubmit()  // Turbo가 가로채서 처리
form.remove()
```

## 2. 동적 폼 필드 추가/삭제

### Stimulus + Template 패턴
```erb
<!-- 템플릿 정의 -->
<template id="nested-template">
  <%= form.fields_for :items, Item.new, child_index: "NEW_RECORD" do |f| %>
    <%= render "item_fields", f: f %>
  <% end %>
</template>

<!-- Stimulus 컨트롤러 -->
<div data-controller="nested">
  <div data-nested-target="list">
    <%= form.fields_for :items do |f| %>
      <%= render "item_fields", f: f %>
    <% end %>
  </div>
  <button data-action="nested#add">추가</button>
</div>
```

```javascript
// nested_controller.js
add(event) {
  event.preventDefault()
  const template = document.getElementById("nested-template")
  const content = template.content.cloneNode(true)
  const timestamp = new Date().getTime()
  const html = content.firstElementChild.outerHTML
                      .replace(/NEW_RECORD/g, timestamp)
  this.listTarget.insertAdjacentHTML("beforeend", html)
}
```

## 3. 플래시 메시지 처리

### 서버 측 (Rails)
```ruby
# application.html.erb
<div id="flash_container"></div>  <!-- Turbo Stream 타겟 -->
<div id="flash">                   <!-- 일반 플래시 -->
  <%= render 'shared/flash' %>
</div>
```

### 클라이언트 측 (Stimulus)
```javascript
showFlash(type, message) {
  const flashHTML = `
    <div class="flash-${type}" data-turbo-temporary>
      ${message}
      <button onclick="this.parentElement.remove()">×</button>
    </div>
  `
  document.getElementById("flash_container")
          .insertAdjacentHTML("afterbegin", flashHTML)
}
```

## 4. Form 제출 처리

### Turbo 호환 폼
```erb
<%= form_with model: @model, data: {
  turbo_frame: "_top",               # 전체 페이지 업데이트
  turbo_confirm: "확인하시겠습니까?",  # 확인 대화상자
  action: "turbo:submit-end->controller#method"  # Stimulus 연동
} do |form| %>
```

### 컨트롤러 응답
```ruby
respond_to do |format|
  format.html { redirect_to path, notice: "성공" }
  format.turbo_stream  # turbo_stream.erb 자동 렌더링
end
```

## 5. 삭제 작업

### button_to 사용 (권장)
```erb
<%= button_to "삭제", path, 
              method: :delete,
              params: { id: item.id },
              data: { 
                turbo_confirm: "삭제하시겠습니까?",
                turbo_frame: "_top"
              },
              class: "btn-danger" %>
```

## 6. Turbo 캐시 제어

### 특정 페이지 캐시 비활성화
```erb
<% content_for :head do %>
  <meta name="turbo-cache-control" content="no-cache">
<% end %>
```

### 프로그래밍 방식
```ruby
class ApplicationController < ActionController::Base
  def disable_turbo_cache
    response.headers["Turbo-Visit-Control"] = "reload"
  end
end
```

## 7. 체크리스트

### 새 기능 구현 시
- [ ] Turbo Stream 응답에서 ID 중복 확인
- [ ] 플래시 메시지는 Stimulus로 처리
- [ ] 폼에 적절한 data 속성 설정
- [ ] button_to 사용 (link_to 대신)
- [ ] Stimulus 컨트롤러 연결 확인

### 디버깅 시
- [ ] 브라우저 콘솔 에러 확인
- [ ] Network 탭에서 Turbo Stream 응답 확인
- [ ] DOM에서 중복 ID 검사
- [ ] Stimulus 디버그 모드 활성화

## 8. 참고 자료
- Turbo 공식 문서: https://turbo.hotwired.dev
- Stimulus 공식 문서: https://stimulus.hotwired.dev
- Rails 8 Turbo 가이드: Rails Guides