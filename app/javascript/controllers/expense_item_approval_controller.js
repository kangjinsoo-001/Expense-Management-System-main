import { Controller } from "@hotwired/stimulus"
import { ApprovalValidationHelper } from "helpers/approval_validation_helper"

export default class extends Controller {
  static targets = ["radio", "chip", "preview", "validationMessage"]
  static values = { 
    selected: String,
    expenseSheetId: String,
    expenseCodes: Object
  }
  
  connect() {
    // 검증 헬퍼 초기화
    this.validationHelper = new ApprovalValidationHelper(
      window.expenseCodesData,
      window.approvalLinesData,
      window.currentUserGroups
    )
    
    // 초기 선택 상태 설정
    this.updateChipStyles()
    
    // 키보드 이벤트 리스너 추가
    this.addKeyboardSupport()
  }
  
  addKeyboardSupport() {
    // 각 라디오 버튼에 키보드 이벤트 추가
    this.radioTargets.forEach(radio => {
      radio.addEventListener('keydown', (event) => {
        // Space 키나 Enter 키로 선택
        if (event.key === ' ' || event.key === 'Enter') {
          event.preventDefault()
          radio.checked = true
          radio.dispatchEvent(new Event('change', { bubbles: true }))
        }
        // 화살표 키로 이동
        else if (event.key === 'ArrowRight' || event.key === 'ArrowDown') {
          event.preventDefault()
          this.focusNextRadio(radio)
        }
        else if (event.key === 'ArrowLeft' || event.key === 'ArrowUp') {
          event.preventDefault()
          this.focusPreviousRadio(radio)
        }
      })
    })
  }
  
  focusNextRadio(currentRadio) {
    const index = this.radioTargets.indexOf(currentRadio)
    const nextIndex = (index + 1) % this.radioTargets.length
    this.radioTargets[nextIndex].focus()
  }
  
  focusPreviousRadio(currentRadio) {
    const index = this.radioTargets.indexOf(currentRadio)
    const prevIndex = index === 0 ? this.radioTargets.length - 1 : index - 1
    this.radioTargets[prevIndex].focus()
  }
  
  handleFocus(event) {
    // 포커스 시 시각적 피드백 강화
    const chip = event.currentTarget.nextElementSibling
    if (chip) {
      chip.classList.add('ring-2', 'ring-offset-2', 'ring-gray-500')
    }
  }
  
  handleBlur(event) {
    // 포커스 해제 시 시각적 피드백 제거
    const chip = event.currentTarget.nextElementSibling
    if (chip) {
      chip.classList.remove('ring-2', 'ring-offset-2', 'ring-gray-500')
    }
  }
  
  selectApprovalLine(event) {
    const approvalLineId = event.currentTarget.dataset.approvalLineId
    
    // 칩 스타일 업데이트
    this.updateChipStyles()
    
    // expense_item_form_controller의 데이터 로딩 상태 확인
    const formElement = document.querySelector('[data-controller*="expense-item-form"]')
    if (formElement) {
      const controller = this.application.getControllerForElementAndIdentifier(
        formElement, 
        'expense-item-form'
      )
      if (controller && controller.isLoadingData) {
        console.log('데이터 로딩 중, 결재선 검증 건너뛰기')
        // 미리보기만 업데이트
        if (approvalLineId && approvalLineId !== "") {
          this.showPreview(approvalLineId)
        } else {
          this.hidePreview()
        }
        return
      }
    }
    
    // 실시간 검증 수행
    this.validateApprovalLine(approvalLineId)
    
    // 클라이언트 검증 컨트롤러 트리거
    const form = this.element.closest('form')
    if (form) {
      const validationController = this.application.getControllerForElementAndIdentifier(form, 'client-validation')
      if (validationController) {
        console.log('결재선 변경 - 검증 트리거')
        validationController.validateAll()
      }
    }
    
    // 미리보기 업데이트
    if (approvalLineId && approvalLineId !== "") {
      this.showPreview(approvalLineId)
    } else {
      this.hidePreview()
    }
  }
  
