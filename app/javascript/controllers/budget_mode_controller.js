import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "checkbox", "normalMode", "budgetMode", "amountField", "budgetAmountField" ]
  
  connect() {
    console.log("Budget mode controller connected")
    // 초기 상태 설정
    this.updateDisplay()
  }
  
  toggleMode(event) {
    console.log("Toggle mode triggered", event.target.checked)
    this.updateDisplay()
    this.handleAmountFields()
    this.triggerApprovalRevalidation()
    this.updateAttachmentLabel()
  }
  
  onBudgetAmountChange(event) {
    console.log("Budget amount changed:", event.target.value)
    // 금액 변경 시 결재선 재검증
    this.triggerApprovalRevalidation()
  }
  
  triggerApprovalRevalidation() {
    // 결재선 검증 컨트롤러 찾기
    const approvalController = document.querySelector('[data-controller*="expense-item-approval"]')
    if (approvalController) {
      // 결재선 재검증 이벤트 발생
      const event = new CustomEvent('revalidate-approval')
      approvalController.dispatchEvent(event)
      
      // 또는 직접 재검증 함수 호출
      const controller = this.application.getControllerForElementAndIdentifier(
        approvalController, 
        'expense-item-approval'
      )
      if (controller && controller.revalidateApprovalLine) {
        console.log('예산 모드 변경 - 결재선 재검증 실행')
        controller.revalidateApprovalLine()
      }
    }
  }
  
  updateDisplay() {
    const isBudgetMode = this.checkboxTarget.checked
    
    if (isBudgetMode) {
      // 예산 모드 표시
      this.normalModeTarget.classList.add("hidden")
      this.budgetModeTarget.classList.remove("hidden")
    } else {
      // 일반 모드 표시
      this.normalModeTarget.classList.remove("hidden")
      this.budgetModeTarget.classList.add("hidden")
    }
  }
  
  handleAmountFields() {
    const isBudgetMode = this.checkboxTarget.checked
    
    if (isBudgetMode) {
      // 예산 모드로 전환 시
      // 일반 금액 필드의 값을 예산 금액 필드로 복사 (비어있지 않은 경우)
      if (this.hasAmountFieldTarget && this.amountFieldTarget.value && 
          this.hasBudgetAmountFieldTarget && !this.budgetAmountFieldTarget.value) {
        this.budgetAmountFieldTarget.value = this.amountFieldTarget.value
      }
      
      // 일반 금액 필드 초기화
      if (this.hasAmountFieldTarget) {
        this.amountFieldTarget.value = ""
        this.amountFieldTarget.removeAttribute("required")
      }
      
      // 예산 금액 필드 필수 설정
      if (this.hasBudgetAmountFieldTarget) {
        this.budgetAmountFieldTarget.setAttribute("required", "required")
      }
    } else {
      // 일반 모드로 전환 시
      // 예산 금액 필드의 값을 일반 금액 필드로 복사 (비어있지 않은 경우)
      if (this.hasBudgetAmountFieldTarget && this.budgetAmountFieldTarget.value && 
          this.hasAmountFieldTarget && !this.amountFieldTarget.value) {
        this.amountFieldTarget.value = this.budgetAmountFieldTarget.value
      }
      
      // 예산 금액 필드 초기화
      if (this.hasBudgetAmountFieldTarget) {
        this.budgetAmountFieldTarget.value = ""
        this.budgetAmountFieldTarget.removeAttribute("required")
      }
      
      // 일반 금액 필드 필수 설정
      if (this.hasAmountFieldTarget) {
        this.amountFieldTarget.setAttribute("required", "required")
      }
    }
  }
  
  updateAttachmentLabel() {
    // expense_item_form 컨트롤러에 첨부파일 라벨 업데이트 요청
    const formController = document.querySelector('[data-controller*="expense-item-form"]')
    if (formController) {
      const controller = this.application.getControllerForElementAndIdentifier(
        formController, 
        'expense-item-form'
      )
      if (controller && controller.expenseCodeTarget?.value) {
        // 현재 선택된 경비 코드의 데이터 가져오기
        const expenseCodeData = controller.expenseCodesDataValue[controller.expenseCodeTarget.value]
        if (expenseCodeData) {
          controller.updateAttachmentRequirement(expenseCodeData)
        }
      }
    }
  }
}