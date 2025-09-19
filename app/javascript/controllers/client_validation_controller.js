import { Controller } from "@hotwired/stimulus"
import { ApprovalValidationHelper } from "helpers/approval_validation_helper"

// 클라이언트 사이드 검증 컨트롤러 - 서버 호출 없이 즉시 검증
export default class extends Controller {
  static targets = ["submitButton", "submitButtonWrapper", "tooltip", "tooltipText"]
  static values = { 
    expenseSheetId: String
  }

  connect() {
    console.log("Client validation controller connected")
    this.isLoadingData = false
    this.validationErrors = new Map() // 검증 에러 상태 추적
    this.setupEventListeners()
    this.observeDynamicFields()
    this.setupTooltipEvents()
    
    // 검증 헬퍼 초기화
    this.approvalValidationHelper = new ApprovalValidationHelper(
      window.expenseCodesData,
      window.approvalLinesData,
      window.currentUserGroups
    )
    
    // 초기 로드 시 전체 검증 실행
    setTimeout(() => {
      this.validateAll()
      
      // 기본값이 설정된 날짜 필드에 대한 추가 검증
      const dateField = this.element.querySelector('input[type="date"][data-needs-validation="true"]')
      if (dateField && dateField.value) {
        console.log("기본 날짜값 검증 실행:", dateField.value)
        this.validateDateForSubmittedSheet(dateField)
      }
    }, 100)
  }

  setupTooltipEvents() {
    // 저장 버튼 wrapper에 마우스 이벤트 추가
    if (this.hasSubmitButtonWrapperTarget) {
      this.submitButtonWrapperTarget.addEventListener('mouseenter', () => {
        if (this.submitButtonTarget.disabled && this.hasTooltipTarget) {
          this.tooltipTarget.classList.remove('hidden')
        }
      })
      
      this.submitButtonWrapperTarget.addEventListener('mouseleave', () => {
        if (this.hasTooltipTarget) {
          this.tooltipTarget.classList.add('hidden')
        }
      })
    }
  }

  setupEventListeners() {
    // 데이터 로딩 상태 추적
    document.addEventListener('expense-item:loading-start', () => {
      this.isLoadingData = true
      console.log('데이터 로딩 시작 - 검증 일시 중지')
    })
    
    document.addEventListener('expense-item:loading-complete', () => {
      this.isLoadingData = false
      console.log('데이터 로딩 완료 - 검증 재개')
      // 로딩 완료 후 전체 폼 검증
      setTimeout(() => this.validateAll(), 100)
    })
    
    // 결재선 검증 이벤트 리스너
    this.element.addEventListener('approval:validated', (event) => {
      const validationResult = event.detail
      console.log('결재선 검증 결과 수신:', validationResult)
      
      // 결재선 검증 결과를 전체 검증에 반영
      if (validationResult.valid === false && validationResult.errors && validationResult.errors.length > 0) {
        // 첫 번째 에러 메시지만 저장 (배열이 아닌 문자열로)
        this.validationErrors.set('approval_line', validationResult.errors[0])
      } else {
        this.validationErrors.delete('approval_line')
      }
      
      // 저장 버튼 상태 업데이트
      this.updateSubmitButton()
    })
  }

  // 동적으로 추가되는 필드 감지
  observeDynamicFields() {
    // MutationObserver로 DOM 변경 감지
    const observer = new MutationObserver((mutations) => {
      mutations.forEach((mutation) => {
        if (mutation.type === 'childList' && mutation.addedNodes.length > 0) {
          mutation.addedNodes.forEach((node) => {
            if (node.nodeType === 1) { // Element node
              // 새로 추가된 커스텀 필드 찾기
              const customFields = node.querySelectorAll ? 
                node.querySelectorAll('input[name*="custom_fields"], select[name*="custom_fields"], textarea[name*="custom_fields"]') : []
              
              if (node.matches && node.matches('input[name*="custom_fields"], select[name*="custom_fields"], textarea[name*="custom_fields"]')) {
                this.attachValidationToField(node)
              }
              
              customFields.forEach(field => {
                this.attachValidationToField(field)
              })
            }
          })
        }
      })
    })

    // 폼 전체를 관찰
    observer.observe(this.element, {
      childList: true,
      subtree: true
    })

    // disconnect를 위해 observer 저장
    this.observer = observer
  }

  // 필드에 검증 이벤트 리스너 추가
  attachValidationToField(field) {
    // 이미 리스너가 있는지 확인 (중복 방지)
    if (field.dataset.validationAttached) return
    
    const fieldName = field.name
    console.log('동적 필드에 검증 추가:', fieldName, field)
    
    if (fieldName.includes('custom_fields')) {
      // input, select, textarea에 따라 다른 이벤트 사용
      if (field.tagName === 'SELECT') {
        field.addEventListener('change', (e) => this.validateField(e))
      } else {
        field.addEventListener('input', (e) => this.validateField(e))
      }
      
      field.dataset.validationAttached = 'true'
    }
  }

  disconnect() {
    // MutationObserver 정리
    if (this.observer) {
      this.observer.disconnect()
    }
  }