  validateApprovalLine(approvalLineId) {
    // 경비 코드와 금액 가져오기
    const expenseCodeSelect = document.querySelector('[data-expense-item-form-target="expenseCode"]')
    const amountInput = document.querySelector('input[name="expense_item[amount]"]')
    const budgetAmountInput = document.querySelector('input[name="expense_item[budget_amount]"]')
    
    if (!expenseCodeSelect) return
    
    const expenseCodeId = expenseCodeSelect.value
    if (!expenseCodeId) return
    
    // Rails check_box는 hidden field와 checkbox 두 개를 생성하므로 
    // type="checkbox"를 명시적으로 선택
    const budgetCheckbox = document.querySelector('input[type="checkbox"][name="expense_item[is_budget]"]')
    const isBudgetMode = budgetCheckbox ? budgetCheckbox.checked : false
    const amount = parseFloat(amountInput ? amountInput.value : 0)
    const budgetAmount = parseFloat(budgetAmountInput ? budgetAmountInput.value : 0)
    
    console.log('=== 클라이언트 결재선 검증 ===')
    console.log('경비 코드 ID:', expenseCodeId)
    console.log('결재선 ID:', approvalLineId)
    console.log('예산 모드:', isBudgetMode)
    console.log('금액:', isBudgetMode ? budgetAmount : amount)
    
    // 클라이언트 사이드 검증 수행
    const context = {
      amount: amount,
      budget_amount: budgetAmount,
      is_budget: isBudgetMode
    }
    
    const validationResult = this.validationHelper.validateApprovalLine(
      expenseCodeId,
      approvalLineId,
      context
    )
    
    console.log('검증 결과:', validationResult)
    
    // UI 업데이트
    this.updateValidationUI(validationResult)
    
    // 전체 폼 검증 트리거
    const form = this.element.closest('form')
    if (form) {
      const event = new CustomEvent('approval:validated', {
        detail: validationResult,
        bubbles: true
      })
      form.dispatchEvent(event)
    }
  }
  
  updateValidationUI(validationResult) {
    // expense_code_validation div를 직접 사용
    let messageContainer = document.getElementById('expense_code_validation')
    
    if (!messageContainer) {
      // fallback: 검증 메시지 영역 찾기 또는 생성
      messageContainer = this.hasValidationMessageTarget 
        ? this.validationMessageTarget 
        : this.element.querySelector('[data-approval-validation-message]')
      
      if (!messageContainer) {
        // 메시지 컨테이너 생성
        messageContainer = document.createElement('div')
        messageContainer.dataset.approvalValidationMessage = true
        messageContainer.className = 'mt-2'
        
        // 결재선 선택 영역 다음에 추가
        const approvalSection = this.element
        if (approvalSection) {
          approvalSection.appendChild(messageContainer)
        }
      }
    }
    
    // 메시지 표시
    let html = ''
    
    // 에러 메시지
    if (validationResult.errors && validationResult.errors.length > 0) {
      html += '<div class="p-3 bg-red-50 border border-red-200 rounded-md mb-2">'
      html += '<div class="flex items-start">'
      html += '<svg class="h-5 w-5 text-red-400 mt-0.5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">'
      html += '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />'
      html += '</svg>'
      html += '<div class="text-sm text-red-700">'
      validationResult.errors.forEach(error => {
        // "승인 필요:" 또는 "필수 아님:" 으로 시작하는 경우 굵은 글씨 처리
        if (error.includes('승인 필요:') || error.includes('필수 아님:')) {
          const parts = error.split(':')
          if (parts.length >= 2) {
            html += `<div><span class="font-semibold">${parts[0]}:</span>${parts.slice(1).join(':')}</div>`
          } else {
            html += `<div>${error}</div>`
          }
        } else {
          html += `<div>${error}</div>`
        }
      })
      html += '</div></div></div>'
    }
    
    // 경고 메시지
    if (validationResult.warnings && validationResult.warnings.length > 0) {
      html += '<div class="p-3 bg-yellow-50 border border-yellow-200 rounded-md mb-2">'
      html += '<div class="flex items-start">'
      html += '<svg class="h-5 w-5 text-yellow-400 mt-0.5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">'
      html += '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />'
      html += '</svg>'
      html += '<div class="text-sm text-yellow-700">'
      validationResult.warnings.forEach(warning => {
        // "필수 아님:" 으로 시작하는 경우 굵은 글씨 처리
        if (warning.includes('필수 아님:')) {
          const parts = warning.split(':')
          if (parts.length >= 2) {
            html += `<div><span class="font-semibold">${parts[0]}:</span>${parts.slice(1).join(':')}</div>`
          } else {
            html += `<div>${warning}</div>`
          }
        } else {
          html += `<div>${warning}</div>`
        }
      })
      html += '</div></div></div>'
    }
    
    // 정보 메시지
    if (validationResult.info && validationResult.info.length > 0) {
      html += '<div class="p-3 bg-blue-50 border border-blue-200 rounded-md mb-2">'
      html += '<div class="flex items-start">'
      html += '<svg class="h-5 w-5 text-blue-400 mt-0.5 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">'
      html += '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />'
      html += '</svg>'
      html += '<div class="text-sm text-blue-700">'
      validationResult.info.forEach(info => {
        html += `<div>${info}</div>`
      })
      html += '</div></div></div>'
    }
    
    messageContainer.innerHTML = html
  }
  
  
  updateChipStyles() {
    this.chipTargets.forEach((chip, index) => {
      const radio = this.radioTargets[index]
      if (radio.checked) {
        chip.classList.remove('border-gray-300', 'bg-white', 'text-gray-700', 'hover:border-gray-400')
        chip.classList.add('border-indigo-500', 'bg-indigo-50', 'text-indigo-700')
      } else {
        chip.classList.remove('border-indigo-500', 'bg-indigo-50', 'text-indigo-700')
        chip.classList.add('border-gray-300', 'bg-white', 'text-gray-700', 'hover:border-gray-400')
      }
    })
  }
  
