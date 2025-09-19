# Rails 8 특화 가이드

## Rails 8 주요 변경사항

### 기본 설정 변경
- **Hotwire 기본 내장**: --minimal 옵션 없이 자동 포함
- **importmap 기본**: esbuild는 선택사항
- **Propshaft**: Sprockets 대신 기본 asset pipeline
- **Solid Queue**: 백그라운드 작업 처리 내장

### Turbo/Stimulus 필수 규칙
- ✅ JavaScript 초기화: `turbo:load` 이벤트 사용
- ❌ `DOMContentLoaded` 사용 금지
- ✅ 삭제 작업: `status: :see_other` 필수
- ✅ 검증 실패: `status: :unprocessable_entity` 필수
- ✅ Turbo 요청 리다이렉트: `render` 우선 (redirect는 예외)

### Rails 8 vs Rails 7 차이점
| 기능 | Rails 7 | Rails 8 |
|------|---------|---------|
| Hotwire | `rails hotwire:install` 필요 | 기본 내장 |
| JS 번들링 | importmap 또는 esbuild | importmap 기본 |
| Asset Pipeline | Sprockets | Propshaft |
| 백그라운드 작업 | Sidekiq 등 별도 설치 | Solid Queue 내장 |
| 에러 페이지 | 정적 HTML | 설정 가능한 브랜딩 |

### 코드 패턴 업데이트

#### 폼 응답 처리
```ruby
# Rails 8 방식
def create
  if @model.save
    respond_to do |format|
      format.turbo_stream  # Turbo 우선
      format.html { redirect_to @model, status: :see_other }
    end
  else
    render :new, status: :unprocessable_entity  # 422 필수
  end
end
```

#### 삭제 작업
```ruby
# Rails 8 방식
def destroy
  @model.destroy
  redirect_to models_path, status: :see_other  # 303 필수
end
```

#### JavaScript 이벤트 처리
```javascript
// ❌ 잘못된 방식 (Rails 7 이하)
document.addEventListener('DOMContentLoaded', () => {
  // 초기화 코드
})

// ✅ 올바른 방식 (Rails 8)
document.addEventListener('turbo:load', () => {
  // 초기화 코드
})
```

#### Turbo Frame 응답
```erb
<!-- 요청 페이지 -->
<%= turbo_frame_tag dom_id(@model) do %>
  <%= link_to "편집", edit_model_path(@model) %>
<% end %>

<!-- 응답 페이지 (edit.html.erb) -->
<%= turbo_frame_tag dom_id(@model) do %>
  <!-- 동일한 ID 필수! -->
  <%= form_with model: @model do |f| %>
    <!-- 폼 내용 -->
  <% end %>
<% end %>
```

### 체크리스트

#### 프로젝트 설정
- [ ] `config.load_defaults 8.0` 설정 확인
- [ ] Gemfile에 `rails "~> 8.0"` 확인
- [ ] Propshaft 사용 중인지 확인
- [ ] Solid Queue 설정 확인 (필요시)

#### Turbo/Stimulus 구현
- [ ] Turbo 항상 활성화 (`data: { turbo: false }` 최소화)
- [ ] status 코드 명시적 지정
- [ ] `turbo:load` 이벤트 사용
- [ ] Turbo Frame ID 일치 확인
- [ ] Turbo Stream target ID 존재 확인

#### 디버깅
- [ ] Rails 로그에서 요청 타입 확인 (TURBO_STREAM, HTML)
- [ ] 브라우저 Network 탭에서 Content-Type 확인
- [ ] Console에서 JavaScript 에러 확인
- [ ] 응답 상태 코드 확인 (200, 422, 303)

### 마이그레이션 가이드

#### Rails 7 → Rails 8 업그레이드 시
1. Gemfile 업데이트: `gem "rails", "~> 8.0"`
2. `bundle update rails`
3. `rails app:update`
4. `config.load_defaults 8.0` 설정
5. JavaScript 이벤트 리스너를 `turbo:load`로 변경
6. 삭제 작업에 `status: :see_other` 추가
7. 폼 검증 실패 시 `status: :unprocessable_entity` 추가

### 참고 자료
- [Rails 8 Release Notes](https://guides.rubyonrails.org/8_0_release_notes.html)
- [Hotwire Handbook](https://turbo.hotwired.dev/handbook/introduction)
- [Stimulus Reference](https://stimulus.hotwired.dev/reference/controllers)