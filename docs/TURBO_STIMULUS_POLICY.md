# Turbo & Stimulus 사용 정책 (Rails Way)

## 핵심 원칙
**Turbo는 Rails 8의 기본 기능으로, 항상 활성화 상태를 유지합니다.**  
비활성화는 정말 필요한 예외적인 경우에만 적용합니다.

## Turbo 사용 정책

### 1. 기본 원칙 - Turbo 항상 활성화

#### ✅ Turbo를 활성화 상태로 유지하는 경우 (기본값)
- **모든 폼 제출** (파일 업로드 포함)
- **CRUD 작업** (Create, Read, Update, Delete)
- **페이지 간 네비게이션**
- **리다이렉트가 필요한 작업**

```erb
<!-- 기본: Turbo 자동 활성화 -->
<%= form_with model: @expense_item do |form| %>
  <!-- 파일 업로드도 Turbo가 처리 -->
  <%= form.file_field :receipt %>
<% end %>
```

#### ❌ Turbo 비활성화가 정당한 예외 경우
- **외부 결제 게이트웨이 연동** (PG사 페이지 이동)
- **파일 다운로드** (PDF, Excel 등)
- **OAuth 인증 플로우** (외부 인증 서비스)
- **레거시 JavaScript 라이브러리와의 충돌**

```erb
<!-- 예외적으로 Turbo 비활성화 -->
<%= form_with url: external_payment_path, data: { turbo: false } do |form| %>
  <!-- 외부 결제 시스템으로 이동 -->
<% end %>
```

### 2. CRUD 작업 표준 패턴

#### Create/Update 작업
```ruby
# 컨트롤러
def create
  @expense_item = @expense_sheet.expense_items.build(expense_item_params)
  
  if @expense_item.save
    respond_to do |format|
      # Turbo Stream으로 동적 업데이트
      format.turbo_stream do
        render turbo_stream: [
          turbo_stream.append("expense_items", partial: "expense_item", locals: { expense_item: @expense_item }),
          turbo_stream.replace("notice", partial: "shared/notice", locals: { message: "항목이 추가되었습니다." })
        ]
      end
      # 일반 HTML 요청 (폴백)
      format.html { redirect_to @expense_sheet, notice: "항목이 추가되었습니다." }
    end
  else
    render :new, status: :unprocessable_entity
  end
end
```

#### Delete 작업
```ruby
# 컨트롤러
def destroy
  @expense_item.destroy
  
  respond_to do |format|
    format.turbo_stream do
      render turbo_stream: [
        turbo_stream.remove(@expense_item),
        turbo_stream.update("total_amount", @expense_sheet.total_amount)
      ]
    end
    format.html { redirect_to @expense_sheet, status: :see_other }
  end
end
```

```erb
<!-- 뷰 -->
<%= button_to "삭제", 
              expense_item_path(item), 
              method: :delete,
              form: { data: { turbo_confirm: "정말 삭제하시겠습니까?" } },
              class: "btn btn-danger" %>
```

### 3. Turbo Frame 활용

#### 부분 페이지 업데이트
```erb
<!-- 목록 페이지 -->
<turbo-frame id="expense_item_<%= item.id %>">
  <div class="expense-item">
    <%= item.description %>
    <%= link_to "편집", edit_expense_item_path(item) %>
  </div>
</turbo-frame>

<!-- 편집 폼 -->
<turbo-frame id="expense_item_<%= @expense_item.id %>">
  <%= form_with model: @expense_item do |form| %>
    <!-- 폼 필드들 -->
  <% end %>
</turbo-frame>
```

### 4. Turbo Stream 활용

#### 실시간 업데이트
```erb
<!-- app/views/expense_items/create.turbo_stream.erb -->
<%= turbo_stream.append "expense_items" do %>
  <%= render partial: "expense_item", locals: { expense_item: @expense_item } %>
<% end %>

<%= turbo_stream.update "stats" do %>
  <%= render partial: "expense_sheets/stats", locals: { expense_sheet: @expense_sheet } %>
<% end %>
```

## Stimulus 컨트롤러 정책

### 1. 네이밍 규칙
- **데이터 중심**: `[model]_controller.js` (예: expense_item_controller.js)
- **UI 컴포넌트**: `[component]_controller.js` (예: dropdown_controller.js)
- **유틸리티**: `[function]_controller.js` (예: autosave_controller.js)

### 2. Stimulus 역할 정의

#### ✅ Stimulus를 사용하는 경우
- **클라이언트 사이드 상태 관리**
- **DOM 조작 및 이벤트 처리**
- **서드파티 라이브러리 통합** (Choice.js, Chart.js 등)
- **실시간 검증 및 계산**

