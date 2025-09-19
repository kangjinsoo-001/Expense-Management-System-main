import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["actualAmount", "budgetAmount", "excessReasonField", "budgetInfo"]
  static values = { budget: Number }
  
  connect() {
    console.log("Budget execution controller connected")
    this.checkBudgetExcess()
  }
  
  onActualAmountChange(event) {
    this.checkBudgetExcess()
  }
  
  checkBudgetExcess() {
    if (!this.hasActualAmountTarget) return
    
    const actualAmount = parseFloat(this.actualAmountTarget.value) || 0
    const budgetAmount = this.budgetValue || 0
    
    if (actualAmount > budgetAmount && budgetAmount > 0) {
      // 예산 초과
      this.showExcessReasonField()
      this.updateBudgetInfo(actualAmount, budgetAmount, true)
    } else {
      // 예산 내
      this.hideExcessReasonField()
      this.updateBudgetInfo(actualAmount, budgetAmount, false)
    }
  }
  
  showExcessReasonField() {
    if (this.hasExcessReasonFieldTarget) {
      this.excessReasonFieldTarget.classList.remove("hidden")
      
      // 필수 표시
      const textarea = this.excessReasonFieldTarget.querySelector("textarea")
      if (textarea) {
        textarea.setAttribute("required", "required")
      }
    }
  }
  
  hideExcessReasonField() {
    if (this.hasExcessReasonFieldTarget) {
      this.excessReasonFieldTarget.classList.add("hidden")
      
      // 필수 해제
      const textarea = this.excessReasonFieldTarget.querySelector("textarea")
      if (textarea) {
        textarea.removeAttribute("required")
      }
    }
  }
  
  updateBudgetInfo(actualAmount, budgetAmount, exceeded) {
    if (!this.hasBudgetInfoTarget) return
    
    const difference = actualAmount - budgetAmount
    const percentage = budgetAmount > 0 ? ((actualAmount / budgetAmount) * 100).toFixed(1) : 0
    
    if (exceeded) {
      // 예산 초과 경고 표시
      this.budgetInfoTarget.innerHTML = `
        <div class="mt-2 p-3 bg-red-50 border border-red-200 rounded-md">
          <div class="flex items-start gap-2">
            <svg class="h-5 w-5 text-red-600 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
            <div class="text-sm text-red-800">
              <p class="font-medium">예산 초과 경고</p>
              <p class="mt-1">
                예산 대비 ${percentage}% 집행 (초과액: ${this.formatCurrency(difference)})
              </p>
              <p class="mt-1 font-semibold">재승인이 필요합니다.</p>
            </div>
          </div>
        </div>
      `
    } else if (actualAmount > 0) {
      // 예산 내 정상 집행
      this.budgetInfoTarget.innerHTML = `
        <div class="mt-2 p-3 bg-green-50 border border-green-200 rounded-md">
          <div class="flex items-start gap-2">
            <svg class="h-5 w-5 text-green-600 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
            <div class="text-sm text-green-800">
              <p class="font-medium">예산 내 정상 집행</p>
              <p class="mt-1">
                예산 대비 ${percentage}% 집행 (잔여액: ${this.formatCurrency(Math.abs(difference))})
              </p>
            </div>
          </div>
        </div>
      `
    } else {
      this.budgetInfoTarget.innerHTML = ""
    }
  }
  
  formatCurrency(amount) {
    return new Intl.NumberFormat('ko-KR', {
      style: 'currency',
      currency: 'KRW'
    }).format(Math.abs(amount))
  }
}