  // 필드 입력 시 검증
  validateField(event) {
    if (this.isLoadingData) {
      console.log('데이터 로딩 중, 검증 건너뜀')
      return
    }
    
    const field = event.target
    const fieldName = field.name
    
    console.log('validateField 호출:', fieldName, 'value:', field.value, 'dataset:', field.dataset)
    
    // 경비 코드 변경은 검증하지 않음 (커스텀 필드 로드 대기)
    if (fieldName === 'expense_item[expense_code_id]') {
      return
    }
    
    // 날짜 필드 변경 시 제출 가능 여부 검증
    if (fieldName === 'expense_item[expense_date]') {
      this.validateDateForSubmittedSheet(field)
    }
    
    // 단일 필드 검증
    this.validateSingleField(field)
    
    // 금액 필드 변경 시 결재선과 한도 검증
    if (fieldName === 'expense_item[amount]') {
      this.checkApprovalLine()
      this.validateAmountLimit()
    }
    
    // 참석자 필드 변경 시 한도 재계산 및 검증
    if (fieldName.includes('custom_fields') && (field.dataset.fieldType === 'participants' || field.dataset.fieldName === '참석자')) {
      this.validateAmountLimit()
    }
  }

  // 즉시 검증 (select 등)
  validateImmediately(event) {
    if (this.isLoadingData) return
    this.validateSingleField(event.target)
  }

  // 단일 필드 검증
  validateSingleField(field) {
    console.log('validateSingleField 시작:', field.name, 'required:', field.dataset.fieldRequired)
    
    // Choice.js를 사용하는 경우 실제 select가 숨겨지므로 Choice.js 컨테이너를 찾아야 함
    let container = field.closest('div')
    
    // Choice.js 필드인 경우 상위 div로 이동
    if (field.hasAttribute('data-choices-initialized')) {
      const choicesElement = field.closest('.choices')
      if (choicesElement) {
        container = choicesElement.parentElement
      }
    }
    
    if (!container) {
      console.log('컨테이너를 찾을 수 없음')
      return
    }
    
    // 기존 에러 메시지 제거 (Choice.js 외부에서)
    const existingError = container.querySelector(':scope > .field-error')
    if (existingError) existingError.remove()
    
    // 필드 테두리 초기화 (Choice.js의 경우 inner element에 적용)
    if (field.hasAttribute('data-choices-initialized')) {
      const choicesInner = container.querySelector('.choices__inner')
      if (choicesInner) {
        choicesInner.classList.remove('border-red-300', 'border-green-300')
      }
    } else {
      field.classList.remove('border-red-300', 'border-green-300')
    }
    
    // 필수 필드 체크
    const isRequired = this.isFieldRequired(field)
    console.log('필수 필드 여부:', isRequired)
    if (!isRequired) {
      // 필수 필드가 아니면 에러 맵에서 제거
      this.validationErrors.delete(field.name)
      this.updateSubmitButton()
      return
    }
    
    const isEmpty = this.isFieldEmpty(field)
    console.log('필드 비어있음:', isEmpty)
    
    if (isEmpty) {
      // 에러 표시
      if (field.hasAttribute('data-choices-initialized')) {
        const choicesInner = container.querySelector('.choices__inner')
        if (choicesInner) {
          choicesInner.classList.add('border-red-300')
        }
      } else {
        field.classList.add('border-red-300')
      }
      
      const errorMsg = this.getFieldErrorMessage(field)
      const error = document.createElement('p')
      error.className = 'field-error mt-1 text-sm text-red-600'
      error.textContent = errorMsg
      
      // Choice.js 컨테이너 밖에 추가
      if (field.hasAttribute('data-choices-initialized')) {
        const choicesElement = container.querySelector('.choices')
        if (choicesElement) {
          choicesElement.insertAdjacentElement('afterend', error)
        } else {
          container.appendChild(error)
        }
      } else {
        container.appendChild(error)
      }
      
      // 에러 맵에 추가
      this.validationErrors.set(field.name, errorMsg)
      this.updateSubmitButton()
    } else {
      // 성공 표시 (잠시만)
      if (field.hasAttribute('data-choices-initialized')) {
        const choicesInner = container.querySelector('.choices__inner')
        if (choicesInner) {
          choicesInner.classList.add('border-green-300')
          setTimeout(() => {
            choicesInner.classList.remove('border-green-300')
          }, 1000)
        }
      } else {
        field.classList.add('border-green-300')
        setTimeout(() => {
          field.classList.remove('border-green-300')
        }, 1000)
      }
      
      // 에러 맵에서 제거
      this.validationErrors.delete(field.name)
      this.updateSubmitButton()
    }
  }

  // 필수 필드인지 확인
  isFieldRequired(field) {
    const fieldName = field.name
    
    // 기본 필수 필드
    const requiredFields = [
      'expense_item[expense_date]',
      'expense_item[expense_code_id]',
      'expense_item[amount]',
      'expense_item[cost_center_id]'
    ]
    
    if (requiredFields.includes(fieldName)) {
      return true
    }
    
    // 커스텀 필드 체크
    if (fieldName.includes('custom_fields')) {
      return field.dataset.fieldRequired === 'true'
    }
    
    return false
  }

