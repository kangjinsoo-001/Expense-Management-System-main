import { Controller } from "@hotwired/stimulus"

// 신청서 실시간 검증 컨트롤러 - 경비 항목과 동일한 방식
export default class extends Controller {
  static targets = ["submitButton", "submitButtonWrapper", "tooltip", "tooltipText"]
  
  connect() {
    console.log("Request form validation controller connected")
    this.validationErrors = new Map() // 검증 에러 상태 추적
    this.setupTooltipEvents()
    this.observeDynamicFields()
    
    // 결재선 라디오 버튼에 이벤트 리스너 추가
    this.attachApprovalLineListeners()
    
    // 초기 로드 시 필드 검증과 결재선 검증 실행
    setTimeout(() => {
      this.validateAllFields()
      // 항상 결재선 검증 실행 (승인이 필요한지 확인하기 위해)
      this.checkApprovalLine()
    }, 100)
  }
  
  setupTooltipEvents() {
    // 제출 버튼 wrapper에 마우스 이벤트 추가
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
  
  // 동적으로 추가되는 필드 감지
  observeDynamicFields() {
    // 초기 필드 바인딩
    const initialFields = this.element.querySelectorAll('input[name*="[form_data]"], select[name*="[form_data]"], textarea[name*="[form_data]"]')
    initialFields.forEach(field => {
      if (field.type !== 'hidden') {
        this.attachValidationToField(field)
      }
    })
    
    // MutationObserver로 DOM 변경 감지
    const observer = new MutationObserver((mutations) => {
      mutations.forEach((mutation) => {
        if (mutation.type === 'childList' && mutation.addedNodes.length > 0) {
          mutation.addedNodes.forEach((node) => {
            if (node.nodeType === 1) { // Element node
              // 새로 추가된 동적 필드 찾기
              const formFields = node.querySelectorAll ? 
                node.querySelectorAll('input[name*="[form_data]"], select[name*="[form_data]"], textarea[name*="[form_data]"]') : []
              
              if (node.matches && node.matches('input[name*="[form_data]"], select[name*="[form_data]"], textarea[name*="[form_data]"]')) {
                if (node.type !== 'hidden') {
                  this.attachValidationToField(node)
                }
              }
              
              formFields.forEach(field => {
                if (field.type !== 'hidden') {
                  this.attachValidationToField(field)
                }
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
    console.log('동적 필드에 검증 추가:', fieldName, 'required:', field.required)
    
    // input, select, textarea에 따라 다른 이벤트 사용
    if (field.tagName === 'SELECT') {
      field.addEventListener('change', (e) => {
        console.log('Select 필드 변경:', e.target.name, 'value:', e.target.value)
        this.validateField(e)
      })
    } else if (field.type === 'checkbox') {
      field.addEventListener('change', (e) => {
        console.log('Checkbox 필드 변경:', e.target.name, 'checked:', e.target.checked)
        this.validateField(e)
      })
    } else {
      field.addEventListener('input', (e) => {
        console.log('Input 필드 변경:', e.target.name, 'value:', e.target.value)
        this.validateField(e)
      })
      field.addEventListener('blur', (e) => {
        console.log('Blur 이벤트:', e.target.name)
        this.validateField(e)
      })
    }
    
    field.dataset.validationAttached = 'true'
  }
  
  // 결재선 라디오 버튼에 이벤트 리스너 추가
  attachApprovalLineListeners() {
    const approvalLineRadios = this.element.querySelectorAll('input[name="request_form[approval_line_id]"]')
    approvalLineRadios.forEach(radio => {
      radio.addEventListener('change', (event) => {
        console.log('결재선 라디오 버튼 변경:', event.target.value)
        this.checkApprovalLine()
      })
    })
  }
  
  disconnect() {
    // MutationObserver 정리
    if (this.observer) {
      this.observer.disconnect()
    }
  }
  
  // 필드 입력 시 검증
  validateField(event) {
    const field = event.target
    
    // 단일 필드 검증
    this.validateSingleField(field)
    
    // 결재선 검증 - 항상 실행
    if (field.name === 'request_form[approval_line_id]') {
      // 검증은 무조건 실행 (결재 없음 선택 시에도)
      this.checkApprovalLine()
    }
  }
  
  // 단일 필드 검증
  validateSingleField(field) {
    console.log('validateSingleField 시작:', field.name, 'required:', field.required)
    
    let container = field.closest('.field-item') || field.closest('div')
    
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
    
    // 기존 에러 메시지 제거
    const existingError = container.querySelector(':scope > .field-error')
    if (existingError) existingError.remove()
    
    // 필드 테두리 초기화
    if (field.hasAttribute('data-choices-initialized')) {
      const choicesInner = container.querySelector('.choices__inner')
      if (choicesInner) {
        choicesInner.classList.remove('border-red-300', 'border-green-300')
      }
    } else {
      field.classList.remove('border-red-300', 'border-green-300')
    }
    
    // 필수 필드 체크
    const isRequired = field.required || field.hasAttribute('required')
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
        field.insertAdjacentElement('afterend', error)
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
  
  // 필드가 비어있는지 확인
  isFieldEmpty(field) {
    const value = field.value
    
    // checkbox 필드 체크
    if (field.type === 'checkbox') {
      // checkbox의 경우 checked 상태를 확인해야 함
      return !field.checked
    }
    
    // 멀티셀렉트 체크 (Choice.js)
    if (field.multiple && field._choices) {
      const selectedValues = field._choices.getValue(true)
      return !selectedValues || selectedValues.length === 0
    }
    
    // select의 프롬프트 값 체크
    if (field.tagName === 'SELECT') {
      // 빈 값이거나 프롬프트 텍스트인 경우
      return !value || value === '' || value === '선택하세요'
    }
    
    // 일반 필드
    return !value || value.trim() === ''
  }
  
  // 필드별 에러 메시지
  getFieldErrorMessage(field) {
    // 레이블에서 필드명 추출
    const fieldKey = field.name.match(/\[([^\]]+)\]$/)?.[1]
    const fieldContainer = field.closest('.field-item')
    const label = fieldContainer?.querySelector('label')
    
    if (label) {
      // 레이블 텍스트에서 * 표시 제거
      const labelText = label.textContent.replace('*', '').trim()
      return `${labelText} 필수`
    }
    
    // 폴백
    return `이 필드는 필수입니다`
  }
  
  // 필드만 검증 (결재선 제외)
  validateAllFields() {
    console.log('필드 검증 시작')
    
    // 모든 동적 필드 검증
    const fields = this.element.querySelectorAll('input[name*="[form_data]"]:not([type="hidden"]), select[name*="[form_data]"], textarea[name*="[form_data]"]')
    console.log('검증할 필드 수:', fields.length)
    
    fields.forEach(field => {
      // required 속성이 있는 필드만 검증
      if (field.required || field.hasAttribute('required')) {
        console.log('필수 필드 검증:', field.name, 'value:', field.value)
        this.validateSingleField(field)
      }
    })
  }
  
  // 전체 검증 (필드 + 결재선)
  validateAll() {
    console.log('전체 폼 검증 시작')
    this.validateAllFields()
    this.checkApprovalLine()
  }
  
  // 결재선 검증
  async checkApprovalLine() {
    console.log('=== checkApprovalLine 시작 ===')
    
    // 템플릿의 승인 규칙 확인 (window.templateApprovalRules에서 읽기)
    const templateApprovalRules = window.templateApprovalRules || []
    console.log('템플릿 승인 규칙:', templateApprovalRules)
    
    if (templateApprovalRules.length === 0) {
      console.log('승인 규칙이 없음')
      this.clearApprovalError()
      return
    }
    
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
    
    // 현재 폼 데이터 수집 (조건 평가용)
    const formData = {}
    const formFields = this.element.querySelectorAll('input[name*="[form_data]"], select[name*="[form_data]"], textarea[name*="[form_data]"]')
    formFields.forEach(field => {
      const fieldKey = field.name.match(/\[form_data\]\[([^\]]+)\]/)?.[1]
      if (fieldKey) {
        formData[fieldKey] = field.value
      }
    })
    console.log('폼 데이터:', formData)
    
    templateApprovalRules.forEach(rule => {
      console.log('규칙 체크:', rule)
      
      // 조건 평가
      let ruleApplies = false
      if (!rule.condition || rule.condition === '' || rule.condition === null) {
        // 조건이 없으면 항상 적용
        ruleApplies = true
        console.log('=> 조건 없음, 항상 적용')
      } else {
        // 조건이 있으면 평가 (간단한 평가만 구현)
        // TODO: 서버와 동일한 조건 평가 로직 구현 필요
        ruleApplies = true // 임시로 true
        console.log(`=> 조건: ${rule.condition}, 적용: ${ruleApplies}`)
      }
      
      if (ruleApplies && rule.approver_group) {
        const groupPriority = rule.approver_group.priority || 0
        console.log(`그룹: ${rule.approver_group.name}, 우선순위: ${groupPriority}, 사용자 최고 우선순위: ${userMaxPriority}`)
        
        // 사용자의 권한이 요구되는 권한보다 낮으면 승인 필요
        if (userMaxPriority < groupPriority) {
          console.log(`=> 승인 필요: ${rule.approver_group.name}`)
          requiredGroups.push(rule.approver_group.name)
        } else {
          console.log(`=> 사용자가 이미 권한 보유`)
        }
      }
    })
    
    const needsApproval = requiredGroups.length > 0
    
    console.log('승인 필요 여부:', needsApproval, '필요 그룹:', requiredGroups)
    
    // 선택된 결재선 확인
    const approvalRadios = document.querySelectorAll('input[name="request_form[approval_line_id]"]')
    let hasApprovalLine = false
    let selectedApprovalLineId = null
    let isNoApprovalSelected = false // "결재 없음" 선택 여부 추가
    
    approvalRadios.forEach(radio => {
      if (radio.checked) {
        if (radio.value === '') {
          // "결재 없음" 선택된 경우
          isNoApprovalSelected = true
        } else {
          hasApprovalLine = true
          selectedApprovalLineId = radio.value
        }
      }
    })
    
    console.log('결재선 선택 여부:', hasApprovalLine, '선택된 결재선 ID:', selectedApprovalLineId, '"결재 없음" 선택:', isNoApprovalSelected)
    
    // Case 1: 승인이 필요한데 결재선이 선택되지 않은 경우 ("결재 없음" 선택 포함)
    if (needsApproval && (!hasApprovalLine || isNoApprovalSelected)) {
      const message = `승인 필요: ${requiredGroups.join(', ')}`
      console.log('결재선 필수 메시지 표시:', message)
      
      // 메시지 표시 (요소가 있을 때만)
      const approvalMessages = document.getElementById('approval_server_messages')
      if (approvalMessages) {
        approvalMessages.innerHTML = `
          <div class="mt-2 p-3 bg-red-50 border border-red-200 rounded-md">
            <div class="flex items-start gap-2">
              <svg class="h-4 w-4 text-red-600 mt-0.5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
              </svg>
              <div class="text-sm text-red-800">
                <p>${message}</p>
              </div>
            </div>
          </div>`
      }
      
      // 에러 맵에 추가 (메시지 표시 여부와 관계없이)
      this.validationErrors.set('approval_line', message)
      this.updateSubmitButton()
      return // 여기서 종료
    }
      
    // Case 2: 결재선이 선택된 경우
    if (hasApprovalLine && selectedApprovalLineId) {
      // 결재선이 선택된 경우 - 승인 충족 여부 및 과도한 승인자 체크
      const approvalLinesData = window.approvalLinesData || {}
      const selectedLineData = approvalLinesData[selectedApprovalLineId]
      const approvalMessages = document.getElementById('approval_server_messages')
      
      if (selectedLineData && selectedLineData.approver_groups) {
          // 원본 템플릿이 요구하는 최고 우선순위 (사용자 권한 관계없이)
          let originalMaxRequiredPriority = 0
          templateApprovalRules.forEach(rule => {
            if (rule.approver_group) {
              originalMaxRequiredPriority = Math.max(originalMaxRequiredPriority, rule.approver_group.priority || 0)
            }
          })
          
          // 사용자 권한을 고려한 필요한 최고 우선순위
          let userAdjustedMaxRequiredPriority = 0
          templateApprovalRules.forEach(rule => {
            if (rule.approver_group && rule.approver_group.priority > userMaxPriority) {
              userAdjustedMaxRequiredPriority = Math.max(userAdjustedMaxRequiredPriority, rule.approver_group.priority)
            }
          })
          
          // 실제 결재선의 최고 우선순위
          let maxActualPriority = 0
          const actualGroups = []
          
          selectedLineData.approver_groups.forEach(group => {
            if (group.priority > maxActualPriority) {
              maxActualPriority = group.priority
            }
            actualGroups.push(group)
          })
          
          console.log('원본 요구 최고 우선순위:', originalMaxRequiredPriority)
          console.log('사용자 조정 최고 우선순위:', userAdjustedMaxRequiredPriority)
          console.log('실제 결재선 최고 우선순위:', maxActualPriority)
          
          // 원본 템플릿 요구사항을 충족하지 못한 경우
          if (originalMaxRequiredPriority > 0 && maxActualPriority < originalMaxRequiredPriority) {
            const message = `승인 필요: ${requiredGroups.join(', ')}`
            console.log('결재선 불충분:', message)
            
            // 메시지 표시 (요소가 있을 때만)
            if (approvalMessages) {
              approvalMessages.innerHTML = `
                <div class="mt-2 p-3 bg-red-50 border border-red-200 rounded-md">
                  <div class="flex items-start gap-2">
                    <svg class="h-4 w-4 text-red-600 mt-0.5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                      <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
                    </svg>
                    <div class="text-sm text-red-800">
                      <p>${message}</p>
                    </div>
                  </div>
                </div>`
            }
            
            // 에러 맵에 추가 (메시지 표시 여부와 관계없이)
            this.validationErrors.set('approval_line', message)
            this.updateSubmitButton()
            return // 에러가 있으므로 여기서 종료
          }
          // 과도한 승인자 체크 (사용자 조정 우선순위 기준)
          else if (maxActualPriority > userAdjustedMaxRequiredPriority && userAdjustedMaxRequiredPriority > userMaxPriority) {
            const excessiveGroups = actualGroups.filter(g => g.priority > userAdjustedMaxRequiredPriority)
            const excessiveGroupNames = [...new Set(excessiveGroups.map(g => g.name))]
            
            if (excessiveGroupNames.length > 0) {
              const warningMessage = `필수 아님: ${excessiveGroupNames.join(', ')}`
              console.log('과도한 승인자 경고:', warningMessage)
              
              // 메시지 표시 (요소가 있을 때만)
              if (approvalMessages) {
                approvalMessages.innerHTML = `
                  <div class="mt-2 p-3 bg-yellow-50 border border-yellow-200 rounded-md">
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
              }
              // 경고는 에러가 아니므로 에러 맵에서 제거
              this.validationErrors.delete('approval_line')
              this.updateSubmitButton()
            } else {
              // 정확히 충족되면 메시지 없음
              this.clearApprovalError()
              // 에러가 없으므로 에러 맵에서 제거
              this.validationErrors.delete('approval_line')
              this.updateSubmitButton()
            }
          } else {
            // 정확히 충족되면 메시지 없음
            this.clearApprovalError()
            // 에러가 없으므로 에러 맵에서 제거
            this.validationErrors.delete('approval_line')
            this.updateSubmitButton()
          }
        } else {
          // 정확히 충족되면 메시지 없음
          this.clearApprovalError()
          // 에러가 없으므로 에러 맵에서 제거
          this.validationErrors.delete('approval_line')
          this.updateSubmitButton()
        }
        
        return // 여기서 종료
      }
      
    // Case 3: 승인이 필요 없는 경우
    if (!needsApproval) {
      const approvalMessages = document.getElementById('approval_server_messages')
      
      // 승인이 필요 없는데 결재선을 선택한 경우 경고 표시
      if (hasApprovalLine) {
        const approvalLinesData = window.approvalLinesData || {}
        const selectedLineData = approvalLinesData[selectedApprovalLineId]
        
        if (selectedLineData && selectedLineData.approver_groups) {
          const actualGroups = selectedLineData.approver_groups
          const groupNames = [...new Set(actualGroups.map(g => g.name))]
          
          const warningMessage = `필수 아님: ${groupNames.join(', ')}`
          console.log('불필요한 결재선 경고:', warningMessage)
          
          // 메시지 표시 (요소가 있을 때만)
          if (approvalMessages) {
            approvalMessages.innerHTML = `
              <div class="mt-2 p-3 bg-yellow-50 border border-yellow-200 rounded-md">
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
          }
        }
      } else {
        // 승인도 필요 없고 결재선도 선택하지 않은 경우 - 모든 에러 제거
        this.clearApprovalError()
      }
      
      // 승인이 필요 없으면 에러는 없음
      this.validationErrors.delete('approval_line')
      this.updateSubmitButton()
    }
  }
  
  // 결재선 에러 제거
  clearApprovalError() {
    const approvalMessages = document.getElementById('approval_server_messages')
    if (approvalMessages) {
      approvalMessages.innerHTML = ''
    }
    this.validationErrors.delete('approval_line')
    this.updateSubmitButton()
  }
  
  // 제출 버튼 상태 업데이트
  updateSubmitButton() {
    // 제출 버튼이 없으면 종료
    if (!this.hasSubmitButtonTarget) {
      console.log('제출 버튼 target이 없음')
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
      const originalText = submitButton.dataset.originalText || submitButton.textContent
      if (!submitButton.dataset.originalText) {
        submitButton.dataset.originalText = submitButton.textContent
      }
      submitButton.textContent = `${originalText} (${this.validationErrors.size}개 오류)`
      
      // 커스텀 툴팁 텍스트 설정
      if (this.hasTooltipTextTarget) {
        const errorMessages = Array.from(this.validationErrors.values())
        this.tooltipTextTarget.textContent = errorMessages.join(', ')
      }
    } else {
      // 에러가 없으면 버튼 활성화
      submitButton.disabled = false
      submitButton.classList.remove('opacity-50', 'cursor-not-allowed')
      submitButton.classList.add('hover:bg-indigo-700')
      
      // 원래 텍스트로 복원
      if (submitButton.dataset.originalText) {
        submitButton.textContent = submitButton.dataset.originalText
      }
      
      // 커스텀 툴팁 숨기기
      if (this.hasTooltipTarget) {
        this.tooltipTarget.classList.add('hidden')
      }
    }
  }
}