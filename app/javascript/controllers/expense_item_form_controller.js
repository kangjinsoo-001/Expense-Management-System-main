import { Controller } from "@hotwired/stimulus"

let Choices

export default class extends Controller {
  static targets = [
    "expenseCode", "customFields", "costCenter", "amount",
    "attachmentCount", "attachmentInfo", "attachmentDetails",
    "extractedAmount", "extractedDate", "extractedVendor", "attachmentIds",
    "expenseDate", "description"
  ]
  static values = { 
    expenseSheetId: String,
    expenseCodesData: Object
  }

  async connect() {
    console.log("Expense item form controller connected")
    console.log("Edit mode at connect:", this.element.dataset.editMode)
    
    // Choices.js 로드
    await this.loadChoicesJS()
    
    // 초기 경비 코드 ID 저장
    this.previousExpenseCodeId = this.hasExpenseCodeTarget ? this.expenseCodeTarget.value : null
    
    // 데이터 로딩 상태 플래그
    this.isLoadingData = false
    
    // 초기화
    this.loadUsersAndOrganizations()
    this.initializeExpenseCode()
    this.initializeCostCenter()
    this.initializeMultiSelects()
    this.setupAmountListener()
    
    // 캘린더 열림 상태 플래그
    this.pickerOpened = false
  }
  
  disconnect() {
    // 컨트롤러 연결 해제 시 플래그 리셋
    this.pickerOpened = false
  }
  
  // Rails Way: focus 이벤트로 캘린더 열기
  openDatePicker(event) {
    // DOM이 완전히 준비되었는지 확인 (Turbo 렌더링 완료)
    requestAnimationFrame(() => {
      // 첫 번째 focus에서만 캘린더 열기 (autofocus인 경우)
      if (!this.pickerOpened && event.target.showPicker) {
        try {
          event.target.showPicker()
          this.pickerOpened = true
        } catch (error) {
          // 사용자 제스처가 필요하거나 브라우저가 지원하지 않는 경우
          console.log("Date picker auto-open not available:", error)
        }
      }
    })
  }
  
  async loadChoicesJS() {
    if (window.Choices) {
      Choices = window.Choices
      return
    }
    
    return new Promise((resolve) => {
      const script = document.createElement('script')
      script.src = '/javascripts/choices.min.js'
      script.onload = () => {
        Choices = window.Choices
        resolve()
      }
      script.onerror = () => {
        console.error("Failed to load Choices.js")
        resolve()
      }
      if (!document.querySelector('script[src="/javascripts/choices.min.js"]')) {
        document.head.appendChild(script)
      } else {
        resolve()
      }
    })
  }
  
  checkExpenseSheet(event) {
    const selectedDate = new Date(event.target.value)
    const currentYear = parseInt(event.target.dataset.currentSheetYear)
    const currentMonth = parseInt(event.target.dataset.currentSheetMonth)
    
    // 선택된 날짜의 년월 확인
    const selectedYear = selectedDate.getFullYear()
    const selectedMonth = selectedDate.getMonth() + 1 // 0-based index
    
    // 현재 시트와 다른 월인 경우에도 confirm 없이 자동 처리
    if (selectedYear !== currentYear || selectedMonth !== currentMonth) {
      const monthNames = ['1월', '2월', '3월', '4월', '5월', '6월', '7월', '8월', '9월', '10월', '11월', '12월']
      const selectedMonthName = monthNames[selectedMonth - 1]
      
      // confirm 창 없이 바로 진행 - 서버에서 필요한 시트를 자동으로 생성하거나 처리
      console.log(`다른 월 선택: ${selectedYear}년 ${selectedMonthName} - 서버에서 자동 처리`)
      // 사용자 선택한 날짜 그대로 유지
    }
  }
  
  setupAmountListener() {
    // 금액 입력 필드에 이벤트 리스너 추가
    if (this.hasAmountTarget) {
      // debounce를 위한 타이머
      let timeoutId
      
      this.amountTarget.addEventListener('input', (event) => {
        clearTimeout(timeoutId)
        timeoutId = setTimeout(() => {
          // 경비 코드가 선택되어 있으면 검증 메시지 업데이트
          if (this.expenseCodeTarget.value) {
            const expenseCodeData = this.expenseCodesDataValue[this.expenseCodeTarget.value]
            if (expenseCodeData) {
              this.updateValidationMessage(expenseCodeData)
            }
          }
          
          // 결재선 검증 컨트롤러에 금액 변경 알림
          const approvalController = this.element.querySelector('[data-controller="expense-item-approval"]')
          if (approvalController) {
            const controller = this.application.getControllerForElementAndIdentifier(
              approvalController, 
              'expense-item-approval'
            )
            if (controller && controller.revalidateApprovalLine) {
              controller.revalidateApprovalLine()
            }
          }
        }, 500) // 500ms 디바운스
      })
    }
  }