  // 필드가 비어있는지 확인
  isFieldEmpty(field) {
    const value = field.value
    
    // 멀티셀렉트 체크 (Choice.js)
    if (field.multiple && field._choices) {
      const selectedValues = field._choices.getValue(true)
      return !selectedValues || selectedValues.length === 0
    }
    
    // 일반 필드
    return !value || value.trim() === ''
  }

  // 필드별 에러 메시지
  getFieldErrorMessage(field) {
    const fieldName = field.name
    
    // 기본 필드 메시지
    const messages = {
      'expense_item[expense_date]': '날짜 필수',
      'expense_item[expense_code_id]': '경비 코드 필수',
      'expense_item[amount]': '금액 필수',
      'expense_item[cost_center_id]': '코스트 센터 필수'
    }
    
    if (messages[fieldName]) {
      return messages[fieldName]
    }
    
    // 커스텀 필드
    if (fieldName.includes('custom_fields')) {
      // dataset.fieldName이 실제 필드 이름을 가지고 있음 (예: "사유", "구성원")
      const fieldLabel = field.dataset.fieldName || '필드'
      return `${fieldLabel} 필수`
    }
    
    return '필수'
  }

  // 전체 검증
  validateAll() {
    // 데이터 로딩 중이면 검증하지 않음
    if (this.isLoadingData) {
      console.log('데이터 로딩 중 - 전체 검증 건너뜀')
      return
    }
    
    console.log('전체 폼 검증 시작')
    
    // 모든 입력 필드 검증
    const inputs = this.element.querySelectorAll('input:not([type="hidden"]), select, textarea')
    inputs.forEach(input => {
      if (this.isFieldRequired(input)) {
        this.validateSingleField(input)
      }
    })
    
    // 첨부파일 검증
    this.validateAttachments()
    
    // 한도 검증
    this.validateAmountLimit()
    
    // 결재선 검증 (이건 서버에서)
    this.checkApprovalLine()
  }

  // 첨부파일 검증
  validateAttachments() {
    const expenseCodeSelect = document.querySelector('[data-expense-item-form-target="expenseCode"]')
    if (!expenseCodeSelect) return
    
    const expenseCodeId = expenseCodeSelect.value
    if (!expenseCodeId) return
    
    // 경비 코드 데이터에서 첨부파일 필수 여부 확인
    const expenseCodesData = window.expenseCodesData || {}
    const codeData = expenseCodesData[expenseCodeId]
    const messagesContainer = document.getElementById('validation-messages')
    
    if (!messagesContainer) return
    
    if (codeData && codeData.attachment_required) {
      const attachmentInputs = document.querySelectorAll('input[name="attachment_ids[]"]')
      const hasAttachments = attachmentInputs.length > 0
      
      if (!hasAttachments) {
        messagesContainer.innerHTML = '<p class="text-sm text-red-600">첨부파일 필수</p>'
        // 에러 맵에 추가
        this.validationErrors.set('attachments', '첨부파일 필수')
        this.updateSubmitButton()
      } else {
        messagesContainer.innerHTML = ''
        // 에러 맵에서 제거
        this.validationErrors.delete('attachments')
        this.updateSubmitButton()
      }
    } else {
      // 첨부파일이 필수가 아닌 경우 메시지 제거
      messagesContainer.innerHTML = ''
      this.validationErrors.delete('attachments')
      this.updateSubmitButton()
    }
  }

