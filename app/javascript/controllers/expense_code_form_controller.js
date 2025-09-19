import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["requiredFields", "limitAmountField", "noLimitCheckbox", "fieldRow", "viewMode", "editMode", "preview", "previewFields"]
  
  connect() {
    console.log("ExpenseCodeForm controller connected")
    window.expenseCodeFormController = this // 디버깅용
    // 폼 제출 시 데이터 준비
    this.element.addEventListener('submit', this.prepareFormData.bind(this))
    
    // 폼 중복 제출 방지
    this.isSubmitting = false
    
    // 초기 상태 설정
    if (this.hasNoLimitCheckboxTarget && this.hasLimitAmountFieldTarget) {
      this.updateLimitAmountState()
      // 원래 값 저장 (체크박스 해제 시 복원용)
      this.originalLimitAmount = this.limitAmountFieldTarget.value || ''
      
      // 한도 금액 필드 값 변경 감지
      this.limitAmountFieldTarget.addEventListener('input', (event) => {
        if (!this.noLimitCheckboxTarget.checked) {
          this.originalLimitAmount = event.target.value
        }
      })
    }
    
    // 드래그 앤 드롭 초기화
    this.initializeDragAndDrop()
    
    // 이벤트 위임 설정
    this.setupEventDelegation()
    
    // 기존 필드 초기화 (선택지 타입인 경우 옵션 UI 표시)
    this.initializeExistingFields()
    
    // 초기 미리보기 업데이트
    this.updatePreview()
  }
  
  toggleLimitAmount(event) {
    // 체크박스 해제 시 이전 값 복원을 위한 처리
    if (!event.target.checked && this.originalLimitAmount) {
      this.limitAmountFieldTarget.value = this.originalLimitAmount
    }
    this.updateLimitAmountState()
  }
  
  updateLimitAmountState() {
    const isNoLimit = this.noLimitCheckboxTarget.checked
    this.limitAmountFieldTarget.disabled = isNoLimit
    
    if (isNoLimit) {
      // 현재 값을 저장하고 필드 비우기
      if (this.limitAmountFieldTarget.value) {
        this.originalLimitAmount = this.limitAmountFieldTarget.value
      }
      this.limitAmountFieldTarget.value = ''
      this.limitAmountFieldTarget.classList.add('bg-gray-100', 'cursor-not-allowed')
    } else {
      this.limitAmountFieldTarget.classList.remove('bg-gray-100', 'cursor-not-allowed')
      // 체크박스 해제 시 포커스 이동 (값이 있을 때만)
      if (this.limitAmountFieldTarget.value) {
        this.limitAmountFieldTarget.focus()
      }
    }
  }
  
  generateFieldKey() {
    // 타임스탬프와 랜덤 문자열로 고유한 키 생성
    const timestamp = Date.now()
    const random = Math.random().toString(36).substr(2, 5)
    return `field_${timestamp}_${random}`
  }
  
  addField(event) {
    console.log("addField called")
    event.preventDefault()
    
    const fieldKey = this.generateFieldKey()
    const fieldRow = this.createFieldRow(fieldKey, {
      label: '',
      type: 'text',
      required: true
    })
    
    this.requiredFieldsTarget.appendChild(fieldRow)
    
    // 새로 추가된 필드에도 드래그 이벤트 설정
    this.setupFieldRowDragEvents(fieldRow)
    
    // 화살표 버튼 상태 업데이트
    this.updateFieldOrder()
    
    // 미리보기 업데이트
    this.updatePreview()
    
    // 새로 추가된 필드의 이름 입력란에 포커스
    const labelInput = fieldRow.querySelector('[data-field-label]')
    if (labelInput) {
      labelInput.focus()
    }
    
    // 이벤트 리스너는 이벤트 위임으로 처리되므로 개별적으로 추가하지 않음
  }
  
  setupFieldRowDragEvents(row) {
    row.draggable = true
    row.style.cursor = 'move'
    
    // 데스크톱 드래그 이벤트
    row.addEventListener('dragstart', this.handleDragStart.bind(this))
    row.addEventListener('dragend', this.handleDragEnd.bind(this))
    row.addEventListener('dragover', this.handleDragOver.bind(this))
    row.addEventListener('drop', this.handleDrop.bind(this))
    row.addEventListener('dragenter', this.handleDragEnter.bind(this))
    row.addEventListener('dragleave', this.handleDragLeave.bind(this))
    
    // 터치 이벤트 지원
    row.addEventListener('touchstart', this.handleTouchStart.bind(this), { passive: false })
    row.addEventListener('touchmove', this.handleTouchMove.bind(this), { passive: false })
    row.addEventListener('touchend', this.handleTouchEnd.bind(this))
  }
  
  removeField(event) {
    event.preventDefault()
    const fieldRow = event.target.closest('.field-row')
    
    // 필드 이름 가져오기
    const labelInput = fieldRow.querySelector('[data-field-label]')
    const fieldLabel = labelInput ? labelInput.value.trim() : ''
    
    // 확인 메시지
    const confirmMessage = fieldLabel 
      ? `'${fieldLabel}' 필드를 삭제하시겠습니까?\n\n이미 입력된 데이터가 있는 경우 해당 데이터도 함께 삭제됩니다.`
      : '이 필드를 삭제하시겠습니까?'
    
    if (confirm(confirmMessage)) {
      fieldRow.remove()
      
      // 필드 제거 후 순서 업데이트
      this.updateFieldOrder()
      
      // 미리보기 업데이트
      this.updatePreview()
      
      // 삭제 완료 메시지 (선택사항)
      this.showNotification(`필드가 삭제되었습니다.`)
    }
  }
  
  handleTypeChange(event) {
    console.log('handleTypeChange called')
    const typeSelect = event.target
    console.log('Type select value:', typeSelect.value)
    console.log('Type select element:', typeSelect)
    
    const fieldRow = typeSelect.closest('.field-row')
    console.log('Field row found:', fieldRow)
    
    const editMode = fieldRow.querySelector('.edit-mode')
    console.log('Edit mode element:', editMode)
    
    // 기존 선택지 입력 UI 제거
    const existingOptionsInput = fieldRow.querySelector('.options-input')
    if (existingOptionsInput) {
      console.log('Removing existing options input')
      existingOptionsInput.remove()
    }
    
    // 선택지 타입인 경우 옵션 입력 UI 추가
    console.log('Checking if type is select:', typeSelect.value === 'select')
    if (typeSelect.value === 'select') {
      console.log('Creating options UI')
      const optionsDiv = document.createElement('div')
      optionsDiv.className = 'options-input mt-2 p-3 bg-gray-50 rounded'
      
      // 기존 옵션 값 가져오기 (있다면)
      const fieldKey = fieldRow.dataset.fieldKey
      const existingOptions = fieldRow.dataset.options ? JSON.parse(fieldRow.dataset.options) : ['옵션1', '옵션2', '옵션3']
      
      optionsDiv.innerHTML = `
        <label class="block text-sm font-medium text-gray-700 mb-2">선택지 목록 (쉼표로 구분)</label>
        <input type="text" 
               value="${existingOptions.join(', ')}" 
               placeholder="예: 승인, 반려, 보류"
               class="w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
               data-field-options>
        <p class="mt-1 text-xs text-gray-500">각 선택지를 쉼표(,)로 구분하여 입력하세요.</p>
      `
      
      editMode.appendChild(optionsDiv)
      
      // 옵션 입력 시 미리보기 업데이트
      const optionsInput = optionsDiv.querySelector('[data-field-options]')
      optionsInput.addEventListener('input', () => this.updatePreview())
    }
  }
  
  setupEventDelegation() {
    // 이벤트 위임을 사용하여 동적으로 추가되는 요소도 처리
    if (this.hasRequiredFieldsTarget) {
      // 타입 변경 이벤트
      this.requiredFieldsTarget.addEventListener('change', (event) => {
        if (event.target.matches('[data-field-type]')) {
          console.log('Type select changed via delegation:', event.target.value)
          this.handleTypeChange(event)
          this.updatePreview()
        }
        // 필수 체크박스 변경 이벤트
        else if (event.target.matches('[data-field-required]')) {
          this.updatePreview()
        }
      })
      
      // 라벨 입력 이벤트
      this.requiredFieldsTarget.addEventListener('input', (event) => {
        if (event.target.matches('[data-field-label]')) {
          this.updatePreview()
        }
        // 옵션 입력 이벤트
        else if (event.target.matches('[data-field-options]')) {
          this.updatePreview()
        }
      })
    }
  }

  initializeExistingFields() {
    // 기존 필드들에 대해 선택지 타입인 경우 편집 모드에서 옵션 UI 표시
    const fieldRows = this.requiredFieldsTarget.querySelectorAll('.field-row[data-saved="true"]')
    fieldRows.forEach(row => {
      const typeSelect = row.querySelector('[data-field-type]')
      if (typeSelect && typeSelect.value === 'select') {
        const editMode = row.querySelector('.edit-mode')
        if (editMode && !editMode.classList.contains('hidden')) {
          const fakeEvent = { target: typeSelect }
          this.handleTypeChange(fakeEvent)
        }
      }
    })
  }
  
  showNotification(message, type = 'info', duration = 3000) {
    // 기존 알림 제거
    const existingNotification = document.querySelector('.field-notification')
    if (existingNotification) {
      existingNotification.remove()
    }
    
    // 새 알림 생성
    const notification = document.createElement('div')
    notification.className = `field-notification fixed bottom-4 right-4 px-6 py-4 rounded-lg shadow-xl transition-opacity duration-300 max-w-md ${
      type === 'success' ? 'bg-green-500 text-white' : 
      type === 'error' ? 'bg-red-500 text-white' : 
      type === 'info' ? 'bg-blue-500 text-white' :
      'bg-gray-700 text-white'
    }`
    
    // 멀티라인 메시지 처리
    const lines = message.split('\n')
    if (lines.length > 1) {
      notification.innerHTML = lines.map((line, index) => 
        index === 0 ? `<div class="font-semibold mb-2">${line}</div>` : `<div class="text-sm">• ${line}</div>`
      ).join('')
    } else {
      notification.textContent = message
    }
    
    document.body.appendChild(notification)
    
    // duration 후 제거
    setTimeout(() => {
      notification.style.opacity = '0'
      setTimeout(() => notification.remove(), 300)
    }, duration)
  }
  
  toggleEditMode(event) {
    event.preventDefault()
    const fieldRow = event.target.closest('.field-row')
    const viewMode = fieldRow.querySelector('.view-mode')
    const editMode = fieldRow.querySelector('.edit-mode')
    const editBtn = fieldRow.querySelector('.edit-btn')
    const saveBtn = fieldRow.querySelector('.save-btn')
    const cancelBtn = fieldRow.querySelector('.cancel-btn')
    const deleteBtn = fieldRow.querySelector('.delete-btn')
    
    // 편집 모드로 전환
    viewMode.classList.add('hidden')
    editMode.classList.remove('hidden')
    editBtn.classList.add('hidden')
    deleteBtn.classList.add('hidden')
    saveBtn.classList.remove('hidden')
    cancelBtn.classList.remove('hidden')
    
    // 선택지 타입인 경우 옵션 UI 표시
    const typeSelect = editMode.querySelector('[data-field-type]')
    if (typeSelect && typeSelect.value === 'select') {
      console.log('Field is select type, showing options UI')
      const fakeEvent = { target: typeSelect }
      this.handleTypeChange(fakeEvent)
    }
    
    // 첫 번째 입력 필드에 포커스
    const firstInput = editMode.querySelector('input[type="text"]')
    if (firstInput) firstInput.focus()
  }
  
  checkTypeChangeWarning(fieldRow, oldType, newType) {
    // 타입이 변경되었고, 이미 저장된 필드인 경우 경고
    if (oldType !== newType && fieldRow.dataset.saved === 'true') {
      const warningMessage = `필드 타입을 '${this.getTypeLabel(oldType)}'에서 '${this.getTypeLabel(newType)}'로 변경하시겠습니까?\n\n이미 입력된 데이터가 있는 경우 데이터 형식이 맞지 않을 수 있습니다.`
      return confirm(warningMessage)
    }
    return true
  }
  
  getTypeLabel(type) {
    const labels = {
      'text': '텍스트',
      'number': '숫자',
      'participants': '구성원',
      'organization': '조직',
      'select': '선택지'
    }
    return labels[type] || type
  }
  
  saveField(event) {
    event.preventDefault()
    console.log('saveField called')
    const fieldRow = event.target.closest('.field-row')
    const viewMode = fieldRow.querySelector('.view-mode')
    const editMode = fieldRow.querySelector('.edit-mode')
    const editBtn = fieldRow.querySelector('.edit-btn')
    const saveBtn = fieldRow.querySelector('.save-btn')
    const cancelBtn = fieldRow.querySelector('.cancel-btn')
    const deleteBtn = fieldRow.querySelector('.delete-btn')
    
    // 편집된 값 가져오기
    const labelInput = editMode.querySelector('[data-field-label]')
    const typeSelect = editMode.querySelector('[data-field-type]')
    const requiredCheckbox = editMode.querySelector('[data-field-required]')
    
    console.log('Field values:', {
      label: labelInput.value,
      type: typeSelect.value,
      required: requiredCheckbox.checked
    })
    
    // 기존 타입 확인
    const typeSpan = viewMode.querySelector('span.bg-blue-100')
    const oldType = typeSpan ? typeSpan.dataset.fieldType : typeSelect.value
    const newType = typeSelect.value
    
    // 타입 변경 경고
    if (!this.checkTypeChangeWarning(fieldRow, oldType, newType)) {
      return // 사용자가 취소한 경우
    }
    
    // 기존 레이블 가져오기
    const labelSpan = viewMode.querySelector('span.font-medium')
    const oldLabel = labelSpan?.textContent?.trim()
    const newLabel = labelInput.value.trim()
    
    // 레이블이 변경되었는지 확인
    if (oldLabel && oldLabel !== newLabel) {
      // 설명 템플릿과 한도 필드 확인
      const templateField = document.querySelector('[name="expense_code[description_template]"]')
      const limitField = this.limitAmountFieldTarget
      
      let updates = []
      
      // 템플릿 자동 업데이트
      if (templateField?.value?.includes(`#${oldLabel}`)) {
        const oldTemplate = templateField.value
        templateField.value = templateField.value.replace(new RegExp(`#${oldLabel}`, 'g'), `#${newLabel}`)
        updates.push(`설명 템플릿: "${oldTemplate}" → "${templateField.value}"`)
      }
      
      // 한도 수식 자동 업데이트
      if (limitField?.value?.includes(`#${oldLabel}`)) {
        const oldLimit = limitField.value
        limitField.value = limitField.value.replace(new RegExp(`#${oldLabel}`, 'g'), `#${newLabel}`)
        updates.push(`한도 수식: "${oldLimit}" → "${limitField.value}"`)
      }
      
      // 업데이트 내역이 있으면 알림 표시
      if (updates.length > 0) {
        this.showNotification('필드 이름 변경이 관련 항목에 반영되었습니다.', 'info', 3000)
      }
    }
    
    // 읽기 모드 업데이트
    const requiredSpan = viewMode.querySelector('span.bg-red-100, span.bg-gray-100')
    
    if (labelSpan) labelSpan.textContent = newLabel
    if (typeSpan) {
      // 아이콘과 텍스트 업데이트
      const fieldTypes = {
        'text': '텍스트',
        'number': '숫자',
        'participants': '구성원',
        'organization': '조직',
        'select': '선택지'
      }
      const fieldIcons = {
        'text': '<svg class="h-3 w-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" /></svg>',
        'number': '<svg class="h-3 w-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 20l4-16m2 16l4-16M6 9h14M4 15h14" /></svg>',
        'participants': '<svg class="h-3 w-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" /></svg>',
        'organization': '<svg class="h-3 w-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" /></svg>',
        'select': '<svg class="h-3 w-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-6 9l2 2 4-4" /></svg>'
      }
      typeSpan.innerHTML = `${fieldIcons[newType] || ''} ${fieldTypes[newType] || newType}`
      typeSpan.dataset.fieldType = newType // 타입 정보 저장
    }
    if (requiredSpan) {
      if (requiredCheckbox.checked) {
        requiredSpan.className = 'px-2 py-1 text-xs font-medium rounded-full bg-red-100 text-red-800'
        requiredSpan.textContent = '필수'
      } else {
        requiredSpan.className = 'px-2 py-1 text-xs font-medium rounded-full bg-gray-100 text-gray-800'
        requiredSpan.textContent = '선택'
      }
    }
    
    // 선택지 타입인 경우 옵션 저장
    if (newType === 'select') {
      const optionsInput = editMode.querySelector('[data-field-options]')
      console.log('Looking for options input:', optionsInput)
      if (optionsInput) {
        const optionsText = optionsInput.value.trim()
        const options = optionsText.split(',').map(opt => opt.trim()).filter(opt => opt)
        console.log('Saving options:', options)
        fieldRow.dataset.options = JSON.stringify(options)
      } else {
        console.log('No options input found for select type')
      }
    } else {
      // 선택지가 아닌 경우 옵션 데이터 제거
      delete fieldRow.dataset.options
    }
    
    // 필드가 저장되었음을 표시
    fieldRow.dataset.saved = 'true'
    
    // 현재 필드의 인덱스(순서) 저장
    const allFieldRows = this.requiredFieldsTarget.querySelectorAll('.field-row')
    const currentIndex = Array.from(allFieldRows).indexOf(fieldRow)
    fieldRow.dataset.order = currentIndex
    
    // 읽기 모드로 복귀
    viewMode.classList.remove('hidden')
    editMode.classList.add('hidden')
    editBtn.classList.remove('hidden')
    deleteBtn.classList.remove('hidden')
    saveBtn.classList.add('hidden')
    cancelBtn.classList.add('hidden')
    
    // 옵션 입력 UI 숨기기
    const optionsDiv = fieldRow.querySelector('.options-input')
    if (optionsDiv) {
      optionsDiv.remove()
    }
    
    // 미리보기 업데이트
    this.updatePreview()
  }
  
  cancelEdit(event) {
    event.preventDefault()
    const fieldRow = event.target.closest('.field-row')
    const viewMode = fieldRow.querySelector('.view-mode')
    const editMode = fieldRow.querySelector('.edit-mode')
    const editBtn = fieldRow.querySelector('.edit-btn')
    const saveBtn = fieldRow.querySelector('.save-btn')
    const cancelBtn = fieldRow.querySelector('.cancel-btn')
    const deleteBtn = fieldRow.querySelector('.delete-btn')
    
    // 원래 값으로 복원 (아무것도 하지 않음)
    
    // 읽기 모드로 복귀
    viewMode.classList.remove('hidden')
    editMode.classList.add('hidden')
    editBtn.classList.remove('hidden')
    deleteBtn.classList.remove('hidden')
    saveBtn.classList.add('hidden')
    cancelBtn.classList.add('hidden')
    
    // 옵션 입력 UI 숨기기
    const optionsDiv = fieldRow.querySelector('.options-input')
    if (optionsDiv) {
      optionsDiv.remove()
    }
    
    // 미리보기 업데이트
    this.updatePreview()
  }
  
  createFieldRow(fieldKey, fieldConfig) {
    const div = document.createElement('div')
    div.className = 'field-row flex flex-col sm:flex-row items-start sm:items-center gap-2 p-2 bg-white rounded border border-gray-200'
    div.dataset.fieldKey = fieldKey
    div.dataset.expenseCodeFormTarget = 'fieldRow'
    
    const fieldTypes = {
      'text': '텍스트',
      'number': '숫자',
      'participants': '구성원',
      'organization': '조직',
      'select': '선택지'
    }
    
    const fieldIcons = {
      'text': '<svg class="h-3 w-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" /></svg>',
      'number': '<svg class="h-3 w-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M7 20l4-16m2 16l4-16M6 9h14M4 15h14" /></svg>',
      'participants': '<svg class="h-3 w-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M17 20h5v-2a3 3 0 00-5.356-1.857M17 20H7m10 0v-2c0-.656-.126-1.283-.356-1.857M7 20H2v-2a3 3 0 015.356-1.857M7 20v-2c0-.656.126-1.283.356-1.857m0 0a5.002 5.002 0 019.288 0M15 7a3 3 0 11-6 0 3 3 0 016 0zm6 3a2 2 0 11-4 0 2 2 0 014 0zM7 10a2 2 0 11-4 0 2 2 0 014 0z" /></svg>',
      'organization': '<svg class="h-3 w-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" /></svg>',
      'select': '<svg class="h-3 w-3" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 5H7a2 2 0 00-2 2v12a2 2 0 002 2h10a2 2 0 002-2V7a2 2 0 00-2-2h-2M9 5a2 2 0 002 2h2a2 2 0 002-2M9 5a2 2 0 012-2h2a2 2 0 012 2m-6 9l2 2 4-4" /></svg>'
    }
    
    div.innerHTML = `
      <!-- 읽기 모드 (숨김 - 새로 추가된 필드는 편집 모드로 시작) -->
      <div class="view-mode hidden flex-1 flex flex-wrap items-center gap-2" data-expense-code-form-target="viewMode">
        <span class="font-medium text-gray-900">${fieldConfig.label || ''}</span>
        <span class="px-2 py-1 text-xs font-medium rounded-full bg-blue-100 text-blue-800 inline-flex items-center gap-1"
              data-field-type="${fieldConfig.type}">
          ${fieldIcons[fieldConfig.type] || ''}
          ${fieldTypes[fieldConfig.type] || fieldConfig.type}
        </span>
        ${fieldConfig.required !== false ? 
          '<span class="px-2 py-1 text-xs font-medium rounded-full bg-red-100 text-red-800">필수</span>' : 
          '<span class="px-2 py-1 text-xs font-medium rounded-full bg-gray-100 text-gray-800">선택</span>'}
      </div>
      
      <!-- 편집 모드 (기본값 - 새로 추가된 필드) -->
      <div class="edit-mode flex-1 flex flex-col sm:flex-row items-stretch sm:items-center gap-2" data-expense-code-form-target="editMode">
        <input type="text" 
               value="${fieldConfig.label || ''}" 
               placeholder="필드 이름"
               class="flex-1 rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
               data-field-label>
        <select class="rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
                data-field-type>
          <option value="text" ${fieldConfig.type === 'text' ? 'selected' : ''}>텍스트</option>
          <option value="number" ${fieldConfig.type === 'number' ? 'selected' : ''}>숫자</option>
          <option value="participants" ${fieldConfig.type === 'participants' ? 'selected' : ''}>구성원</option>
          <option value="organization" ${fieldConfig.type === 'organization' ? 'selected' : ''}>조직</option>
          <option value="select" ${fieldConfig.type === 'select' ? 'selected' : ''}>선택지</option>
        </select>
        <label class="inline-flex items-center">
          <input type="checkbox" 
                 ${fieldConfig.required !== false ? 'checked' : ''}
                 class="rounded border-gray-300 text-indigo-600 shadow-sm focus:border-indigo-500 focus:ring-indigo-500"
                 data-field-required>
          <span class="ml-2 text-sm text-gray-600">필수</span>
        </label>
      </div>
      
      <!-- 액션 버튼들 -->
      <div class="action-buttons flex items-center gap-1 flex-shrink-0">
        <!-- 화살표 버튼들 -->
        <button type="button" 
                class="move-up-btn text-gray-400 hover:text-gray-600" 
                data-action="click->expense-code-form#moveFieldUp"
                title="위로 이동">
          <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 15l7-7 7 7" />
          </svg>
        </button>
        <button type="button" 
                class="move-down-btn text-gray-400 hover:text-gray-600" 
                data-action="click->expense-code-form#moveFieldDown"
                title="아래로 이동">
          <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 9l-7 7-7-7" />
          </svg>
        </button>
        
        <button type="button" 
                class="edit-btn hidden text-gray-400 hover:text-gray-600" 
                data-action="click->expense-code-form#toggleEditMode"
                title="편집">
          <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" />
          </svg>
        </button>
        <button type="button" 
                class="save-btn text-green-600 hover:text-green-800" 
                data-action="click->expense-code-form#saveField"
                title="저장">
          <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7" />
          </svg>
        </button>
        <button type="button" 
                class="cancel-btn text-gray-400 hover:text-gray-600" 
                data-action="click->expense-code-form#cancelEdit"
                title="취소">
          <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
        <button type="button" 
                class="delete-btn hidden text-red-600 hover:text-red-900" 
                data-action="click->expense-code-form#removeField"
                title="삭제">
          <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
          </svg>
        </button>
      </div>
    `
    
    return div
  }
  
  // 드래그 앤 드롭 메서드들
  initializeDragAndDrop() {
    if (!this.hasRequiredFieldsTarget) return
    
    // 드래그 가능하도록 설정
    this.updateDraggableStatus()
    
    // 초기 화살표 버튼 상태 업데이트
    this.updateFieldOrder()
  }
  
  updateDraggableStatus() {
    const fieldRows = this.requiredFieldsTarget.querySelectorAll('.field-row')
    fieldRows.forEach(row => {
      this.setupFieldRowDragEvents(row)
    })
  }
  
  handleDragStart(event) {
    const fieldRow = event.target.closest('.field-row')
    if (!fieldRow) return
    
    // 편집 모드인 경우 드래그 방지
    const editMode = fieldRow.querySelector('.edit-mode')
    if (editMode && !editMode.classList.contains('hidden')) {
      event.preventDefault()
      return
    }
    
    this.draggedElement = fieldRow
    fieldRow.classList.add('opacity-50')
    
    // 드래그 데이터 설정
    event.dataTransfer.effectAllowed = 'move'
    event.dataTransfer.setData('text/html', fieldRow.innerHTML)
  }
  
  handleDragEnd(event) {
    const fieldRow = event.target.closest('.field-row')
    if (!fieldRow) return
    
    fieldRow.classList.remove('opacity-50')
    
    // 드롭 인디케이터 제거
    const allRows = this.requiredFieldsTarget.querySelectorAll('.field-row')
    allRows.forEach(row => {
      row.classList.remove('border-t-4', 'border-indigo-500')
    })
    
    this.draggedElement = null
  }
  
  handleDragOver(event) {
    if (event.preventDefault) {
      event.preventDefault()
    }
    event.dataTransfer.dropEffect = 'move'
    return false
  }
  
  handleDragEnter(event) {
    const fieldRow = event.target.closest('.field-row')
    if (!fieldRow || fieldRow === this.draggedElement) return
    
    fieldRow.classList.add('border-t-4', 'border-indigo-500')
  }
  
  handleDragLeave(event) {
    const fieldRow = event.target.closest('.field-row')
    if (!fieldRow) return
    
    // 마우스가 자식 요소로 이동한 경우는 무시
    if (fieldRow.contains(event.relatedTarget)) return
    
    fieldRow.classList.remove('border-t-4', 'border-indigo-500')
  }
  
  handleDrop(event) {
    if (event.stopPropagation) {
      event.stopPropagation()
    }
    event.preventDefault()
    
    const dropTarget = event.target.closest('.field-row')
    if (!dropTarget || !this.draggedElement || dropTarget === this.draggedElement) return
    
    // 드롭 위치 계산
    const rect = dropTarget.getBoundingClientRect()
    const y = event.clientY - rect.top
    const height = rect.height
    
    if (y < height / 2) {
      // 위쪽에 드롭
      dropTarget.parentNode.insertBefore(this.draggedElement, dropTarget)
    } else {
      // 아래쪽에 드롭
      dropTarget.parentNode.insertBefore(this.draggedElement, dropTarget.nextSibling)
    }
    
    // 순서 업데이트
    this.updateFieldOrder()
    this.updatePreview()
    
    return false
  }
  
  updateFieldOrder() {
    const fieldRows = this.requiredFieldsTarget.querySelectorAll('.field-row')
    fieldRows.forEach((row, index) => {
      row.dataset.order = index
      // 첫 번째와 마지막 필드의 화살표 버튼 상태 업데이트
      this.updateMoveButtonsState(row, index, fieldRows.length)
    })
  }
  
  updateMoveButtonsState(row, index, total) {
    const moveUpBtn = row.querySelector('.move-up-btn')
    const moveDownBtn = row.querySelector('.move-down-btn')
    
    if (moveUpBtn) {
      if (index === 0) {
        moveUpBtn.disabled = true
        moveUpBtn.classList.add('opacity-50', 'cursor-not-allowed')
      } else {
        moveUpBtn.disabled = false
        moveUpBtn.classList.remove('opacity-50', 'cursor-not-allowed')
      }
    }
    
    if (moveDownBtn) {
      if (index === total - 1) {
        moveDownBtn.disabled = true
        moveDownBtn.classList.add('opacity-50', 'cursor-not-allowed')
      } else {
        moveDownBtn.disabled = false
        moveDownBtn.classList.remove('opacity-50', 'cursor-not-allowed')
      }
    }
  }
  
  moveFieldUp(event) {
    event.preventDefault()
    const fieldRow = event.target.closest('.field-row')
    const previousRow = fieldRow.previousElementSibling
    
    if (previousRow && previousRow.classList.contains('field-row')) {
      fieldRow.parentNode.insertBefore(fieldRow, previousRow)
      this.updateFieldOrder()
      this.updatePreview()
    }
  }
  
  moveFieldDown(event) {
    event.preventDefault()
    const fieldRow = event.target.closest('.field-row')
    const nextRow = fieldRow.nextElementSibling
    
    if (nextRow && nextRow.classList.contains('field-row')) {
      fieldRow.parentNode.insertBefore(nextRow, fieldRow)
      this.updateFieldOrder()
      this.updatePreview()
    }
  }
  
  // 터치 이벤트 핸들러들
  handleTouchStart(event) {
    const fieldRow = event.target.closest('.field-row')
    if (!fieldRow) return
    
    // 편집 모드인 경우 터치 이동 방지
    const editMode = fieldRow.querySelector('.edit-mode')
    if (editMode && !editMode.classList.contains('hidden')) {
      return
    }
    
    // 터치 시작 위치 저장
    this.touchStartY = event.touches[0].clientY
    this.touchedElement = fieldRow
    this.touchedElement.style.opacity = '0.5'
    this.touchedElement.style.zIndex = '1000'
    
    // 스크롤 방지
    event.preventDefault()
  }
  
  handleTouchMove(event) {
    if (!this.touchedElement) return
    
    event.preventDefault()
    
    const touch = event.touches[0]
    const currentY = touch.clientY
    const deltaY = currentY - this.touchStartY
    
    // 이동 중인 요소 표시
    this.touchedElement.style.transform = `translateY(${deltaY}px)`
    
    // 드롭 위치 하이라이트
    const elementBelow = document.elementFromPoint(touch.clientX, touch.clientY)
    const fieldRowBelow = elementBelow?.closest('.field-row')
    
    if (fieldRowBelow && fieldRowBelow !== this.touchedElement) {
      // 기존 하이라이트 제거
      const allRows = this.requiredFieldsTarget.querySelectorAll('.field-row')
      allRows.forEach(row => row.classList.remove('border-t-4', 'border-indigo-500'))
      
      // 새 하이라이트 추가
      fieldRowBelow.classList.add('border-t-4', 'border-indigo-500')
    }
  }
  
  handleTouchEnd(event) {
    if (!this.touchedElement) return
    
    const touch = event.changedTouches[0]
    const elementBelow = document.elementFromPoint(touch.clientX, touch.clientY)
    const fieldRowBelow = elementBelow?.closest('.field-row')
    
    // 스타일 초기화
    this.touchedElement.style.opacity = ''
    this.touchedElement.style.zIndex = ''
    this.touchedElement.style.transform = ''
    
    // 하이라이트 제거
    const allRows = this.requiredFieldsTarget.querySelectorAll('.field-row')
    allRows.forEach(row => row.classList.remove('border-t-4', 'border-indigo-500'))
    
    // 드롭 처리
    if (fieldRowBelow && fieldRowBelow !== this.touchedElement) {
      const rect = fieldRowBelow.getBoundingClientRect()
      const y = touch.clientY - rect.top
      const height = rect.height
      
      if (y < height / 2) {
        fieldRowBelow.parentNode.insertBefore(this.touchedElement, fieldRowBelow)
      } else {
        fieldRowBelow.parentNode.insertBefore(this.touchedElement, fieldRowBelow.nextSibling)
      }
      
      this.updateFieldOrder()
      this.updatePreview()
    }
    
    this.touchedElement = null
    this.touchStartY = null
  }
  
  // 미리보기 메서드들
  updatePreview() {
    if (!this.hasPreviewFieldsTarget) return
    
    // 미리보기 컨테이너 초기화
    this.previewFieldsTarget.innerHTML = ''
    
    // 현재 필드들을 순서대로 가져오기
    const fieldRows = this.requiredFieldsTarget.querySelectorAll('.field-row')
    const fields = []
    
    fieldRows.forEach(row => {
      const labelInput = row.querySelector('[data-field-label]')
      const typeSelect = row.querySelector('[data-field-type]')
      const requiredCheckbox = row.querySelector('[data-field-required]')
      
      if (labelInput && labelInput.value.trim()) {
        const fieldData = {
          label: labelInput.value.trim(),
          type: typeSelect ? typeSelect.value : 'text',
          required: requiredCheckbox ? requiredCheckbox.checked : true
        }
        
        // 선택지 타입인 경우 옵션 추가
        if (fieldData.type === 'select') {
          const optionsInput = row.querySelector('[data-field-options]')
          if (optionsInput) {
            const optionsText = optionsInput.value.trim()
            const options = optionsText.split(',').map(opt => opt.trim()).filter(opt => opt)
            fieldData.options = options.length > 0 ? options : ['옵션1', '옵션2', '옵션3']
          } else {
            fieldData.options = ['옵션1', '옵션2', '옵션3']
          }
        }
        
        fields.push(fieldData)
      }
    })
    
    // 미리보기 생성
    if (fields.length === 0) {
      this.previewFieldsTarget.innerHTML = '<p class="text-sm text-gray-500 italic">추가 필드가 없습니다.</p>'
    } else {
      fields.forEach(field => {
        const previewField = this.createPreviewField(field)
        this.previewFieldsTarget.appendChild(previewField)
      })
    }
  }
  
  createPreviewField(field) {
    const div = document.createElement('div')
    div.className = 'mb-3'
    
    const fieldId = `preview_${field.label.replace(/\s+/g, '_').toLowerCase()}`
    
    let inputHtml = ''
    switch (field.type) {
      case 'number':
        inputHtml = `<input type="number" id="${fieldId}" class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm" placeholder="${field.label} 입력">`
        break
      case 'participants':
        inputHtml = `<textarea id="${fieldId}" rows="2" class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm" placeholder="구성원 목록 (예: 홍길동, 김철수)"></textarea>`
        break
      case 'organization':
        inputHtml = `<select id="${fieldId}" class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm">
          <option value="">조직 선택</option>
          <option value="dev">개발팀</option>
          <option value="sales">영업팀</option>
          <option value="hr">인사팀</option>
        </select>`
        break
      case 'select':
        const options = field.options || ['옵션1', '옵션2', '옵션3']
        const optionsHtml = options.map(opt => `<option value="${opt}">${opt}</option>`).join('')
        inputHtml = `<select id="${fieldId}" class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm">
          <option value="">선택하세요</option>
          ${optionsHtml}
        </select>`
        break
      default:
        inputHtml = `<input type="text" id="${fieldId}" class="mt-1 block w-full rounded-md border-gray-300 shadow-sm focus:border-indigo-500 focus:ring-indigo-500 sm:text-sm" placeholder="${field.label} 입력">`
    }
    
    div.innerHTML = `
      <label for="${fieldId}" class="block text-sm font-medium text-gray-700">
        ${field.label}
        ${field.required ? '<span class="text-red-500">*</span>' : ''}
      </label>
      ${inputHtml}
    `
    
    return div
  }
  
  prepareFormData(event) {
    console.log('prepareFormData called')
    
    // 중복 제출 방지
    if (this.isSubmitting) {
      console.log('Form is already submitting, preventing duplicate submission')
      event.preventDefault()
      return false
    }
    this.isSubmitting = true
    
    // 폼 객체 가져오기
    const form = event.target
    
    // 기존 동적으로 추가된 hidden fields 제거
    const existingHiddenFields = form.querySelectorAll('input[data-dynamic-field="true"]')
    existingHiddenFields.forEach(field => field.remove())
    
    // 한도 없음 체크박스 상태를 hidden field로 추가
    if (this.hasNoLimitCheckboxTarget && this.noLimitCheckboxTarget.checked) {
      const noLimitInput = document.createElement('input')
      noLimitInput.type = 'hidden'
      noLimitInput.name = 'no_limit'
      noLimitInput.value = '1'
      noLimitInput.setAttribute('data-dynamic-field', 'true')
      form.appendChild(noLimitInput)
    }
    
    // 필수 필드 데이터 수집
    const requiredFields = {}
    const fieldRows = this.requiredFieldsTarget.querySelectorAll('.field-row')
    
    fieldRows.forEach((row, index) => {
      // 기존 키 사용하거나 새로 생성
      let fieldKey = row.dataset.fieldKey
      if (!fieldKey) {
        fieldKey = this.generateFieldKey()
        row.dataset.fieldKey = fieldKey // DOM에 저장
      }
      
      // 편집 모드인지 읽기 모드인지 확인
      const editMode = row.querySelector('.edit-mode')
      const viewMode = row.querySelector('.view-mode')
      const isEditing = editMode && !editMode.classList.contains('hidden')
      
      let label, type, required
      
      if (isEditing) {
        // 편집 모드에서 값 읽기
        label = row.querySelector('[data-field-label]')?.value || ''
        type = row.querySelector('[data-field-type]')?.value || 'text'
        required = row.querySelector('[data-field-required]')?.checked !== false
      } else {
        // 읽기 모드에서 값 읽기
        const labelSpan = viewMode.querySelector('span.font-medium')
        const typeSpan = viewMode.querySelector('span[data-field-type]')
        const requiredSpan = viewMode.querySelector('span.bg-red-100')
        
        label = labelSpan?.textContent || ''
        type = typeSpan?.dataset.fieldType || 'text'
        required = !!requiredSpan
      }
      
      if (label.trim()) {
        const fieldData = {
          label: label.trim(),
          type: type,
          required: required,
          order: index // 순서 정보 추가
        }
        
        console.log(`Processing field ${fieldKey}:`, {
          label: label,
          type: type,
          hasOptionsData: !!row.dataset.options
        })
        
        // 선택지 타입인 경우 옵션 추가
        if (type === 'select') {
          // 먼저 dataset에서 옵션 확인
          if (row.dataset.options) {
            try {
              const options = JSON.parse(row.dataset.options)
              console.log('Using options from dataset:', options)
              fieldData.options = options
            } catch (e) {
              console.error('Failed to parse options from dataset:', e)
            }
          } else {
            // dataset에 없으면 input에서 확인
            const optionsInput = row.querySelector('[data-field-options]')
            if (optionsInput) {
              const optionsText = optionsInput.value.trim()
              const options = optionsText.split(',').map(opt => opt.trim()).filter(opt => opt)
              console.log('Using options from input:', options)
              fieldData.options = options
            }
          }
        }
        
        requiredFields[fieldKey] = fieldData
      }
    })
    
    // hidden field 생성
    console.log('Final requiredFields data:', requiredFields)
    const input = document.createElement('input')
    input.type = 'hidden'
    input.name = 'expense_code[validation_rules][required_fields]'
    input.value = JSON.stringify(requiredFields)
    input.setAttribute('data-dynamic-field', 'true')
    console.log('Hidden field value:', input.value)
    form.appendChild(input)
    
    // 제출 후 플래그 리셋 (에러 발생 시를 대비)
    setTimeout(() => {
      this.isSubmitting = false
    }, 1000)
  }
}