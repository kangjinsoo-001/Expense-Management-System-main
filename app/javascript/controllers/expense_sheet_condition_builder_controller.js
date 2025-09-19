import { Controller } from "@hotwired/stimulus"

// 경비 시트 승인 규칙 조건 빌더 컨트롤러
export default class extends Controller {
  static targets = [
    "ruleType",
    "submitterGroup",
    "conditionFields",
    "amountCondition",
    "countCondition",
    "expenseCodeCondition",
    "expenseCodeCheckbox",
    "customCondition"
  ]

  connect() {
    this.updateConditionFields()
  }

  updateConditionFields() {
    const ruleType = this.ruleTypeTarget.value
    
    // 모든 조건 필드 숨기기
    this.hideAllConditions()
    
    // 선택된 규칙 유형에 따라 필드 표시
    switch(ruleType) {
      case 'total_amount':
        this.amountConditionTarget.classList.remove('hidden')
        break
      case 'item_count':
        this.countConditionTarget.classList.remove('hidden')
        break
      case 'submitter_based':
        this.submitterGroupTarget.classList.remove('hidden')
        break
      case 'expense_code_based':
        this.expenseCodeConditionTarget.classList.remove('hidden')
        break
      case 'custom':
        this.customConditionTarget.classList.remove('hidden')
        break
    }
  }

  hideAllConditions() {
    if (this.hasAmountConditionTarget) {
      this.amountConditionTarget.classList.add('hidden')
    }
    if (this.hasCountConditionTarget) {
      this.countConditionTarget.classList.add('hidden')
    }
    if (this.hasExpenseCodeConditionTarget) {
      this.expenseCodeConditionTarget.classList.add('hidden')
    }
    if (this.hasCustomConditionTarget) {
      this.customConditionTarget.classList.add('hidden')
    }
    if (this.hasSubmitterGroupTarget) {
      this.submitterGroupTarget.classList.add('hidden')
    }
  }
}