  // 결재선 검증 - expense_item_approval_controller에 위임
  async checkApprovalLine() {
    console.log('=== checkApprovalLine 시작 - expense_item_approval_controller에 위임 ===')
    
    // expense_item_approval_controller의 재검증 메서드 호출
    const approvalElement = document.querySelector('[data-controller*="expense-item-approval"]')
    if (approvalElement) {
      const approvalController = this.application.getControllerForElementAndIdentifier(
        approvalElement,
        'expense-item-approval'
      )
      if (approvalController && approvalController.revalidateApprovalLine) {
        console.log('expense_item_approval_controller의 revalidateApprovalLine 호출')
        approvalController.revalidateApprovalLine()
      }
    }
    
    // 기존 로직은 모두 제거하고 expense_item_approval_controller에 위임
    return
    
    /* 아래 코드는 더 이상 사용하지 않음 - expense_item_approval_controller가 처리
    const expenseCodeSelect = document.querySelector('[data-expense-item-form-target="expenseCode"]')
    const amountInput = document.querySelector('input[name="expense_item[amount]"]:not([type="hidden"])')
    
    console.log('expenseCodeSelect:', expenseCodeSelect)
    console.log('amountInput:', amountInput)
    
    if (!expenseCodeSelect || !amountInput) {
      console.log('필수 요소를 찾을 수 없음')
      return
    }
    
    const expenseCodeId = expenseCodeSelect.value
    // 금액이 비어있으면 0으로 처리
    const amount = amountInput.value || '0'
    
    console.log('expenseCodeId:', expenseCodeId, 'amount:', amount)
    
    if (!expenseCodeId) {
      console.log('경비 코드가 없음 - 결재선 검증 건너뜀')
      return
    }
    
    // 경비 코드 데이터에서 승인 규칙 확인
    const expenseCodesData = window.expenseCodesData || {}
    const codeData = expenseCodesData[expenseCodeId]
    
    if (codeData && codeData.approval_rules && codeData.approval_rules.length > 0) {
      // 현재 사용자의 최고 권한 우선순위 가져오기
      const currentUserGroups = window.currentUserGroups || []
      let userMaxPriority = 0
      currentUserGroups.forEach(group => {
        if (group.priority > userMaxPriority) {
          userMaxPriority = group.priority
        }
      })
      
      console.log('현재 사용자 그룹:', currentUserGroups, '최고 우선순위:', userMaxPriority)
      
      // 필요한 승인 그룹 수집
      const requiredGroups = []
      const requiredGroupsWithPriority = []
      
      // 금액 기반 규칙 체크
      codeData.approval_rules.forEach(rule => {
        let ruleApplies = false
        
        if (rule.condition) {
          // "#금액 > 300000" 또는 "#금액 >= 300000" 형식 파싱
          const gtMatch = rule.condition.match(/#?금액\s*>\s*(\d+)/)
          const gteMatch = rule.condition.match(/#?금액\s*>=\s*(\d+)/)
          
          if (gtMatch) {
            const threshold = parseInt(gtMatch[1])
            ruleApplies = parseInt(amount) > threshold
          } else if (gteMatch) {
            const threshold = parseInt(gteMatch[1])
            ruleApplies = parseInt(amount) >= threshold
          } else if (rule.condition.includes('amount')) {
            // 기존 "amount > 100000" 형식도 지원
            const amountGtMatch = rule.condition.match(/amount\s*>\s*(\d+)/)
            const amountGteMatch = rule.condition.match(/amount\s*>=\s*(\d+)/)
            
            if (amountGtMatch) {
              const threshold = parseInt(amountGtMatch[1])
              ruleApplies = parseInt(amount) > threshold
            } else if (amountGteMatch) {
              const threshold = parseInt(amountGteMatch[1])
              ruleApplies = parseInt(amount) >= threshold
            }
          }
        } else if (rule.condition === null || rule.condition === 'always' || rule.condition === '') {
          // 조건이 null이거나 'always'인 경우 항상 승인 필요
          ruleApplies = true
        }
        
        if (ruleApplies && rule.approver_group) {
          // 사용자가 이미 해당 권한을 가지고 있거나 더 높은 권한이 있는지 체크
          const groupPriority = rule.approver_group.priority || 0
          
          // 사용자의 권한이 요구되는 권한보다 같거나 높으면 스킵
          if (userMaxPriority >= groupPriority) {
            console.log(`사용자가 이미 ${rule.approver_group.name} 권한 이상을 보유 (${userMaxPriority} >= ${groupPriority})`)
          } else {
            requiredGroups.push(rule.approver_group.name)
            requiredGroupsWithPriority.push(rule.approver_group)
          }
        }
      })
      
      const finalNeedsApproval = requiredGroups.length > 0
      
      console.log('승인 필요 여부:', finalNeedsApproval, '필요 그룹:', requiredGroups)
      
      const approvalRadios = document.querySelectorAll('input[name="expense_item[approval_line_id]"]')
      let hasApprovalLine = false
      let selectedApprovalLineId = null
      
      approvalRadios.forEach(radio => {
        if (radio.checked && radio.value !== '') {
          hasApprovalLine = true
          selectedApprovalLineId = radio.value
        }
      })
      
      console.log('결재선 선택 여부:', hasApprovalLine, '선택된 결재선 ID:', selectedApprovalLineId)
      
      const approvalMessages = document.getElementById('expense_code_validation')
      console.log('expense_code_validation 요소:', approvalMessages)
      
      if (approvalMessages) {
        // 서버 검증이 진행될 예정이므로 로딩 상태 표시
        // 단, 결재선이 없고 승인이 필요한 경우는 즉시 에러 표시
        if (finalNeedsApproval && !hasApprovalLine) {
          // 결재선이 필요한데 선택되지 않은 경우 - 에러 메시지
          // 중복 제거하고 권한 순서대로 정렬
          const uniqueGroups = [...new Set(requiredGroups)]
          const groupOrder = ['CEO', '조직총괄', '조직리더', '보직자']
          const sortedGroups = uniqueGroups.sort((a, b) => {
            const indexA = groupOrder.indexOf(a)
            const indexB = groupOrder.indexOf(b)
            if (indexA === -1) return 1
            if (indexB === -1) return -1
            return indexA - indexB
          })
          const message = `승인 필요: ${sortedGroups.join(', ')}`
          console.log('결재선 필수 메시지 표시:', message)
          approvalMessages.innerHTML = `<div class="p-3 bg-red-50 border border-red-200 rounded-md"><p class="text-sm text-red-600">${message}</p></div>`
          // 에러 맵에 추가
          this.validationErrors.set('approval_line', message)
          this.updateSubmitButton()
        } else if (hasApprovalLine) {
          // 결재선이 선택된 경우 - 클라이언트에서 직접 검증
          console.log('결재선 선택됨 - 클라이언트 검증 시작')
          
          // 클라이언트 검증 로직 수행
          // 결재선이 선택된 경우 - 과도한 승인자 체크
          // 두 가지 경우를 체크:
          // 1. 사용자 권한으로 이미 충족되는데 결재선을 선택한 경우
          // 2. 필요한 권한보다 높은 권한의 결재선을 선택한 경우
          
          // 원래 필요한 최고 우선순위 (사용자 권한 고려하지 않음)
          let originalMaxRequiredPriority = 0
          // 사용자 권한 고려한 필요한 최고 우선순위
          let maxRequiredPriority = 0
          
          codeData.approval_rules.forEach(rule => {
            let ruleApplies = false
            
            if (rule.condition) {
              const match = rule.condition.match(/#?금액\s*>=?\s*(\d+)/)
              if (match) {
                const threshold = parseInt(match[1])
                ruleApplies = parseInt(amount) >= threshold
              }
            } else if (rule.condition === null || rule.condition === '' || rule.condition === 'always') {
              ruleApplies = true
            }
            
            if (ruleApplies && rule.approver_group && rule.approver_group.priority) {
              const groupPriority = rule.approver_group.priority
              originalMaxRequiredPriority = Math.max(originalMaxRequiredPriority, groupPriority)
              
              // 사용자가 이미 가진 권한은 제외
              if (groupPriority > userMaxPriority) {
                maxRequiredPriority = Math.max(maxRequiredPriority, groupPriority)
              }
            }
          })
          
          console.log('원래 필요한 최고 우선순위:', originalMaxRequiredPriority)
          console.log('사용자 권한 고려한 필요한 최고 우선순위:', maxRequiredPriority)
          
          // 선택된 결재선의 승인자들이 속한 그룹 확인 (window.approvalLinesData에서 읽기)
          const approvalLinesData = window.approvalLinesData || {}
          const selectedLineData = approvalLinesData[selectedApprovalLineId]
          
          if (selectedLineData && selectedLineData.approver_groups) {
            let maxActualPriority = 0
            const actualGroups = []
            
            selectedLineData.approver_groups.forEach(group => {
              if (group.priority > maxActualPriority) {
                maxActualPriority = group.priority
              }
              actualGroups.push(group)
            })
            
            console.log('실제 최고 우선순위:', maxActualPriority, '실제 그룹:', actualGroups)
              
            // 먼저 필요한 승인이 부족한지 체크 (에러)
            if (maxRequiredPriority > 0 && maxActualPriority < maxRequiredPriority) {
              // 필요한 승인이 부족한 경우 - 에러 처리
              const missingGroups = requiredGroupsWithPriority
                .filter(g => g.priority > maxActualPriority)
                .sort((a, b) => b.priority - a.priority)
                .map(g => g.name)
              
              const uniqueMissingGroups = [...new Set(missingGroups)]
              const message = `승인 필요: ${uniqueMissingGroups.join(', ')}`
              
              console.log('승인 부족 에러:', message)
              approvalMessages.innerHTML = `
                <div class="p-3 bg-red-50 border border-red-200 rounded-md">
                  <div class="flex items-start gap-2">
                    <svg class="h-4 w-4 text-red-600 mt-0.5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                    </svg>
                    <div class="text-sm text-red-800">
                      <p>${message}</p>
                    </div>
                  </div>
                </div>`
              // 에러 맵에 추가
              this.validationErrors.set('approval_line', message)
              this.updateSubmitButton()
            }
            // 과도한 승인자 체크 (경고)
            // 세 가지 경우를 체크:
            // 1. 원래 필요한 권한보다 높은 권한의 결재선 (originalMaxRequiredPriority 사용)
            // 2. 사용자 권한으로 이미 충족되는데 결재선 선택 (maxRequiredPriority == 0인 경우)
            else if (maxRequiredPriority === 0 && maxActualPriority > 0) {
              // 사용자 권한으로 이미 충족되는데 결재선을 선택한 경우
              // 사용자 권한보다 높은 승인자만 경고
              if (maxActualPriority > userMaxPriority) {
                const excessiveGroups = actualGroups.filter(g => g.priority > userMaxPriority)
                const sortedExcessiveGroups = excessiveGroups.sort((a, b) => b.priority - a.priority)
                const excessiveGroupNames = sortedExcessiveGroups.map(g => g.name).filter((v, i, a) => a.indexOf(v) === i)
                
                if (excessiveGroupNames.length > 0) {
                  warningMessage = `필수 아님: ${excessiveGroupNames.join(', ')}`
                  showWarning = true
                }
              }
            } else if (maxActualPriority > originalMaxRequiredPriority && originalMaxRequiredPriority > 0) {
              // 원래 필요한 권한보다 높은 권한의 결재선을 선택한 경우
              const excessiveGroups = actualGroups.filter(g => g.priority > originalMaxRequiredPriority)
              const sortedExcessiveGroups = excessiveGroups.sort((a, b) => b.priority - a.priority)
              const excessiveGroupNames = sortedExcessiveGroups.map(g => g.name).filter((v, i, a) => a.indexOf(v) === i)
              
              if (excessiveGroupNames.length > 0) {
                warningMessage = `필수 아님: ${excessiveGroupNames.join(', ')}`
                showWarning = true
              }
            }
            
            if (showWarning) {
              console.log('과도한 승인자 경고:', warningMessage)
              
              approvalMessages.innerHTML = `
                <div class="p-3 bg-yellow-50 border border-yellow-200 rounded-md">
                  <div class="flex items-start gap-2">
                    <svg class="h-4 w-4 text-yellow-600 mt-0.5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
                    </svg>
                    <div class="text-sm text-yellow-800">
                      <p class="font-semibold mb-1">주의</p>
                      <p>${warningMessage}</p>
                      <p class="mt-2 text-xs">제출은 가능하지만, 불필요한 승인 단계가 포함되어 있습니다.</p>
                    </div>
                  </div>
                </div>`
              // 경고는 에러가 아니므로 에러 맵에서 제거
              this.validationErrors.delete('approval_line')
              this.updateSubmitButton()
            } else if (maxRequiredPriority > 0 && maxActualPriority >= maxRequiredPriority) {
              // 적절한 결재선인 경우 - 메시지 삭제
              console.log('결재선 메시지 삭제')
              approvalMessages.innerHTML = ''
              this.validationErrors.delete('approval_line')
              this.updateSubmitButton()
            }
          }
        } else {
          // 결재선이 필요 없는 경우 - 메시지 삭제
          console.log('결재선 메시지 삭제')
          approvalMessages.innerHTML = ''
          this.validationErrors.delete('approval_line')
          this.updateSubmitButton()
        }
      } else {
        console.error('approval_validation_messages 요소를 찾을 수 없음')
      }
    }
    */
  }

