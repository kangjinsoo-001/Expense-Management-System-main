import { Controller } from "@hotwired/stimulus"

// 새 경비 코드 생성 시 승인 규칙을 동적으로 관리하는 컨트롤러
export default class extends Controller {
  static targets = ["rules", "groupSelect", "minAmount", "maxAmount", "mandatory"]
  
  connect() {
    this.ruleIndex = 0
    this.availableGroups = this.parseAvailableGroups()
  }
  
  parseAvailableGroups() {
    const groups = {}
    const options = this.groupSelectTarget.querySelectorAll('option')
    options.forEach(option => {
      if (option.value) {
        groups[option.value] = option.textContent
      }
    })
    return groups
  }
  
  addRule(event) {
    event.preventDefault()
    
    const groupId = this.groupSelectTarget.value
    const minAmount = this.minAmountTarget.value
    const maxAmount = this.maxAmountTarget.value
    const isMandatory = this.mandatoryTarget.checked
    
    // 유효성 검사
    if (!groupId) {
      alert('승인 그룹을 선택해주세요.')
      return
    }
    
    // 중복 체크
    const existingRules = this.rulesTarget.querySelectorAll('[data-group-id]')
    for (let rule of existingRules) {
      if (rule.dataset.groupId === groupId) {
        alert('이미 추가된 승인 그룹입니다.')
        return
      }
    }
    
    // 금액 유효성 검사
    if (minAmount && maxAmount) {
      if (parseFloat(minAmount) > parseFloat(maxAmount)) {
        alert('최소 금액이 최대 금액보다 클 수 없습니다.')
        return
      }
    }
    
    // 규칙 HTML 생성
    const ruleHtml = this.createRuleHtml(groupId, minAmount, maxAmount, isMandatory)
    this.rulesTarget.insertAdjacentHTML('beforeend', ruleHtml)
    
    // 입력 필드 초기화
    this.groupSelectTarget.value = ''
    this.minAmountTarget.value = ''
    this.maxAmountTarget.value = ''
    this.mandatoryTarget.checked = false
    
    this.ruleIndex++
  }
  
  createRuleHtml(groupId, minAmount, maxAmount, isMandatory) {
    const groupName = this.availableGroups[groupId]
    let amountText = '모든 금액'
    
    if (minAmount && maxAmount) {
      amountText = `₩${this.formatNumber(minAmount)} ~ ₩${this.formatNumber(maxAmount)}`
    } else if (minAmount) {
      amountText = `₩${this.formatNumber(minAmount)} 이상`
    } else if (maxAmount) {
      amountText = `₩${this.formatNumber(maxAmount)} 이하`
    }
    
    return `
      <div class="flex items-center justify-between p-3 bg-white border border-gray-200 rounded-lg" data-group-id="${groupId}">
        <div class="flex items-center gap-3">
          <span class="text-sm font-medium text-gray-900">${groupName}</span>
          <span class="text-xs text-gray-500">${amountText}</span>
        </div>
        <div class="flex items-center gap-2">
          <span class="px-2 py-1 text-xs font-medium rounded-full ${isMandatory ? 'bg-red-100 text-red-800' : 'bg-blue-100 text-blue-800'}">
            ${isMandatory ? '필수' : '선택'}
          </span>
          <button type="button" 
                  class="text-red-600 hover:text-red-900 p-1"
                  data-action="click->expense-code-approval#removeRule">
            <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
            </svg>
          </button>
        </div>
        
        <!-- Hidden fields for form submission -->
        <input type="hidden" name="expense_code[approval_rules_attributes][${this.ruleIndex}][approver_group_id]" value="${groupId}">
        <input type="hidden" name="expense_code[approval_rules_attributes][${this.ruleIndex}][min_amount]" value="${minAmount}">
        <input type="hidden" name="expense_code[approval_rules_attributes][${this.ruleIndex}][max_amount]" value="${maxAmount}">
        <input type="hidden" name="expense_code[approval_rules_attributes][${this.ruleIndex}][is_mandatory]" value="${isMandatory ? '1' : '0'}">
      </div>
    `
  }
  
  removeRule(event) {
    event.preventDefault()
    const ruleElement = event.currentTarget.closest('[data-group-id]')
    ruleElement.remove()
  }
  
  formatNumber(num) {
    return parseFloat(num).toLocaleString('ko-KR')
  }
}