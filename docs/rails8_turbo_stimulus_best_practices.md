# Rails 8 Turbo & Stimulus 베스트 프랙티스

## 1. Turbo Stream 업데이트 문제 해결

### 문제
- `turbo_stream.replace(@model)` 사용 시 업데이트가 즉시 반영되지 않음
- 페이지 새로고침 필요

### 원인
- `turbo_stream.replace` 사용 시 반드시 렌더링할 partial을 명시해야 함
- partial을 명시하지 않으면 Rails가 어떤 템플릿을 사용할지 알 수 없음

### 해결책
```ruby
# 잘못된 예
turbo_stream.replace(@expense_code)

# 올바른 예
turbo_stream.replace(@expense_code, 
  partial: 'admin/expense_codes/expense_code', 
  locals: { expense_code: @expense_code }
)
```

## 2. Turbo Frame 사용 모범 사례

### 모달 처리
```erb
<!-- 수정 링크에 turbo_frame 지정 -->
<%= link_to "수정", edit_path(resource), 
    data: { turbo_frame: "modal" } %>
```

### 응답 처리
```ruby
# 컨트롤러에서 modal frame 비우기
turbo_stream.replace('modal', '')
```

## 3. Form 제출 설정

### AJAX 제출
```erb
<%= form_with(model: resource, local: false) do |form| %>
  <!-- local: false로 AJAX 제출 활성화 -->
<% end %>
```

### Stimulus 컨트롤러 연결
```erb
<%= form_with(model: resource, 
    data: { controller: "form-controller" }) do |form| %>
```

## 4. DOM ID 일관성

### 리스트 아이템
```erb
<tr id="<%= dom_id(expense_code) %>">
  <!-- dom_id 헬퍼로 일관된 ID 생성 -->
</tr>
```

### Turbo Stream 타겟팅
```ruby
# dom_id와 동일한 ID를 타겟으로 사용
turbo_stream.replace(dom_id(@expense_code), ...)
# 또는 모델 객체 직접 사용
turbo_stream.replace(@expense_code, ...)
```

## 5. 에러 처리

### 폼 검증 실패 시
```ruby
if @model.save
  # turbo_stream 응답
else
  render :edit, status: :unprocessable_entity
  # status: :unprocessable_entity 필수
end
```

## 6. 플래시 메시지 처리

### Turbo Stream으로 플래시 업데이트
```ruby
turbo_stream.replace('flash', 
  partial: 'shared/flash',
  locals: { flash: { notice: '메시지' } }
)
```

## 7. 리스트 업데이트 패턴

### 새 항목 추가
```ruby
turbo_stream.prepend('list_container', 
  partial: 'item', 
  locals: { item: @item }
)
```

### 항목 삭제
```ruby
turbo_stream.remove(@item)
```

### 항목 수정
```ruby
turbo_stream.replace(@item, 
  partial: 'item', 
  locals: { item: @item }
)
```

## 8. Stimulus 컨트롤러 모범 사례

### 데이터 속성 활용
```javascript
export default class extends Controller {
  static targets = ["field"]
  static values = { url: String }
  
  connect() {
    // 컨트롤러 연결 시 초기화
  }
}
```

### HTML 데이터 바인딩
```erb
<div data-controller="my-controller"
     data-my-controller-url-value="<%= some_path %>">
  <div data-my-controller-target="field">
  </div>
</div>
```

## 9. 성능 최적화

### Turbo 캐싱 제어
```erb
<meta name="turbo-cache-control" content="no-cache">
```

### 특정 요소 캐싱 방지
```erb
<div data-turbo-permanent>
  <!-- 페이지 전환 시에도 유지되는 콘텐츠 -->
</div>
```

## 10. 디버깅 팁

### Turbo 이벤트 로깅
```javascript
document.addEventListener('turbo:load', () => {
  console.log('Turbo page loaded')
})

document.addEventListener('turbo:frame-load', (event) => {
  console.log('Frame loaded:', event.detail)
})
```

### 응답 검증
브라우저 개발자 도구에서:
1. Network 탭에서 요청 확인
2. Response가 text/vnd.turbo-stream.html 타입인지 확인
3. Response 내용이 올바른 turbo-stream 액션인지 확인

## CLAUDE.md 반영 권장사항

```markdown
### Turbo Stream 업데이트 규칙
- **중요**: turbo_stream.replace 사용 시 반드시 partial과 locals 명시
- 예: `turbo_stream.replace(@model, partial: 'path/to/partial', locals: { model: @model })`
- DOM ID 일관성 유지: `dom_id(model)` 헬퍼 사용
- 폼 검증 실패 시 `status: :unprocessable_entity` 필수

### Stimulus 컨트롤러 규칙
- targets와 values를 명확히 정의
- 데이터 속성으로 설정 전달
- connect() 메서드에서 초기화 수행
```