  // 한도 검증
  validateAmountLimit() {
    console.log('=== validateAmountLimit 시작 ===')
    
    // 필요한 요소들 찾기
    const expenseCodeSelect = document.querySelector('[data-expense-item-form-target="expenseCode"]')
    const amountInput = document.querySelector('input[name="expense_item[amount]"]:not([type="hidden"])')
    
    if (!expenseCodeSelect || !amountInput) {
      console.log('경비 코드 또는 금액 필드를 찾을 수 없음')
      return
    }
    
    const expenseCodeId = expenseCodeSelect.value
    const amount = parseFloat(amountInput.value) || 0
    
    if (!expenseCodeId || amount === 0) {
      // 한도 에러 제거
      this.clearAmountLimitError()
      return
    }
    
    // 경비 코드 데이터에서 한도 정보 가져오기
    const expenseCodesData = window.expenseCodesData || {}
    const codeData = expenseCodesData[expenseCodeId]
    
    if (!codeData || !codeData.limit_amount) {
      // 한도가 없는 경비 코드
      this.clearAmountLimitError()
      return
    }
    
    // 한도 계산
    const calculatedLimit = this.calculateDynamicLimit(codeData.limit_amount, codeData)
    
    if (calculatedLimit === null) {
      console.log('한도 계산 불가')
      this.clearAmountLimitError()
      return
    }
    
    console.log(`한도 검증 - 금액: ${amount}, 한도: ${calculatedLimit}`)
    
    // 한도 검증
    if (amount > calculatedLimit) {
      // 한도 초과
      const limitDisplay = this.formatLimitDisplay(codeData.limit_amount, calculatedLimit)
      this.showAmountLimitError(amountInput, limitDisplay, calculatedLimit)
    } else {
      // 한도 이내
      this.clearAmountLimitError(amountInput)
    }
  }
  