  showPreview(approvalLineId) {
    // 미리보기 컨테이너 표시
    this.previewTarget.classList.remove('hidden')
    
    // window.approvalLinesData에서 데이터 가져오기
    const approvalLinesData = window.approvalLinesData || {}
    const lineData = approvalLinesData[approvalLineId]
    
    if (!lineData || !lineData.steps) {
      // 데이터가 없으면 기존 방식으로 폴백 (서버에서 로드)
      const frame = document.createElement('turbo-frame')
      frame.id = 'approval_line_preview_frame'
      frame.src = `/approval_lines/${approvalLineId}/preview`
      frame.loading = 'lazy'
      
      this.previewTarget.innerHTML = ''
      this.previewTarget.appendChild(frame)
      return
    }
    
    // 클라이언트에서 직접 HTML 생성
    const previewHTML = this.generatePreviewHTML(lineData)
    this.previewTarget.innerHTML = previewHTML
  }
  
  generatePreviewHTML(lineData) {
    let html = `
      <div class="mt-2 p-3 bg-gray-50 border border-gray-200 rounded-lg">
        <h4 class="text-sm font-medium text-gray-700 mb-2">승인 단계</h4>
        <div class="space-y-2">
    `
    
    lineData.steps.forEach(step => {
      html += `<div class="text-sm flex items-center">`
      html += `<span class="font-medium text-gray-600 mr-2">${step.order}.</span>`
      
      // 병렬 승인 타입 표시
      const approvers = step.approvers.filter(a => a.role === 'approve')
      if (approvers.length >= 2 && step.approval_type) {
        const badgeClass = step.approval_type === 'all_required' 
          ? 'bg-purple-100 text-purple-800' 
          : 'bg-green-100 text-green-800'
        const badgeText = step.approval_type === 'all_required' ? '전체 합의' : '단독 가능'
        html += `<span class="mr-2 inline-flex items-center px-2 py-0.5 rounded text-xs font-medium ${badgeClass}">${badgeText}</span>`
      }
      
      // 승인자 목록
      step.approvers.forEach((approver, index) => {
        if (index > 0) {
          html += `<span class="mx-1 text-gray-300">|</span>`
        }
        
        html += `<span class="text-gray-700">${approver.name}`
        
        // 그룹 정보 표시
        if (approver.groups && approver.groups.length > 0) {
          html += ` <span class="text-gray-500">(${approver.groups[0].name})</span>`
        }
        
        html += `</span>`
        
        // 역할 배지
        const roleClass = approver.role === 'approve' 
          ? 'bg-blue-100 text-blue-700' 
          : 'bg-gray-100 text-gray-600'
        const roleText = approver.role === 'approve' ? '승인' : '참조'
        html += ` <span class="ml-1 inline-flex items-center px-1.5 py-0.5 rounded text-xs font-medium ${roleClass}">${roleText}</span>`
      })
      
      html += `</div>`
    })
    
    html += `
        </div>
      </div>
    `
    
    return html
  }
  
  hidePreview() {
    this.previewTarget.classList.add('hidden')
    this.previewTarget.innerHTML = ''
  }
  
  // 금액 변경 시 재검증
  revalidateApprovalLine() {
    // expense_item_form_controller의 데이터 로딩 상태 확인
    const formElement = document.querySelector('[data-controller*="expense-item-form"]')
    if (formElement) {
      const controller = this.application.getControllerForElementAndIdentifier(
        formElement, 
        'expense-item-form'
      )
      if (controller && controller.isLoadingData) {
        console.log('데이터 로딩 중, 결재선 재검증 건너뛰기')
        return
      }
    }
    
    // 현재 선택된 결재선 ID 가져오기
    const selectedRadio = this.radioTargets.find(radio => radio.checked)
    if (selectedRadio) {
      const approvalLineId = selectedRadio.dataset.approvalLineId
      this.validateApprovalLine(approvalLineId)
    }
  }
}