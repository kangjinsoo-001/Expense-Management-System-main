import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "excessSection", "excessAmount", "excessReason" ]
  static values = { budget: Number }
  
  connect() {
    console.log("Actual amount controller connected")
    console.log("Budget value:", this.budgetValue)
  }
  
  checkExceeded(event) {
    const actualAmount = parseFloat(event.target.value) || 0
    const budgetAmount = this.budgetValue
    
    if (actualAmount > budgetAmount) {
      // 예산 초과
      const excessAmount = actualAmount - budgetAmount
      const excessPercentage = ((excessAmount / budgetAmount) * 100).toFixed(1)
      
      this.excessSectionTarget.classList.remove("hidden")
      this.excessAmountTarget.textContent = `예산 대비 ₩${excessAmount.toLocaleString()} (${excessPercentage}%) 초과`
      
      // 초과 사유 필수 입력 설정
      if (this.hasExcessReasonTarget) {
        this.excessReasonTarget.setAttribute("required", "required")
      }
    } else {
      // 예산 내
      this.excessSectionTarget.classList.add("hidden")
      
      // 초과 사유 필수 해제 및 초기화
      if (this.hasExcessReasonTarget) {
        this.excessReasonTarget.removeAttribute("required")
        this.excessReasonTarget.value = ""
      }
    }
  }
}