  // 동적 한도 계산
  calculateDynamicLimit(limitFormula, codeData) {
    console.log('한도 수식:', limitFormula)
    
    // 단순 숫자인 경우
    if (/^\d+$/.test(limitFormula)) {
      return parseInt(limitFormula)
    }
    
    // 수식인 경우 파싱
    let calculatedLimit = limitFormula
    const customFields = {}
    
    // 모든 커스텀 필드 값 수집
    this.element.querySelectorAll('[data-field-name]').forEach(field => {
      const fieldName = field.dataset.fieldName
      const fieldType = field.dataset.fieldType
      
      if (fieldType === 'participants' || fieldName === '참석자') {
        // Choice.js 멀티셀렉트인 경우
        if (field.tagName === 'SELECT' && field.multiple && field._choices) {
          const values = field._choices.getValue(true)
          customFields[fieldName] = values.length
          console.log(`Choice.js 멀티셀렉트 - ${fieldName}: ${values.length}명`)
          // 수식에서 필드명과 레이블 모두 치환
          calculatedLimit = calculatedLimit.replace(new RegExp(`#${fieldName}`, 'g'), values.length)
          calculatedLimit = calculatedLimit.replace(new RegExp(`#참석자`, 'g'), values.length)
        } else if (field.value) {
          // 일반 입력 필드인 경우 (쉼표로 구분된 값)
          const participantCount = field.value.split(',').map(v => v.trim()).filter(v => v).length
          customFields[fieldName] = participantCount
          calculatedLimit = calculatedLimit.replace(new RegExp(`#${fieldName}`, 'g'), participantCount)
          calculatedLimit = calculatedLimit.replace(new RegExp(`#참석자`, 'g'), participantCount)
        }
      } else if (fieldType === 'number' || field.type === 'number') {
        const value = parseInt(field.value) || 0
        customFields[fieldName] = value
        calculatedLimit = calculatedLimit.replace(new RegExp(`#${fieldName}`, 'g'), value)
      }
    })
    
    console.log('커스텀 필드 값:', customFields)
    console.log('치환된 수식:', calculatedLimit)
    
    // 아직 치환되지 않은 플레이스홀더가 있으면 계산 불가
    if (calculatedLimit.includes('#')) {
      console.log('미치환 플레이스홀더 존재:', calculatedLimit)
      return null
    }
    
    // 안전한 수식 평가 (숫자와 기본 연산자만 허용)
    if (/^[\d\s\+\-\*\/\(\)]+$/.test(calculatedLimit)) {
      try {
        const result = eval(calculatedLimit)
        console.log('계산 결과:', result)
        return result
      } catch (e) {
        console.error('수식 평가 실패:', e)
        return null
      }
    }
    
    return null
  }
  
