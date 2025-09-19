// 실시간 검증 기능에 대한 JavaScript 단위 테스트

// Stimulus 컨트롤러 테스트 예제
describe('ExpenseItemFormController', () => {
  let controller
  let element
  
  beforeEach(() => {
    // DOM 설정
    document.body.innerHTML = `
      <form data-controller="expense-item-form" 
            data-sheet-year="2025" 
            data-sheet-month="1">
        <select data-expense-item-form-target="expenseCode">
          <option value="">선택하세요</option>
          <option value="1">시내교통비</option>
        </select>
        <input type="number" data-expense-item-form-target="amount">
        <input type="date" data-expense-item-form-target="expenseDate">
        <input type="text" data-expense-item-form-target="description">
        <div data-expense-item-form-target="customFields"></div>
        <div data-expense-item-form-target="validationErrors"></div>
      </form>
    `
    
    element = document.querySelector('[data-controller="expense-item-form"]')
    // 실제 애플리케이션에서는 Stimulus가 자동으로 컨트롤러를 연결함
  })
  
  afterEach(() => {
    document.body.innerHTML = ''
  })
  
  describe('validateAmount', () => {
    it('should show error for negative amount', () => {
      // 음수 금액 테스트
      const amountInput = element.querySelector('[data-expense-item-form-target="amount"]')
      amountInput.value = '-100'
      
      // validateAmount 메서드 호출 시뮬레이션
      // 실제로는 input 이벤트로 트리거됨
      
      // 에러 메시지가 표시되어야 함
      expect(amountInput.classList.contains('border-red-300')).toBe(true)
    })
    
    it('should show success for valid amount', () => {
      const amountInput = element.querySelector('[data-expense-item-form-target="amount"]')
      amountInput.value = '10000'
      
      // 성공 표시가 나타나야 함
      expect(amountInput.classList.contains('border-green-300')).toBe(true)
    })
  })
  
  describe('validateDate', () => {
    it('should reject future dates', () => {
      const dateInput = element.querySelector('[data-expense-item-form-target="expenseDate"]')
      const tomorrow = new Date()
      tomorrow.setDate(tomorrow.getDate() + 1)
      dateInput.value = tomorrow.toISOString().split('T')[0]
      
      // 미래 날짜는 거부되어야 함
      expect(dateInput.classList.contains('border-red-300')).toBe(true)
    })
    
    it('should reject dates outside expense sheet period', () => {
      const dateInput = element.querySelector('[data-expense-item-form-target="expenseDate"]')
      dateInput.value = '2024-12-01' // 이전 달
      
      // 경비 시트 기간 외 날짜는 거부되어야 함
      expect(dateInput.classList.contains('border-red-300')).toBe(true)
    })
  })
  
  describe('validateDescription', () => {
    it('should require minimum 5 characters', () => {
      const descInput = element.querySelector('[data-expense-item-form-target="description"]')
      descInput.value = '짧음'
      
      // 5자 미만은 거부되어야 함
      expect(descInput.classList.contains('border-red-300')).toBe(true)
    })
  })
  
  describe('custom fields', () => {
    it('should validate required custom fields', () => {
      // 커스텀 필드 추가
      const customFieldsTarget = element.querySelector('[data-expense-item-form-target="customFields"]')
      customFieldsTarget.innerHTML = `
        <input type="text" data-field-name="departure" data-field-required="true" required>
      `
      
      const customInput = customFieldsTarget.querySelector('input')
      customInput.value = ''
      
      // 필수 필드가 비어있으면 에러
      expect(customInput.classList.contains('border-red-300')).toBe(true)
    })
  })
  
  describe('tooltips', () => {
    it('should show guideline tooltip on focus', () => {
      // 툴팁 표시 테스트
      const customFieldsTarget = element.querySelector('[data-expense-item-form-target="customFields"]')
      customFieldsTarget.innerHTML = `
        <input type="text" data-field-name="departure" data-tooltip="출발 장소를 입력하세요">
      `
      
      const input = customFieldsTarget.querySelector('input')
      input.focus()
      
      // 툴팁이 표시되어야 함
      const tooltip = document.querySelector('.expense-field-tooltip')
      expect(tooltip).not.toBeNull()
      expect(tooltip.textContent).toContain('출발 장소')
    })
  })
})

// 참고: 실제 테스트 실행을 위해서는 Jest나 다른 JavaScript 테스트 프레임워크 설정이 필요합니다.