  // 경비 코드 변경 시
  expenseCodeChanged(event) {
    console.log("=== expenseCodeChanged 호출됨 ===")
    console.log("Event type:", event.type)
    console.log("Event target:", event.target)
    const selectedCodeId = this.expenseCodeTarget.value
    console.log("Selected code ID:", selectedCodeId)
    
    // 이전 경비 코드 저장 (처음 변경이 아닌지 확인용)
    const previousCodeId = this.previousExpenseCodeId
    this.previousExpenseCodeId = selectedCodeId
    
    // 경비 코드가 변경되면 기존 검증 에러 초기화
    if (previousCodeId !== selectedCodeId) {
      console.log("경비 코드 변경됨 - 검증 에러 초기화")
      // client-validation 컨트롤러의 검증 에러 초기화
      const form = this.element
      const validationController = this.application.getControllerForElementAndIdentifier(
        form, 
        'client-validation'
      )
      if (validationController && validationController.validationErrors) {
        // 커스텀 필드 관련 에러만 제거
        const keysToRemove = []
        validationController.validationErrors.forEach((value, key) => {
          if (key.includes('custom_fields')) {
            keysToRemove.push(key)
          }
        })
        keysToRemove.forEach(key => {
          validationController.validationErrors.delete(key)
        })
        // 제출 버튼 상태 업데이트
        if (validationController.updateSubmitButton) {
          validationController.updateSubmitButton()
        }
      }
      
      // 기존 에러 메시지 DOM 제거
      const existingErrors = this.element.querySelectorAll('.field-error')
      existingErrors.forEach(error => {
        // 커스텀 필드 관련 에러만 제거
        const parentField = error.previousElementSibling
        if (parentField && parentField.name && parentField.name.includes('custom_fields')) {
          error.remove()
        }
      })
    }
    
    if (selectedCodeId) {
      // 로컬 데이터에서 경비 코드 정보 가져오기
      const expenseCodeData = this.expenseCodesDataValue[selectedCodeId]
      
      if (expenseCodeData) {
        // 가이드 정보 업데이트
        this.updateExpenseCodeGuide(expenseCodeData)
        
        // 추가 필드 업데이트 (edit 모드가 아니거나 경비 코드가 변경된 경우)
        // edit 페이지에서도 경비 코드를 변경하면 추가 필드를 업데이트해야 함
        if (this.element.dataset.editMode !== 'true' || previousCodeId !== selectedCodeId) {
          // 경비 코드가 변경되면 기존 최근 작성 내용 알림 제거
          const existingNotification = document.querySelector('.expense-autofill-notification')
          if (existingNotification) {
            existingNotification.remove()
          }
          
          // 추가 필드 업데이트
          this.updateCustomFields(expenseCodeData)
        }
        
        // 승인 조건 검증 메시지 업데이트
        this.updateValidationMessage(expenseCodeData)
        
        // 첨부파일 필수 여부 업데이트
        this.updateAttachmentRequirement(expenseCodeData)
        
        // 최근 제출 내역 자동 불러오기 (새 항목 작성 시에만, 그리고 이전과 다른 코드일 때)
        console.log("Edit mode check:", this.element.dataset.editMode, typeof this.element.dataset.editMode)
        // dataset.editMode는 문자열 'true' 또는 'false'이므로 문자열 비교 필요
        if (this.element.dataset.editMode !== 'true' && previousCodeId !== selectedCodeId) {
          console.log("Loading recent submission for expense code:", selectedCodeId)
          this.loadRecentSubmission(selectedCodeId)
        }
        
        // 결재선 재검증
        setTimeout(() => {
          const approvalController = this.element.querySelector('[data-controller="expense-item-approval"]')
          if (approvalController) {
            const controller = this.application.getControllerForElementAndIdentifier(
              approvalController, 
              'expense-item-approval'
            )
            if (controller && controller.revalidateApprovalLine) {
              controller.revalidateApprovalLine()
            }
          }
        }, 100)
      }
    } else {
      // 선택 해제 시 영역 숨기기
      document.getElementById('expense_code_guide').classList.add('hidden')
      document.getElementById('expense_code_validation').innerHTML = ''
      const customFieldsFrame = document.querySelector('turbo-frame#custom_fields_container')
      if (customFieldsFrame) {
        customFieldsFrame.innerHTML = ''
      }
    }
  }
  