  // 한도 표시 형식 - 참석자 수를 직접 가져오기
  formatLimitDisplay(limitFormula, calculatedLimit) {
    // 수식인 경우 상세 표시
    if (limitFormula.includes('#')) {
      let participantCount = 0
      
      // 참석자 필드 찾기 - data-field-name으로 검색
      this.element.querySelectorAll('[data-field-name]').forEach(field => {
        const fieldName = field.dataset.fieldName
        const fieldType = field.dataset.fieldType
        
        if (fieldType === 'participants' || fieldName === '참석자') {
          if (field.tagName === 'SELECT' && field.multiple && field._choices) {
            // Choice.js 사용
            const values = field._choices.getValue(true)
            participantCount = values.length
            console.log('formatLimitDisplay - Choice.js에서 참석자 수:', participantCount)
          } else if (field.tagName === 'SELECT' && field.multiple) {
            // 일반 멀티셀렉트
            participantCount = Array.from(field.selectedOptions).length
          } else if (field.value) {
            // 일반 입력 필드 (쉼표로 구분된 값)
            participantCount = field.value.split(',').map(v => v.trim()).filter(v => v).length
          }
        }
      })
      
      // OTME 특별 처리
      if (limitFormula.includes('참석자') && limitFormula.includes('15000')) {
        return `₩${this.formatCurrency(calculatedLimit)} (참석자 ${participantCount}명 × ₩15,000)`
      }
      
      // 일반 수식
      const displayFormula = limitFormula.replace(/#참석자/g, participantCount)
      return `₩${this.formatCurrency(calculatedLimit)} (${displayFormula})`
    }
    
    // 단순 금액
    return `₩${this.formatCurrency(calculatedLimit)}`
  }
  
  // 통화 형식
  formatCurrency(amount) {
    return amount.toString().replace(/\B(?=(\d{3})+(?!\d))/g, ',')
  }
  
  // 한도 초과 에러 표시 (간단한 스타일)
  showAmountLimitError(amountInput, limitDisplay, calculatedLimit) {
    // 기존 에러 제거
    this.clearAmountLimitError()
    
    // 금액 필드에 빨간 테두리
    amountInput.classList.add('border-red-300')
    amountInput.classList.remove('border-green-300')
    
    // 에러 메시지 생성 (간단한 텍스트 형식)
    const errorP = document.createElement('p')
    errorP.id = 'amount-limit-error'
    errorP.className = 'field-error mt-1 text-sm text-red-600'
    errorP.textContent = `한도 초과: ${limitDisplay}`
    
    // 금액 필드 다음에 삽입
    amountInput.parentElement.appendChild(errorP)
    
    // 에러 맵에 추가
    this.validationErrors.set('amount_limit', `한도 초과: ${limitDisplay}`)
    this.updateSubmitButton()
  }
  
  // 한도 에러 제거
  clearAmountLimitError(amountInput = null) {
    // 에러 메시지 제거
    const errorDiv = document.getElementById('amount-limit-error')
    if (errorDiv) {
      errorDiv.remove()
    }
    
    // 금액 필드 테두리 정상화
    if (!amountInput) {
      amountInput = document.querySelector('input[name="expense_item[amount]"]:not([type="hidden"])')
    }
    if (amountInput) {
      amountInput.classList.remove('border-red-300')
    }
    
    // 에러 맵에서 제거
    this.validationErrors.delete('amount_limit')
    this.updateSubmitButton()
  }
  
  // 날짜가 제출된 시트에 해당하는지 검증
  async validateDateForSubmittedSheet(dateField) {
    console.log('=== validateDateForSubmittedSheet 시작 ===')
    
    const selectedDate = dateField.value
    if (!selectedDate) {
      this.clearDateSheetError()
      return
    }
    
    // 날짜에서 년/월 추출
    const date = new Date(selectedDate)
    const year = date.getFullYear()
    const month = date.getMonth() + 1 // JavaScript의 월은 0부터 시작
    
    // 현재 시트 정보 가져오기
    const currentSheetYear = parseInt(this.element.dataset.sheetYear || new Date().getFullYear())
    const currentSheetMonth = parseInt(this.element.dataset.sheetMonth || new Date().getMonth() + 1)
    
    console.log(`선택된 날짜: ${year}년 ${month}월, 현재 시트: ${currentSheetYear}년 ${currentSheetMonth}월`)
    
    // 같은 월이면 체크 불필요
    if (year === currentSheetYear && month === currentSheetMonth) {
      this.clearDateSheetError()
      return
    }
    
    try {
      // 서버에 해당 월 시트 상태 확인 요청
      const response = await fetch(`/expense_sheets/check_month_status?year=${year}&month=${month}`, {
        headers: {
          'Accept': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]')?.content
        }
      })
      
      if (!response.ok) {
        console.error('시트 상태 확인 실패:', response.statusText)
        return
      }
      
      const data = await response.json()
      console.log('시트 상태 응답:', data)
      
      if (data.sheet_exists && !data.editable) {
        // 제출된 시트에 해당하는 날짜인 경우 에러 표시
        this.showDateSheetError(dateField, year, month, data.status)
      } else {
        // 문제 없는 경우 에러 제거
        this.clearDateSheetError()
      }
    } catch (error) {
      console.error('시트 상태 확인 중 오류:', error)
      // 네트워크 오류 등의 경우 일단 통과
      this.clearDateSheetError()
    }
  }
  
