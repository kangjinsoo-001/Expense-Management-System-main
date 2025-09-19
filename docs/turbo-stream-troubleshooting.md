# Turbo Stream 실시간 렌더링 문제 해결 가이드

## 문제 상황
Rails 8 + Hotwire 환경에서 발생하는 Turbo Stream 렌더링 문제들

### 케이스 1: "첫 번째는 작동하지만 두 번째부터 먹통"
#### 증상
1. 멤버 추가/삭제 시 첫 번째 작업은 정상 동작
2. 두 번째 작업부터 플래시 메시지가 표시되지 않음
3. DOM 업데이트가 실시간으로 반영되지 않음
4. F5(새로고침) 후에만 정상 작동

#### 원인
1. **DOM ID 중복**: Turbo Stream으로 교체된 요소의 ID가 중복되어 충돌
2. **Turbo 캐시 문제**: Turbo Drive가 페이지 상태를 캐싱하여 폼의 CSRF 토큰이나 상태가 동기화되지 않음
3. **플래시 메시지 ID 중복**: 같은 ID로 플래시를 계속 추가하려 해서 실패

### 케이스 2: Turbo Stream 응답은 오지만 DOM이 업데이트되지 않음
#### 증상
1. 서버에서 200 OK 응답과 함께 올바른 Turbo Stream HTML 반환
2. 콘솔에 JavaScript 에러 없음
3. DOM에 변화가 전혀 없음

#### 원인
**fetch API가 Turbo Stream 응답을 자동으로 처리하지 못함**

#### 해결책
```javascript
// ❌ 작동하지 않는 코드
fetch(url, {
  method: 'POST',
  headers: {
    'Accept': 'text/vnd.turbo-stream.html'
  },
  body: formData
})

// ✅ 작동하는 코드 - 동적 폼 생성 후 Turbo가 처리하도록 함
const form = document.createElement('form')
form.method = 'POST'
form.action = url
form.style.display = 'none'

// CSRF 토큰 추가
const csrfInput = document.createElement('input')
csrfInput.type = 'hidden'
csrfInput.name = 'authenticity_token'
csrfInput.value = document.querySelector('[name="csrf-token"]').content
form.appendChild(csrfInput)

// 데이터 추가
for (const [key, value] of formData.entries()) {
  const input = document.createElement('input')
  input.type = 'hidden'
  input.name = key
  input.value = value
  form.appendChild(input)
}

// 폼 제출 - Turbo가 자동으로 가로채서 처리
document.body.appendChild(form)
form.requestSubmit()
form.remove()
```

## 해결 방법

### 1. Stimulus Controller 패턴 적용
클라이언트 측에서 플래시 메시지를 관리하도록 Stimulus 컨트롤러 생성

```javascript
// app/javascript/controllers/approver_group_controller.js
import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["membersList", "addMemberForm", "flashContainer"]
  
  // 멤버 추가 성공 시 호출
  memberAdded(event) {
    const [data, status, xhr] = event.detail
    
    if (status === "ok") {
      this.showFlash("notice", "멤버가 추가되었습니다.")
    }
  }
  
  // 플래시 메시지 표시
  showFlash(type, message) {
    const flashHTML = `<div class="flash-message">...</div>`
    const container = document.getElementById("flash_container") || this.element
    container.insertAdjacentHTML("afterbegin", flashHTML)
    
    // 5초 후 자동 제거
    setTimeout(() => {
      const flash = container.querySelector(".flash-message")
      if (flash) flash.remove()
    }, 5000)
  }
}
```

### 2. 뷰에 Stimulus 연결
```erb
<!-- show.html.erb -->
<div class="container" data-controller="approver-group">
  <!-- 폼에 이벤트 연결 -->
  <%= form_with data: { 
    turbo_frame: "_top",
    action: "turbo:submit-end->approver-group#memberAdded"
  } do |form| %>
  
  <!-- 삭제 버튼에도 이벤트 연결 -->
  <%= button_to data: {
    action: "turbo:submit-end->approver-group#memberRemoved"
  } %>
</div>
```

### 3. 컨트롤러 단순화
```ruby
# app/controllers/admin/approver_groups_controller.rb
def add_member
  # ... 로직 ...
  
  respond_to do |format|
    format.turbo_stream {
      # 플래시 메시지 제거, DOM 업데이트만 처리
      render turbo_stream: [
        turbo_stream.replace("members_list_wrapper", 
          partial: "admin/approver_groups/members_list_wrapper", 
          locals: { approver_group: @approver_group, members: @members }
        ),
        turbo_stream.replace("add_member_form",
          partial: "admin/approver_groups/add_member_form",
          locals: { approver_group: @approver_group, available_users: @available_users }
        )
      ]
    }
  end
end
```

### 4. 레이아웃에 플래시 컨테이너 추가
```erb
<!-- layouts/admin.html.erb -->
<!-- 플래시 메시지 전용 컨테이너 -->
<div id="flash_container"></div>
<div id="flash">
  <%= render 'shared/flash' %>
</div>
```

## 주의사항

### 피해야 할 패턴
1. ❌ Turbo Stream에서 같은 ID로 계속 append/prepend
2. ❌ 캐시 관련 헤더를 과도하게 설정
3. ❌ turbo_stream.erb 파일에서 복잡한 로직 처리

### 권장 패턴
1. ✅ Stimulus로 클라이언트 측 동작 관리
2. ✅ 서버는 데이터 업데이트와 DOM 교체만 담당
3. ✅ 플래시 메시지는 클라이언트에서 생성
4. ✅ ID는 고유하게 유지 (timestamp 활용)

## 디버깅 체크리스트
- [ ] 브라우저 개발자 도구에서 Network 탭 확인 (Turbo Stream 응답 확인)
- [ ] Console에 JavaScript 에러가 없는지 확인
- [ ] DOM Inspector에서 ID 중복이 없는지 확인
- [ ] Stimulus 컨트롤러가 제대로 연결되었는지 확인 (`console.log` 활용)

## 관련 문서
- [Hotwire Turbo 공식 문서](https://turbo.hotwired.dev)
- [Stimulus 공식 문서](https://stimulus.hotwired.dev)
- Rails 8의 Turbo 통합 가이드