```javascript
// app/javascript/controllers/expense_item_controller.js
import { Controller } from "@hotwired/stimulus"
import Choices from "choices.js"

export default class extends Controller {
  static targets = ["expenseCode", "customFields", "amount", "total"]
  static values = { 
    customFieldsUrl: String,
    updateUrl: String 
  }
  
  connect() {
    this.initializeChoices()
  }
  
  initializeChoices() {
    if (this.hasExpenseCodeTarget) {
      this.choices = new Choices(this.expenseCodeTarget, {
        removeItemButton: true,
        searchEnabled: true,
        placeholder: true,
        placeholderValue: '경비 코드를 선택하세요'
      })
    }
  }
  
  // data-action="change->expense-item#loadCustomFields"
  async loadCustomFields(event) {
    const expenseCodeId = event.target.value
    if (!expenseCodeId) return
    
    const response = await fetch(`${this.customFieldsUrlValue}?expense_code_id=${expenseCodeId}`)
    const html = await response.text()
    this.customFieldsTarget.innerHTML = html
  }
  
  // data-action="input->expense-item#calculateTotal"
  calculateTotal() {
    const amounts = this.amountTargets.map(el => parseFloat(el.value) || 0)
    const total = amounts.reduce((sum, amount) => sum + amount, 0)
    this.totalTarget.textContent = total.toLocaleString()
  }
  
  disconnect() {
    if (this.choices) {
      this.choices.destroy()
    }
  }
}
```

### 3. HTML과 Stimulus 연결

```erb
<%= form_with model: [@expense_sheet, @expense_item],
              data: { 
                controller: "expense-item",
                expense_item_custom_fields_url_value: custom_fields_expense_codes_path,
                expense_item_update_url_value: expense_sheet_expense_item_path(@expense_sheet, @expense_item)
              } do |form| %>
  
  <%= form.select :expense_code_id,
                  options_from_collection_for_select(@expense_codes, :id, :name),
                  { prompt: "선택하세요" },
                  { 
                    data: { 
                      expense_item_target: "expenseCode",
                      action: "change->expense-item#loadCustomFields"
                    }
                  } %>
  
  <div data-expense-item-target="customFields">
    <!-- 동적으로 로드되는 커스텀 필드 -->
  </div>
  
  <%= form.number_field :amount,
                        data: { 
                          expense_item_target: "amount",
                          action: "input->expense-item#calculateTotal"
                        } %>
  
  <div>
    합계: <span data-expense-item-target="total">0</span>
  </div>
<% end %>
```

## 모범 사례 체크리스트

### 새로운 기능 개발 시
- [ ] **Turbo 우선**: Turbo로 해결 가능한가?
- [ ] **Turbo Stream**: 동적 업데이트가 필요한가? → Turbo Stream 사용
- [ ] **Turbo Frame**: 부분 업데이트가 필요한가? → Turbo Frame 사용
- [ ] **Stimulus 최소화**: 정말 JavaScript가 필요한가?
- [ ] **서버 중심**: 로직을 서버로 옮길 수 있는가?

### 폼 제출 시
- [ ] **기본값 유지**: `data: { turbo: false }` 없이 시작
- [ ] **파일 업로드**: Turbo가 자동 처리 (비활성화 불필요)
- [ ] **리다이렉트**: Turbo가 자동 처리 (비활성화 불필요)
- [ ] **검증 오류**: `status: :unprocessable_entity` 사용

### 삭제 작업 시
- [ ] **Turbo Stream 응답**: 동적으로 DOM 업데이트
- [ ] **확인 대화상자**: `data: { turbo_confirm: "..." }` 사용
- [ ] **상태 코드**: `:see_other` 사용

## 마이그레이션 가이드

### 기존 코드 개선 예시

#### Before (Turbo 비활성화)
```erb
<%= form_with model: @expense_item, data: { turbo: false } do |form| %>
  <!-- 폼 내용 -->
<% end %>
```

#### After (Turbo 활성화 + Stream)
```erb
<%= form_with model: @expense_item do |form| %>
  <!-- 폼 내용 -->
<% end %>

<!-- 컨트롤러에서 Turbo Stream 응답 추가 -->
```

### 점진적 마이그레이션 전략
1. **Phase 1**: 새로운 기능은 Turbo 활성화로 개발
2. **Phase 2**: 기존 삭제 기능을 Turbo Stream으로 전환
3. **Phase 3**: 폼 제출을 Turbo Frame/Stream으로 개선
4. **Phase 4**: 불필요한 Stimulus 컨트롤러 정리

## 트러블슈팅

### 일반적인 문제와 해결책

#### 1. 리다이렉트가 작동하지 않음
```ruby
# 문제: Turbo에서 리다이렉트 미작동
redirect_to @expense_sheet  # ❌

# 해결: 적절한 상태 코드 추가
redirect_to @expense_sheet, status: :see_other  # ✅
```

#### 2. 폼 제출 후 화면이 업데이트되지 않음
```ruby
# 문제: 422 오류 시 폼이 대체되지 않음
render :new  # ❌

# 해결: 상태 코드 추가
render :new, status: :unprocessable_entity  # ✅
```

#### 3. JavaScript 이벤트가 작동하지 않음
```javascript
// 문제: 동적으로 추가된 요소에 이벤트 미작동
document.addEventListener('DOMContentLoaded', () => {})  // ❌

// 해결: Turbo 이벤트 사용
document.addEventListener('turbo:load', () => {})  // ✅
```

## 참고 자료
- [Turbo Handbook](https://turbo.hotwired.dev/handbook/introduction)
- [Stimulus Handbook](https://stimulus.hotwired.dev/handbook/introduction)
- [Rails 8 Hotwire 가이드](https://guides.rubyonrails.org/working_with_javascript_in_rails.html)