  // 날짜 시트 에러 표시 (빨간색 에러로 변경)
  showDateSheetError(dateField, year, month, status) {
    // 기존 에러 제거
    this.clearDateSheetError()
    
    // 날짜 필드에 에러 테두리
    dateField.classList.add('border-red-300')
    dateField.classList.remove('border-green-300', 'border-yellow-500')
    
    // 상태별 메시지
    let statusText = ''
    switch(status) {
      case 'submitted':
        statusText = '제출됨'
        break
      case 'approved':
        statusText = '승인됨'
        break
      case 'closed':
        statusText = '마감됨'
        break
      default:
        statusText = status
    }
    
    // 에러 메시지 생성 (빨간색 에러)
    const errorP = document.createElement('p')
    errorP.id = 'date-sheet-error'
    errorP.className = 'field-error mt-1 text-sm text-red-600'
    errorP.textContent = `${year}년 ${month}월 시트는 이미 ${statusText} 상태입니다. 다른 날짜를 선택하세요.`
    
    // 날짜 필드 다음에 삽입
    dateField.parentElement.appendChild(errorP)
    
    // 에러맵에 추가하여 제출 차단
    this.validationErrors.set('date_sheet', `${year}년 ${month}월 시트는 이미 ${statusText} 상태`)
    this.updateSubmitButton()
  }
  
  // 날짜 시트 에러 제거
  clearDateSheetError() {
    // 에러 메시지 제거
    const errorP = document.getElementById('date-sheet-error')
    if (errorP) {
      errorP.remove()
    }
    
    // 날짜 필드 테두리 정상화
    const dateField = document.querySelector('input[name="expense_item[expense_date]"]')
    if (dateField) {
      dateField.classList.remove('border-red-300', 'border-yellow-500')
    }
    
    // 에러맵에서 제거
    this.validationErrors.delete('date_sheet')
    this.updateSubmitButton()
  }
  
  // 저장 버튼 상태 업데이트
  updateSubmitButton() {
    // 저장 버튼이 없으면 종료
    if (!this.hasSubmitButtonTarget) {
      console.log('저장 버튼 target이 없음')
      return
    }
    
    const submitButton = this.submitButtonTarget
    const hasErrors = this.validationErrors.size > 0
    
    console.log('검증 에러 개수:', this.validationErrors.size, '에러:', Array.from(this.validationErrors.entries()))
    
    if (hasErrors) {
      // 에러가 있으면 버튼 비활성화
      submitButton.disabled = true
      submitButton.classList.add('opacity-50', 'cursor-not-allowed')
      submitButton.classList.remove('hover:bg-indigo-700')
      
      // 버튼 텍스트에 에러 개수 표시
      // form.submit은 input[type="submit"]을 생성하므로 value 속성 사용
      const originalText = submitButton.dataset.originalText || submitButton.value || submitButton.textContent
      if (!submitButton.dataset.originalText) {
        submitButton.dataset.originalText = submitButton.value || submitButton.textContent
      }
      
      if (submitButton.tagName === 'INPUT') {
        submitButton.value = `${originalText} (오류 ${this.validationErrors.size}개)`
      } else {
        submitButton.textContent = `${originalText} (오류 ${this.validationErrors.size}개)`
      }
      
      // 커스텀 툴팁 텍스트 설정
      if (this.hasTooltipTextTarget) {
        const errorFields = Array.from(this.validationErrors.values())
        const fieldNames = errorFields.flatMap(msg => {
          // msg가 배열인 경우 처리
          if (Array.isArray(msg)) {
            return msg.map(m => String(m).replace(' 필수', ''))
          }
          // msg가 문자열인 경우
          return String(msg).replace(' 필수', '')
        })
        this.tooltipTextTarget.textContent = `${fieldNames.join(', ')} 필수`
      }
    } else {
      // 에러가 없으면 버튼 활성화
      submitButton.disabled = false
      submitButton.classList.remove('opacity-50', 'cursor-not-allowed')
      submitButton.classList.add('hover:bg-indigo-700')
      
      // 원래 텍스트로 복원
      if (submitButton.dataset.originalText) {
        if (submitButton.tagName === 'INPUT') {
          submitButton.value = submitButton.dataset.originalText
        } else {
          submitButton.textContent = submitButton.dataset.originalText
        }
      }
      
      // 커스텀 툴팁 숨기기
      if (this.hasTooltipTarget) {
        this.tooltipTarget.classList.add('hidden')
      }
    }
  }
}