  // 가이드 정보 업데이트
  updateExpenseCodeGuide(expenseCodeData) {
    const guideElement = document.getElementById('expense_code_guide')
    if (!guideElement) return
    
    if (expenseCodeData) {
      guideElement.classList.remove('hidden')
      
      // 첨부파일 필수 여부에 따라 배경색 변경
      const bgColorClass = expenseCodeData.attachment_required ? 'bg-yellow-50 border-yellow-200' : 'bg-blue-50 border-blue-200'
      const iconColor = expenseCodeData.attachment_required ? 'text-yellow-600' : 'text-blue-600'
      const textColor = expenseCodeData.attachment_required ? 'text-yellow-800' : 'text-blue-800'
      
      // 클래스 업데이트
      guideElement.className = `mt-2 p-3 rounded-md border ${bgColorClass}`
      
      const guideContent = `
        <div class="flex items-start gap-2">
          ${expenseCodeData.attachment_required ? 
            `<svg class="h-4 w-4 ${iconColor} mt-0.5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
            </svg>` :
            `<svg class="h-4 w-4 ${iconColor} mt-0.5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>`
          }
          <div class="text-sm ${textColor}">
            <p class="font-medium">${expenseCodeData.name}</p>
            <div class="text-xs mt-1 whitespace-pre-wrap">${expenseCodeData.description || '설명 없음'}</div>
            ${expenseCodeData.limit_amount ? `<p class="text-xs mt-1">한도: <span class="font-medium">${expenseCodeData.limit_amount_display}</span></p>` : ''}
            ${expenseCodeData.attachment_required ? 
              `<p class="text-xs mt-2 font-semibold flex items-center gap-1">
                <svg class="h-3 w-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15.172 7l-6.586 6.586a2 2 0 102.828 2.828l6.414-6.586a4 4 0 00-5.656-5.656l-6.415 6.585a6 6 0 108.486 8.486L20.5 13" />
                </svg>
                이 경비 코드는 첨부파일이 필수입니다. 반드시 관련 서류를 첨부해주세요.
              </p>` : ''
            }
          </div>
        </div>
      `
      guideElement.innerHTML = guideContent
    } else {
      guideElement.classList.add('hidden')
    }
  }
  
  // 설명 필드 업데이트 메서드 (더 이상 사용하지 않음 - 설명 필드는 히든 필드로 처리)
  // updateDescriptionField(expenseCodeData) {
  //   // 설명 필드는 이제 히든 필드로 처리되며 자동 생성만 지원
  // }
  
  // 첨부파일 필수 여부 업데이트
  updateAttachmentRequirement(expenseCodeData) {
    // attachment-uploader 컨트롤러를 가진 div 내부의 label 찾기
    const attachmentSection = document.querySelector('[data-controller="attachment-uploader"]')
    if (!attachmentSection) {
      console.log('첨부파일 섹션을 찾을 수 없습니다')
      return
    }
    
    // 첫 번째 label 요소 찾기 (이것이 "첨부 파일" 라벨)
    const attachmentLabel = attachmentSection.querySelector('label')
    
    if (!attachmentLabel) {
      console.log('첨부파일 라벨을 찾을 수 없습니다')
      return
    }
    
    // 예산 모드 체크박스 확인
    const budgetCheckbox = document.querySelector('input[type="checkbox"][name="expense_item[is_budget]"]')
    const isBudgetMode = budgetCheckbox ? budgetCheckbox.checked : false
    
    if (expenseCodeData.attachment_required) {
      if (isBudgetMode) {
        // 예산 모드에서는 선택사항으로 표시 (별표만)
        attachmentLabel.innerHTML = `첨부 파일`
      } else {
        // 일반 모드에서는 필수로 표시 (별표만)
        attachmentLabel.innerHTML = `
          첨부 파일
          <span class="text-red-500">*</span>
        `
      }
    } else {
      // 필수 표시 제거
      attachmentLabel.innerHTML = '첨부 파일'
    }
  }
  
  // 추가 필드 업데이트
  updateCustomFields(expenseCodeData) {
    const customFieldsFrame = document.querySelector('turbo-frame#custom_fields_container')
    if (!customFieldsFrame) return
    
    // 기존 Choice.js 인스턴스 정리
    const existingSelects = customFieldsFrame.querySelectorAll('select[data-choices-initialized]')
    existingSelects.forEach(select => {
      if (select._choices) {
        select._choices.destroy()
        delete select._choices
      }
    })
    
    // required_fields가 없거나 빈 객체인 경우 체크
    if (!expenseCodeData.validation_rules?.required_fields || 
        (typeof expenseCodeData.validation_rules.required_fields === 'object' && 
         Object.keys(expenseCodeData.validation_rules.required_fields).length === 0)) {
      customFieldsFrame.innerHTML = ''
      return
    }
    
    // 새로운 필드 HTML 생성 (기존 값 보존하지 않음 - 경비 코드가 변경되었으므로)
    let customFieldsHtml = '<div class="mt-4 p-4 bg-gray-50 rounded-lg">'
    customFieldsHtml += '<h4 class="text-sm font-medium text-gray-900 mb-3">추가 필드</h4>'
    
    const requiredFields = this.processRequiredFields(expenseCodeData.validation_rules.required_fields)
    
    console.log("=== 생성할 필드 순서 ===")
    requiredFields.forEach((field, index) => {
      console.log(`${index + 1}. ${field.label} (key: ${field.field_key}, order: ${field.order})`)
    })
    
    requiredFields.forEach(fieldConfig => {
      const fieldKey = fieldConfig.field_key || fieldConfig.name || fieldConfig.field
      const fieldLabel = fieldConfig.label || fieldKey
      const fieldRequired = fieldConfig.required !== false
      
      // 경비 코드가 변경되었으므로 기존 값을 null로 설정
      customFieldsHtml += this.generateFieldHtml(fieldKey, fieldLabel, fieldRequired, fieldConfig, null)
    })
    
    customFieldsHtml += '</div>'
    customFieldsFrame.innerHTML = customFieldsHtml
    
    // Choice.js 초기화를 위해 MutationObserver 트리거
    this.setupChoicesForCustomFields()
  }
  
  // 필수 필드 데이터 처리
  processRequiredFields(requiredFieldsRaw) {
    let requiredFields = []
    
    if (Array.isArray(requiredFieldsRaw)) {
      requiredFieldsRaw.forEach(fieldName => {
        requiredFields.push({ name: fieldName, label: fieldName, required: true, order: 999 })
      })
    } else if (typeof requiredFieldsRaw === 'object') {
      const sortedFields = Object.entries(requiredFieldsRaw).map(([key, field]) => ({
        ...field,
        field_key: key,
        order: field.order !== undefined ? field.order : 999
      }))
      // order 값으로 정렬, order가 같으면 키 이름으로 정렬
      requiredFields = sortedFields.sort((a, b) => {
        if (a.order !== b.order) {
          return a.order - b.order
        }
        return a.field_key.localeCompare(b.field_key)
      })
    }
    
    return requiredFields
  }
  
  // 필드 HTML 생성
  generateFieldHtml(fieldKey, fieldLabel, fieldRequired, fieldConfig, existingValue = null) {
    const fieldOrder = fieldConfig.order || 999
    let html = `<div class="mb-4" data-field-name="${fieldKey}" data-field-order="${fieldOrder}">`
    html += `<label class="block text-sm font-medium text-gray-700">`
    html += fieldLabel
    if (fieldRequired) {
      html += ' <span class="text-red-500">*</span>'
    }
    html += '</label>'
    
    if (fieldConfig.type === 'number') {
      const value = existingValue || ''
      html += `<input type="number" name="expense_item[custom_fields][${fieldKey}]" 
                      value="${value}"
                      class="mt-1 block w-full px-3 py-2 bg-white border border-gray-300 rounded-md focus:outline-none focus:border-gray-400 focus:ring-1 focus:ring-gray-400 focus:ring-opacity-25 sm:text-sm"
                      data-field-name="${fieldKey}" data-field-required="${fieldRequired}">`
    } else if (fieldConfig.type === 'select') {
      html += `<select name="expense_item[custom_fields][${fieldKey}]" 
                       class="mt-1 block w-full px-3 py-2 bg-white border border-gray-300 rounded-md focus:outline-none focus:border-gray-400 focus:ring-1 focus:ring-gray-400 focus:ring-opacity-25 sm:text-sm"
                       data-field-name="${fieldKey}" data-field-required="${fieldRequired}">`
      html += '<option value="">선택하세요</option>'
      if (fieldConfig.options) {
        fieldConfig.options.forEach(option => {
          const selected = existingValue === option ? 'selected' : ''
          html += `<option value="${option}" ${selected}>${option}</option>`
        })
      }
      html += '</select>'
    } else if (fieldConfig.type === 'participants' || fieldConfig.type === 'organization') {
      // 멀티셀렉트 - 기존 값을 data 속성으로 전달
      const selectedValues = Array.isArray(existingValue) ? existingValue : (existingValue ? existingValue.split(', ') : [])
      html += `<select name="expense_item[custom_fields][${fieldKey}][]" 
                       multiple="true"
                       class="mt-1 block w-full bg-white border border-gray-300 rounded-md focus:outline-none focus:border-gray-400 focus:ring-1 focus:ring-gray-400 focus:ring-opacity-25 sm:text-sm"
                       data-choices="true"
                       data-field-type="${fieldConfig.type}"
                       data-field-name="${fieldKey}"
                       data-field-required="${fieldRequired}"
                       data-selected-values='${JSON.stringify(selectedValues)}'></select>`
    } else {
      const value = existingValue || ''
      html += `<input type="text" name="expense_item[custom_fields][${fieldKey}]" 
                      value="${value}"
                      class="mt-1 block w-full px-3 py-2 bg-white border border-gray-300 rounded-md focus:outline-none focus:border-gray-400 focus:ring-1 focus:ring-gray-400 focus:ring-opacity-25 sm:text-sm"
                      data-field-name="${fieldKey}" data-field-required="${fieldRequired}">`
    }
    
    html += '</div>'
    return html
  }
  
  // 승인 조건 검증 메시지 업데이트
  updateValidationMessage(expenseCodeData) {
    const validationElement = document.getElementById('expense_code_validation')
    if (!validationElement) return
    
    // 금액 기반 승인 규칙 확인
    const amount = this.hasAmountTarget ? parseInt(this.amountTarget.value) || 0 : 0
    const triggeredRules = []
    
    if (expenseCodeData.approval_rules && amount > 0) {
      expenseCodeData.approval_rules.forEach(rule => {
        if (rule.rule_type === 'amount_greater_than' && amount > rule.condition_value) {
          triggeredRules.push(rule)
        }
      })
    }
    
    if (triggeredRules.length > 0) {
      const requiredGroups = triggeredRules.map(rule => rule.approver_group.name).join(', ')
      const validationHtml = `
        <div class="p-3 bg-yellow-50 border border-yellow-200 rounded-md">
          <div class="flex items-start gap-2">
            <svg class="h-4 w-4 text-yellow-600 mt-0.5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
            </svg>
            <div class="text-sm text-yellow-800">
              <p>승인 필요: ${requiredGroups}</p>
            </div>
          </div>
        </div>
      `
      validationElement.innerHTML = validationHtml
    } else if (expenseCodeData.approval_rules && expenseCodeData.approval_rules.length > 0) {
      // 승인 규칙은 있지만 조건을 충족하지 않는 경우
      const validationHtml = `
        <div class="p-3 bg-green-50 border border-green-200 rounded-md">
          <div class="flex items-start gap-2">
            <svg class="h-4 w-4 text-green-600 mt-0.5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
            <div class="text-sm text-green-800">
              <p>승인 조건 충족</p>
            </div>
          </div>
        </div>
      `
      validationElement.innerHTML = validationHtml
    } else {
      validationElement.innerHTML = ''
    }
  }

  // 사용자와 조직 데이터 프리로드
  async loadUsersAndOrganizations() {
    try {
      // 캐시 확인
      const cachedData = this.getCachedData()
      if (cachedData) {
        this.users = cachedData.users
        this.organizations = cachedData.organizations
        return
      }

      // 캐시가 없으면 서버에서 로드
      const [usersResponse, orgsResponse] = await Promise.all([
        fetch('/api/users/all'),
        fetch('/api/organizations/all')
      ])

      if (usersResponse.ok && orgsResponse.ok) {
        this.users = await usersResponse.json()
        this.organizations = await orgsResponse.json()
        
        // 캐시에 저장 (1시간)
        this.setCachedData({
          users: this.users,
          organizations: this.organizations
        })
      }
    } catch (error) {
      console.error('Failed to load users and organizations:', error)
    }
  }

  // 엔터키 제출 방지 (아무 동작 없음)
  preventEnterSubmit(event) {
    if (event.key === 'Enter' && event.target.tagName !== 'TEXTAREA') {
      event.preventDefault()
    }
  }
  
  // 기존 모달 메서드는 제거됨 - attachment_uploader_controller.js 사용

  // 캐시 관련 메서드
  getCachedData() {
    const cached = localStorage.getItem('expense_form_data')
    if (!cached) return null
    
    const data = JSON.parse(cached)
    const now = new Date().getTime()
    
    // 1시간 이내 데이터만 유효
    if (now - data.timestamp < 3600000) {
      return data
    }
    
    localStorage.removeItem('expense_form_data')
    return null
  }

  setCachedData(data) {
    const cacheData = {
      ...data,
      timestamp: new Date().getTime()
    }
    localStorage.setItem('expense_form_data', JSON.stringify(cacheData))
  }
  
  // Choice.js 멀티셀렉트 초기화
  initializeMultiSelects() {
    // custom fields가 로드된 후에 초기화되도록 MutationObserver 사용
    if (this.hasCustomFieldsTarget) {
      const observer = new MutationObserver((mutations) => {
        mutations.forEach((mutation) => {
          if (mutation.type === 'childList') {
            this.setupChoicesForCustomFields()
          }
        })
      })
      
      observer.observe(this.customFieldsTarget, { childList: true, subtree: true })
      
      // 이미 custom fields가 있으면 즉시 초기화
      if (this.customFieldsTarget.innerHTML.trim()) {
        this.setupChoicesForCustomFields()
      }
    }
  }
  
  // Custom fields 내의 멀티셀렉트 필드에 Choices 적용
  setupChoicesForCustomFields() {
    const selectFields = this.customFieldsTarget.querySelectorAll('select[data-choices]')
    
    selectFields.forEach(selectField => {
      if (selectField && !selectField.hasAttribute('data-choices-initialized')) {
        selectField.setAttribute('data-choices-initialized', 'true')
        
        const fieldType = selectField.dataset.fieldType
        const placeholder = selectField.dataset.placeholder
        let choices = []
        
        if (fieldType === 'participants' && this.users) {
          choices = this.users.map(user => ({
            value: user.name,
            label: `${user.name} (${user.department || '소속 없음'})`,
            customProperties: { id: user.id, department: user.department }
          }))
        } else if (fieldType === 'organization' && this.organizations) {
          choices = this.organizations.map(org => ({
            value: org.name,
            label: `${org.name}`,
            customProperties: { id: org.id, code: org.code }
          }))
        }
        
        // 기존 선택값 가져오기
        const selectedValues = selectField.dataset.selectedValues ? JSON.parse(selectField.dataset.selectedValues) : []
        
        const choicesInstance = new Choices(selectField, {
          removeItemButton: true,
          searchEnabled: true,
          searchResultLimit: 10,
          placeholder: false,
          placeholderValue: '',
          noResultsText: '검색 결과가 없습니다',
          noChoicesText: '선택할 항목이 없습니다',
          itemSelectText: '선택하려면 클릭',
          choices: choices,
          renderChoiceLimit: -1,
          maxItemCount: -1,
          shouldSort: false,
          searchFloor: 1,
          searchPlaceholderValue: '검색...',
          allowHTML: false,  // deprecation 경고 해결
          classNames: {
            containerOuter: 'choices',
            containerInner: 'choices__inner',
            input: 'choices__input',
            inputCloned: 'choices__input--cloned',
            list: 'choices__list',
            listItems: 'choices__list--multiple',
            listSingle: 'choices__list--single',
            listDropdown: 'choices__list--dropdown',
            item: 'choices__item',
            itemSelectable: 'choices__item--selectable',
            itemDisabled: 'choices__item--disabled',
            itemChoice: 'choices__item--choice',
            placeholder: 'choices__placeholder',
            group: 'choices__group',
            groupHeading: 'choices__heading',
            button: 'choices__button',
            activeState: 'is-active',
            focusState: 'is-focused',
            openState: 'is-open',
            disabledState: 'is-disabled',
            highlightedState: 'is-highlighted',
            selectedState: 'is-selected',
            flippedState: 'is-flipped',
            loadingState: 'is-loading',
            noResults: 'has-no-results',
            noChoices: 'has-no-choices'
          }
        })
        
        // Choice.js 인스턴스를 요소에 저장
        selectField._choices = choicesInstance
        
        // 기존 선택값 설정
        if (selectedValues.length > 0) {
          // Choice.js에 선택값 설정
          setTimeout(() => {
            selectedValues.forEach(value => {
              // choices 배열에서 해당 값(이름)으로 찾기
              const choice = choices.find(c => c.value === value)
              if (choice) {
                choicesInstance.setChoiceByValue(value)
              } else {
                // choices 배열에 없는 경우 직접 추가
                choicesInstance.setChoices([{
                  value: value,
                  label: value,
                  selected: true
                }], 'value', 'label', false)
              }
            })
          }, 100)
        }
        
        // 변경사항을 원본 select 요소에 반영
        selectField.addEventListener('change', (event) => {
          const selectedValues = choicesInstance.getValue(true)
          console.log('멀티셀렉트 change 이벤트 - Selected values:', selectedValues)
          
          // 기존 옵션 모두 제거
          selectField.innerHTML = ''
          
          // 선택된 값들을 option으로 추가하고 selected 상태로 설정
          selectedValues.forEach(value => {
            const option = document.createElement('option')
            option.value = value
            option.textContent = value
            option.selected = true
            selectField.appendChild(option)
          })
          
          // 데이터 로딩 중이 아닐 때만 검증 트리거
          if (!this.isLoadingData) {
            console.log('멀티셀렉트 - 검증 트리거 호출')
            this.triggerValidation()
          } else {
            console.log('멀티셀렉트 - 데이터 로딩 중, 검증 건너뜀')
          }
        }, false)
        
        // Choice.js의 아이템 추가/제거 이벤트도 감지
        selectField.addEventListener('addItem', (event) => {
          console.log('Choice.js addItem 이벤트:', event.detail)
          // change 이벤트 수동 발생
          const changeEvent = new Event('change', { bubbles: true })
          selectField.dispatchEvent(changeEvent)
        })
        
        selectField.addEventListener('removeItem', (event) => {
          console.log('Choice.js removeItem 이벤트:', event.detail)
          // change 이벤트 수동 발생
          const changeEvent = new Event('change', { bubbles: true })
          selectField.dispatchEvent(changeEvent)
        })
      }
    })
  }
  
  // 경비 코드 Choice.js 초기화
  initializeExpenseCode() {
    if (this.hasExpenseCodeTarget && this.expenseCodeTarget.dataset.choices) {
      const selectElement = this.expenseCodeTarget
      
      // 이미 초기화되었으면 스킵
      if (selectElement.hasAttribute('data-choices-initialized')) {
        return
      }
      
      console.log("Initializing expense code Choice.js")
      console.log("Original options count:", selectElement.options.length)
      
      selectElement.setAttribute('data-choices-initialized', 'true')
      
      // Choice.js 초기화 - choices 옵션을 제거하여 DOM의 옵션을 그대로 사용
      const choicesInstance = new Choices(selectElement, {
        removeItemButton: false,
        searchEnabled: true,
        searchResultLimit: 10,
        placeholder: false,
        placeholderValue: '',
        noResultsText: '검색 결과가 없습니다',
        noChoicesText: '선택할 항목이 없습니다',
        itemSelectText: '선택하려면 클릭',
        shouldSort: false,
        searchFloor: 1,
        searchPlaceholderValue: '코드 또는 이름으로 검색...',
        allowHTML: false  // deprecation 경고 해결
        // choices 옵션을 제거하여 DOM의 기존 옵션을 그대로 사용
      })
      
      // Choice.js 인스턴스를 요소에 저장
      selectElement._choices = choicesInstance
      
      // Choice.js 선택 이벤트 리스너 추가
      selectElement.addEventListener('choice', (event) => {
        // event.detail.choice가 있을 때만 처리
        if (event.detail && event.detail.choice) {
          console.log('Choice.js choice event detected, value:', event.detail.choice.value)
          // 데이터 로딩 중이 아닐 때만 검증 트리거
          if (!this.isLoadingData) {
            this.triggerValidation()
          }
        }
      }, false)
      
      // change 이벤트도 명시적으로 검증 트리거 (Choice.js가 발생시키는 change 이벤트 활용)
      selectElement.addEventListener('change', () => {
        console.log('Expense code change event detected')
        // 데이터 로딩 중이 아닐 때만 검증 트리거
        if (!this.isLoadingData) {
          this.triggerValidation()
        }
      }, false)
    }
  }
  
  // 코스트 센터 Choice.js 초기화
  initializeCostCenter() {
    if (this.hasCostCenterTarget && this.costCenterTarget.dataset.choices) {
      const selectElement = this.costCenterTarget
      
      // 이미 초기화되었으면 스킵
      if (selectElement.hasAttribute('data-choices-initialized')) {
        console.log("Cost center already initialized, skipping")
        return
      }
      
      console.log("Initializing cost center Choice.js")
      console.log("Original options count:", selectElement.options.length)
      console.log("Original options:", Array.from(selectElement.options).map(opt => ({value: opt.value, text: opt.textContent})))
      
      // 현재 선택된 값 저장
      const currentValue = selectElement.value
      console.log("Current selected value before Choice.js init:", currentValue)
      
      selectElement.setAttribute('data-choices-initialized', 'true')
      
      // Choice.js 초기화 - choices 옵션을 제거하여 DOM의 옵션을 그대로 사용
      const choicesInstance = new Choices(selectElement, {
        removeItemButton: false,
        searchEnabled: true,
        searchResultLimit: 10,
        placeholder: false,
        placeholderValue: '',
        noResultsText: '검색 결과가 없습니다',
        noChoicesText: '선택할 항목이 없습니다',
        itemSelectText: '선택하려면 클릭',
        shouldSort: false,
        searchFloor: 1,
        searchPlaceholderValue: '코드 또는 이름으로 검색...',
        allowHTML: false  // deprecation 경고 해결
        // choices 옵션을 제거하여 DOM의 기존 옵션을 그대로 사용
      })
      
      console.log("Choice.js initialized, checking available choices:", choicesInstance._store.choices.length)
      
      // 초기화 후 값이 있었다면 다시 설정
      if (currentValue) {
        console.log("Restoring value after Choice.js init:", currentValue)
        setTimeout(() => {
          choicesInstance.setChoiceByValue(currentValue)
        }, 10)
      }
      
      // Choice.js 인스턴스를 요소에 저장
      selectElement._choices = choicesInstance
      
      // Choice.js 변경 이벤트에서 검증 트리거
      selectElement.addEventListener('change', () => {
        console.log('Cost center change event detected')
        console.log('데이터 로딩 상태:', this.isLoadingData)
        // 데이터 로딩 중이 아닐 때만 검증 트리거
        if (!this.isLoadingData) {
          console.log('코스트 센터 변경으로 검증 트리거')
          this.triggerValidation()
        } else {
          console.log('코스트 센터 변경 - 로딩 중이므로 검증 건너뜀')
        }
      }, false)
    }
  }

  // Choices.js 스타일 강제 적용
  applyChoicesStyles(selectField) {
    const container = selectField.closest('.choices')
    if (!container) return
    
    // 선택된 아이템들의 스타일을 기본값으로 유지 (회색 배경 제거)
    const items = container.querySelectorAll('.choices__item')
    items.forEach(item => {
      // 스타일 초기화 - 기본 Choices.js 스타일 사용
      item.style.backgroundColor = ''
      item.style.borderColor = ''
      item.style.color = ''
    })
  }

  // 최근 제출 내역 불러오기
  async loadRecentSubmission(expenseCodeId) {
    console.log("=== loadRecentSubmission 시작 ===")
    console.log("expenseCodeId:", expenseCodeId)
    
    if (!expenseCodeId) {
      console.error("expenseCodeId가 없습니다")
      return
    }
    
    // 데이터 로딩 시작 플래그 설정
    this.isLoadingData = true
    console.log("데이터 로딩 시작, 검증 차단")
    // 이벤트 발생
    document.dispatchEvent(new CustomEvent('expense-item:loading-start'))
    
    try {
      // window.expenseCodesData에서 데이터 가져오기 (API 호출 없이)
      const expenseCodesData = window.expenseCodesData || {}
      const codeData = expenseCodesData[expenseCodeId]
      
      console.log("경비 코드 데이터:", codeData)
      
      if (!codeData || !codeData.recent_submission) {
        console.log("최근 사용 내역이 없습니다")
        // 데이터 로딩 완료 처리
        this.isLoadingData = false
        document.dispatchEvent(new CustomEvent('expense-item:loading-complete'))
        
        // 검증 실행 (데이터가 없어도 검증은 실행되어야 함)
        setTimeout(() => {
          this.triggerValidation()
        }, 50)
        return
      }
      
      const data = codeData.recent_submission
      console.log("적용할 데이터:", data)
      
      // 데이터가 있을 때만 폼 채우기 실행
      if (data) {
        // 코스트 센터 자동 선택
        if (data.cost_center_id && this.hasCostCenterTarget) {
          const costCenterSelect = this.costCenterTarget
          const valueToSet = data.cost_center_id.toString()
          
          console.log("=== Setting cost center ===")
          console.log("Target value:", valueToSet)
          console.log("Current options in DOM:", Array.from(costCenterSelect.options).map(opt => ({
            value: opt.value,
            text: opt.textContent,
            selected: opt.selected
          })))
          
          // DOM에 값 설정
          costCenterSelect.value = valueToSet
          
          // Choice.js 인스턴스가 있는 경우
          if (costCenterSelect._choices) {
            console.log("Choice.js instance found, updating...")
            
            // Choice.js의 선택 업데이트
            try {
              // 먼저 기존 선택 제거
              costCenterSelect._choices.removeActiveItems()
              // 새 값 설정
              costCenterSelect._choices.setChoiceByValue(valueToSet)
              console.log("Choice.js updated successfully")
            } catch (e) {
              console.error("Failed to update Choice.js:", e)
              // 실패시 Choice.js 재초기화
              costCenterSelect._choices.destroy()
              costCenterSelect.removeAttribute('data-choices-initialized')
              setTimeout(() => {
                this.initializeCostCenter()
              }, 50)
            }
          }
          
          // change 이벤트 발생
          setTimeout(() => {
            const event = new Event('change', { bubbles: true })
            costCenterSelect.dispatchEvent(event)
            console.log("Final cost center value:", costCenterSelect.value)
          }, 100)
        } else {
          console.log("Cost center not set - missing data or target", {
            hasCostCenterId: !!data.cost_center_id,
            hasCostCenterTarget: this.hasCostCenterTarget
          })
        }
        
        // 결재선 자동 선택
        if (data.approval_line_id) {
          console.log("Setting approval line to:", data.approval_line_id)
          
          // 결재선은 radio button으로 구현되어 있음
          const approvalLineRadio = document.querySelector(`input[type="radio"][name="expense_item[approval_line_id]"][value="${data.approval_line_id}"]`)
          if (approvalLineRadio) {
            console.log("Found approval line radio button:", approvalLineRadio)
            
            // 라디오 버튼 선택
            approvalLineRadio.checked = true
            
            // 변경 이벤트 트리거하여 UI 업데이트
            const event = new Event('change', { bubbles: true })
            approvalLineRadio.dispatchEvent(event)
            
            // expense-item-approval 컨트롤러의 메서드 호출
            const approvalController = document.querySelector('[data-controller="expense-item-approval"]')
            if (approvalController) {
              const controller = this.application.getControllerForElementAndIdentifier(
                approvalController, 
                'expense-item-approval'
              )
              if (controller && controller.selectApprovalLine) {
                // selectApprovalLine 메서드 직접 호출
                const fakeEvent = { 
                  currentTarget: approvalLineRadio,
                  target: approvalLineRadio 
                }
                controller.selectApprovalLine(fakeEvent)
              }
            }
          } else {
            console.log("Approval line radio button not found for ID:", data.approval_line_id)
          }
        } else if (data.approval_line_id === null) {
          // 결재선이 없는 경우 "결재 없음" 선택
          console.log("Setting approval line to: 결재 없음")
          const noApprovalRadio = document.querySelector('input[type="radio"][name="expense_item[approval_line_id]"][value=""]')
          if (noApprovalRadio) {
            noApprovalRadio.checked = true
            const event = new Event('change', { bubbles: true })
            noApprovalRadio.dispatchEvent(event)
          }
        }
        
        // 커스텀 필드 자동 입력 - 즉시 실행
        if (data.custom_fields && Object.keys(data.custom_fields).length > 0) {
          // DOM이 이미 준비되어 있는지 확인
          const customFieldsContainer = this.customFieldsTarget
          if (customFieldsContainer && customFieldsContainer.querySelector('[data-field-name]')) {
            // DOM이 준비되어 있으면 즉시 실행
            console.log('커스텀 필드 DOM 이미 준비됨, 즉시 채우기')
            this.fillCustomFields(data.custom_fields)
          } else {
            // DOM이 아직 준비되지 않았으면 짧은 대기 후 실행
            console.log('커스텀 필드 DOM 대기 중...')
            let filled = false
            
            // MutationObserver로 DOM 변경 감지
            const observer = new MutationObserver((mutations, obs) => {
              if (customFieldsContainer && customFieldsContainer.querySelector('[data-field-name]')) {
                obs.disconnect()
                if (!filled) {
                  filled = true
                  console.log('MutationObserver: 커스텀 필드 DOM 준비 완료, 즉시 채우기')
                  this.fillCustomFields(data.custom_fields)
                }
              }
            })
            
            observer.observe(this.customFieldsTarget, { childList: true, subtree: true })
            
            // 타임아웃 폴백 (최대 100ms 대기)
            setTimeout(() => {
              observer.disconnect()
              if (!filled) {
                filled = true
                console.log('Timeout 폴백: fillCustomFields 호출')
                this.fillCustomFields(data.custom_fields)
              }
            }, 100) // 500ms -> 100ms로 단축
          }
        }
        
        // 비고 필드 자동 입력  
        if (data.remarks) {
          const remarksField = document.querySelector('textarea[name="expense_item[remarks]"]')
          if (remarksField) {
            console.log("기존 비고 필드 값 설정:", data.remarks)
            remarksField.value = data.remarks
          }
        }
        
        // 사용자에게 알림 (경비 코드 이름 포함)
        const selectedOption = this.expenseCodeTarget.options[this.expenseCodeTarget.selectedIndex]
        if (selectedOption) {
          const expenseCodeName = selectedOption.text.split(' - ')[0]
          this.showNotificationWithClearButton(`${expenseCodeName} 코드의 최근 작성 내역을 불러왔습니다.`)
        }
        
        // 최종 검증 실행 (짧은 지연 후)
        setTimeout(() => {
          console.log("=== 최종 검증 시작 ===")
          
          // 데이터 로딩 완료 플래그 설정
          this.isLoadingData = false
          console.log("데이터 로딩 완료, 검증 허용 (isLoadingData = false)")
          // 이벤트 발생
          document.dispatchEvent(new CustomEvent('expense-item:loading-complete'))
          
          // 검증 실행
          console.log("triggerValidation 호출...")
          this.triggerValidation()
        }, 50) // 모든 대기 시간을 50ms로 통합
      } else {
        console.log("최근 제출 내역이 없습니다")
        // 데이터가 없어도 로딩 완료 처리
        setTimeout(() => {
          this.isLoadingData = false
          console.log("데이터 없음, 검증 허용")
          document.dispatchEvent(new CustomEvent('expense-item:loading-complete'))
        }, 100)
      }
    } catch (error) {
      console.error('최근 제출 내역 불러오기 실패:', error)
      // 에러 발생 시에도 로딩 완료 처리
      this.isLoadingData = false
      console.log("로딩 실패, 검증 허용")
      document.dispatchEvent(new CustomEvent('expense-item:loading-complete'))
      
      // 검증 실행
      setTimeout(() => {
        this.triggerValidation()
      }, 50)
    }
  }
  
  // 알림 표시 함수 (새로 작성 버튼 포함)
  showNotificationWithClearButton(message) {
    console.log("알림 표시:", message)
    
    // 기존 알림 제거
    const existingNotification = document.querySelector('.expense-autofill-notification')
    if (existingNotification) {
      existingNotification.remove()
    }
    
    // 새 알림 생성
    const notification = document.createElement('div')
    notification.className = 'expense-autofill-notification mt-2 mb-4 p-3 bg-green-50 border border-green-200 rounded-lg'
    notification.innerHTML = `
      <div class="flex items-center justify-between gap-3">
        <div class="flex items-center">
          <svg class="h-4 w-4 text-green-600 mr-2 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
          <span class="text-sm text-green-800">${message}</span>
        </div>
        <button type="button" class="clear-form-btn bg-white hover:bg-gray-50 text-green-700 text-sm font-medium py-1 px-3 border border-green-300 rounded-md transition-colors">
          새로 작성
        </button>
      </div>
    `
    
    // 경비 코드 안내문(expense_code_guide) 바로 다음에 삽입
    const expenseCodeGuide = document.getElementById('expense_code_guide')
    if (expenseCodeGuide && expenseCodeGuide.parentNode) {
      expenseCodeGuide.parentNode.insertBefore(notification, expenseCodeGuide.nextSibling)
    } else {
      // 안내문이 없으면 폼 상단에 삽입
      const form = this.element
      const firstChild = form.firstElementChild
      if (firstChild) {
        form.insertBefore(notification, firstChild)
      } else {
        form.appendChild(notification)
      }
    }
    
    // 새로 작성 버튼 클릭 이벤트
    const clearButton = notification.querySelector('.clear-form-btn')
    clearButton.addEventListener('click', () => {
      this.clearLoadedData()
      notification.remove()
    })
    
    // 자동 제거는 하지 않음 (사용자가 직접 버튼을 클릭하거나 무시)
  }
  
  // 불러온 데이터 초기화
  clearLoadedData() {
    console.log("불러온 데이터 초기화")
    
    // 코스트 센터 초기화
    if (this.hasCostCenterTarget) {
      const costCenterSelect = this.costCenterTarget
      if (costCenterSelect._choices) {
        costCenterSelect._choices.removeActiveItems()
      } else {
        costCenterSelect.value = ''
      }
    }
    
    // 결재선 초기화 (결재 없음 선택)
    const noApprovalRadio = document.querySelector('input[type="radio"][name="expense_item[approval_line_id]"][value=""]')
    if (noApprovalRadio) {
      noApprovalRadio.checked = true
      const event = new Event('change', { bubbles: true })
      noApprovalRadio.dispatchEvent(event)
    }
    
    // 커스텀 필드 초기화
    const customFields = this.customFieldsTarget.querySelectorAll('input, select, textarea')
    customFields.forEach(field => {
      if (field.type === 'select-multiple' && field._choices) {
        field._choices.removeActiveItems()
      } else if (field.type === 'checkbox' || field.type === 'radio') {
        field.checked = false
      } else {
        field.value = ''
      }
    })
    
    // 비고 필드 초기화
    const remarksField = document.querySelector('textarea[name="expense_item[remarks]"]')
    if (remarksField) {
      remarksField.value = ''
    }
    
    // 검증 재실행
    this.triggerValidation()
  }
  
  // 검증 트리거
  triggerValidation() {
    // 데이터 로딩 중이면 검증 건너뛰기
    if (this.isLoadingData) {
      console.log("데이터 로딩 중, 검증 건너뛰기")
      return
    }
    
    console.log("검증 트리거 실행")
    
    // client-validation 컨트롤러 찾기
    const form = this.element
    const controller = this.application.getControllerForElementAndIdentifier(
      form, 
      'client-validation'
    )
    if (controller && controller.validateAll) {
      console.log("client-validation 컨트롤러의 validateAll 호출")
      controller.validateAll()
    }
  }
  
  // 알림 표시 함수 (기본 - 자동 사라짐)
  showNotification(message) {
    console.log("알림 표시:", message)
    
    // 기존 알림 제거
    const existingNotification = document.querySelector('.expense-autofill-notification')
    if (existingNotification) {
      existingNotification.remove()
    }
    
    // 새 알림 생성
    const notification = document.createElement('div')
    notification.className = 'expense-autofill-notification fixed top-4 right-4 bg-green-100 border border-green-400 text-green-700 px-4 py-3 rounded z-50'
    notification.innerHTML = `
      <div class="flex items-center">
        <svg class="h-5 w-5 mr-2" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd"/>
        </svg>
        <span>${message}</span>
      </div>
    `
    document.body.appendChild(notification)
    
    // 3초 후 자동 제거
    setTimeout(() => {
      notification.style.transition = 'opacity 0.5s'
      notification.style.opacity = '0'
      setTimeout(() => notification.remove(), 500)
    }, 3000)
  }

  // 커스텀 필드 채우기
  fillCustomFields(customFields) {
    console.log("=== fillCustomFields 시작 ===")
    console.log("Filling custom fields:", customFields)
    console.log("데이터 로딩 상태:", this.isLoadingData)
    
    // setTimeout 제거하고 즉시 실행
    const fillFieldsNow = () => {
      console.log("=== fillCustomFields 실행 시작 ===")
      console.log("현재 데이터 로딩 상태:", this.isLoadingData)
      
      // DOM 순서대로 필드를 찾아서 처리 (data-field-order 순서대로)
      const fieldContainers = Array.from(this.customFieldsTarget.querySelectorAll('[data-field-name]'))
      
      console.log("발견된 필드 컨테이너 수:", fieldContainers.length)
      
      // data-field-order 속성으로 정렬
      fieldContainers.sort((a, b) => {
        const orderA = parseInt(a.dataset.fieldOrder) || 999
        const orderB = parseInt(b.dataset.fieldOrder) || 999
        return orderA - orderB
      })
      
      console.log("Processing fields in order:", fieldContainers.map(c => `${c.dataset.fieldName}(order:${c.dataset.fieldOrder})`).join(' -> '))
      
      let filledFields = []
      
      // 정렬된 순서대로 필드 처리
      fieldContainers.forEach(container => {
        const fieldKey = container.dataset.fieldName
        const fieldValue = customFields[fieldKey]
        
        if (!fieldValue) {
          console.log(`${fieldKey} - 값 없음, 건너뜀`)
          return
        }
        
        // 필드 찾기
        const field = container.querySelector(`[name="expense_item[custom_fields][${fieldKey}]"], [name="expense_item[custom_fields][${fieldKey}][]"]`)
        
        if (field) {
          console.log(`Found field for ${fieldKey}:`, field.tagName, field.type, "Multiple:", field.multiple)
          console.log(`Field has data-choices-initialized:`, field.hasAttribute('data-choices-initialized'))
          console.log(`Field._choices:`, field._choices)
          
          if (field.multiple) {
            // 멀티셀렉트 필드 (참석자 등)
            const values = Array.isArray(fieldValue) ? fieldValue : fieldValue.toString().split(', ').map(v => v.trim())
            console.log(`Setting multiple values for ${fieldKey}:`, values)
            
            // Choice.js 인스턴스 확인
            if (field._choices) {
              const choicesInstance = field._choices
              console.log(`Using Choice.js instance for ${fieldKey}`)
              
              // 기존 선택 초기화
              choicesInstance.removeActiveItems()
              
              // 새 값들 설정 - setChoiceByValue를 각 값에 대해 호출
              values.forEach(value => {
                console.log(`Setting choice value: ${value}`)
                // 숫자든 문자열이든 상관없이 처리
                choicesInstance.setChoiceByValue(value.toString())
              })
              filledFields.push(`${fieldKey}=${values.join(',')}`);
            } else if (field.hasAttribute('data-choices-initialized')) {
              // Choice.js가 초기화되었지만 인스턴스가 없는 경우
              console.log(`Field is initialized but no instance found for ${fieldKey}`)
              // DOM 업데이트 후 다시 시도
              setTimeout(() => {
                if (field._choices) {
                  field._choices.removeActiveItems()
                  values.forEach(value => {
                    field._choices.setChoiceByValue(value.toString())
                  })
                  console.log(`${fieldKey} - 재시도 성공`)
                }
              }, 100)
            } else {
              // 일반 멀티셀렉트
              console.log(`Using regular multiselect for ${fieldKey}`)
              Array.from(field.options).forEach(option => {
                option.selected = values.includes(option.value)
              })
              filledFields.push(`${fieldKey}=${values.join(',')}`);
            }
          } else {
            // 일반 필드 (사유 등)
            console.log(`설정 전 ${fieldKey} 값:`, field.value)
            field.value = fieldValue
            console.log(`설정 후 ${fieldKey} 값:`, field.value)
            filledFields.push(`${fieldKey}=${fieldValue}`);
            
            // 값이 설정되면 input 이벤트 발생 - 로딩 중이면 건너뛰기
            if (!this.isLoadingData) {
              console.log(`${fieldKey}에 input 이벤트 발생 (로딩 상태: ${this.isLoadingData})`)
              const inputEvent = new Event('input', { bubbles: true })
              field.dispatchEvent(inputEvent)
            } else {
              console.log(`${fieldKey}에 input 이벤트 건너뜀 (로딩 중)`)
            }
          }
        } else {
          console.log(`Field not found for ${fieldKey}`)
        }
      })
      
      console.log("=== 채워진 필드 요약 ===")
      console.log(filledFields.join(', '))
      console.log("=== fillCustomFields 실행 종료 ===")
      console.log("최종 데이터 로딩 상태:", this.isLoadingData)
    }
    
    // 즉시 실행
    fillFieldsNow()
  }

  // 알림 표시
  showNotification(message) {
    // 기존 알림 제거
    const existingNotification = document.querySelector('.auto-fill-notification')
    if (existingNotification) {
      existingNotification.remove()
    }
    
    // 추가 필드 컨테이너 찾기
    const customFieldsContainer = this.customFieldsTarget
    if (!customFieldsContainer) {
      console.log('Custom fields container not found')
      return
    }
    
    // 새 알림 생성
    const notification = document.createElement('div')
    notification.className = 'auto-fill-notification mt-3 mb-3 p-3 bg-green-50 border border-green-200 rounded-lg transition-opacity duration-300'
    notification.innerHTML = `
      <div class="flex items-center gap-2">
        <svg class="h-5 w-5 text-green-600 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
        </svg>
        <span class="text-sm text-green-800">${message}</span>
      </div>
    `
    
    // 경비 코드 안내문구와 추가 필드 사이에 삽입
    const expenseCodeGuide = document.getElementById('expense_code_guide')
    const firstFieldContainer = customFieldsContainer.querySelector('.mt-4.p-4.bg-gray-50.rounded-lg')
    
    if (expenseCodeGuide && firstFieldContainer && expenseCodeGuide.parentNode === customFieldsContainer) {
      // 경비 코드 안내문구와 첫 번째 필드 컨테이너 사이에 삽입
      customFieldsContainer.insertBefore(notification, firstFieldContainer)
    } else if (firstFieldContainer) {
      // 추가 필드 컨테이너 바로 앞에 삽입
      customFieldsContainer.insertBefore(notification, firstFieldContainer)
    } else {
      // 폴백: customFieldsContainer의 첫 번째 자식으로 삽입
      customFieldsContainer.prepend(notification)
    }
    
    // 3초 후 제거
    setTimeout(() => {
      notification.style.opacity = '0'
      setTimeout(() => notification.remove(), 300)
    }, 3000)
  }

}