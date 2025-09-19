import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

let Choices

export default class extends Controller {
  static targets = ["steps", "stepTemplate", "addButton"]
  
  async connect() {
    await this.loadChoicesJS()
    this.stepCounter = this.getMaxStepOrder()
    this.updateStepNumbers()
    this.initializeExistingElements()
    this.initializeSortable()
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

  disconnect() {
    // Choices 인스턴스 정리
    this.stepsTarget.querySelectorAll('select.approver-select').forEach(select => {
      if (select.choices) {
        select.choices.destroy()
      }
    })
    
    // Sortable 인스턴스 정리
    if (this.sortable) {
      this.sortable.destroy()
    }
  }

  initializeExistingElements() {
    // 기존 단계들의 Choice.js 초기화
    this.stepsTarget.querySelectorAll('.approval-step-group').forEach(stepGroup => {
      this.initializeStepGroup(stepGroup)
    })
  }

  initializeStepGroup(stepGroup) {
    // 각 승인자 선택 필드에 Choice.js 초기화
    stepGroup.querySelectorAll('.approver-select').forEach(select => {
      this.initializeChoices(select)
      
      // 승인자 선택 변경 시 다른 선택 필드 업데이트
      select.addEventListener('change', (e) => this.handleApproverChange(e))
    })
    
    // 역할 변경 이벤트 설정
    stepGroup.querySelectorAll('.role-select').forEach(select => {
      select.addEventListener('change', (e) => this.handleRoleChange(e))
    })
    
    // 승인자 삭제 버튼은 Stimulus action으로 처리됨 - 추가 이벤트 불필요
    
    // 승인 타입 표시 여부 업데이트
    this.updateApprovalTypeVisibility(stepGroup)
    
    // 선택된 승인자 업데이트
    this.updateAvailableApprovers(stepGroup)
  }

  initializeChoices(select) {
    if (select.hasAttribute('data-choices-initialized')) {
      return
    }
    
    const choices = new Choices(select, {
      searchEnabled: true,
      itemSelectText: '',
      noResultsText: '검색 결과가 없습니다',
      noChoicesText: '선택할 수 있는 사용자가 없습니다',
      placeholder: true,
      placeholderValue: '승인자를 선택하세요',
      searchPlaceholderValue: '이름 또는 조직으로 검색',
      shouldSort: false,
      removeItemButton: false
    })
    
    select.choices = choices
    select.setAttribute('data-choices-initialized', 'true')
  }

  addStep(event) {
    event.preventDefault()
    
    const template = this.stepTemplateTarget.content.cloneNode(true)
    const stepGroup = template.querySelector('.approval-step-group')
    
    // 새로운 step의 ID와 name 속성 업데이트
    const newIndex = new Date().getTime()
    stepGroup.querySelectorAll('[name], [id]').forEach(element => {
      if (element.name) {
        element.name = element.name.replace(/NEW_RECORD/g, newIndex)
      }
      if (element.id) {
        element.id = element.id.replace(/NEW_RECORD/g, newIndex)
      }
    })
    
    // step_order 설정
    this.stepCounter++
    const stepOrderInput = stepGroup.querySelector('[name*="[step_order]"]')
    if (stepOrderInput) {
      stepOrderInput.value = this.stepCounter
    }
    stepGroup.setAttribute('data-step-order', this.stepCounter)
    
    // step number 표시 업데이트
    const stepNumber = stepGroup.querySelector('.step-number')
    if (stepNumber) {
      stepNumber.textContent = this.stepCounter
    }
    
    this.stepsTarget.appendChild(stepGroup)
    this.initializeStepGroup(stepGroup)
    this.updateStepNumbers()
  }

  addApproverToStep(event) {
    event.preventDefault()
    
    const stepGroup = event.target.closest('.approval-step-group')
    const approversContainer = stepGroup.querySelector('.approvers-container')
    const stepOrder = stepGroup.getAttribute('data-step-order')
    
    // 이미 선택된 승인자 목록 가져오기
    const selectedApprovers = new Set()
    approversContainer.querySelectorAll('.approval-step:not([style*="display: none"]) .approver-select').forEach(select => {
      if (select.value) {
        selectedApprovers.add(select.value)
      }
    })
    
    // 현재 단계의 approval_type 값 가져오기
    const approvalTypeSelect = stepGroup.querySelector('.approval-type-select')
    const currentApprovalType = approvalTypeSelect ? approvalTypeSelect.value : 'single_allowed'
    
    // 새 승인자 HTML 생성
    const newIndex = new Date().getTime()
    const approverHtml = `
      <div class="approval-step relative">
        <input type="hidden" name="approval_line[approval_line_steps_attributes][${newIndex}][step_order]" value="${stepOrder}">
        <input type="hidden" name="approval_line[approval_line_steps_attributes][${newIndex}][_destroy]" value="false">
        <input type="hidden" name="approval_line[approval_line_steps_attributes][${newIndex}][approval_type]" value="${currentApprovalType}" class="approval-type-hidden">
        
        <div class="grid grid-cols-1 md:grid-cols-3 gap-4">
          <div class="md:col-span-2">
            <select name="approval_line[approval_line_steps_attributes][${newIndex}][approver_id]" 
                    class="w-full approver-select">
              <option value="">승인자를 선택하세요</option>
              ${window.approvalLineUsers.map(user => {
                const orgName = user.organization?.name || "소속 없음"
                const disabled = selectedApprovers.has(user.id.toString()) ? 'disabled' : ''
                return `<option value="${user.id}" ${disabled}>${user.name} (${orgName})</option>`
              }).join('')}
            </select>
          </div>
          
          <div class="flex items-center gap-2">
            <select name="approval_line[approval_line_steps_attributes][${newIndex}][role]" 
                    class="flex-1 px-3 py-2 border border-gray-300 rounded-lg focus:ring-blue-500 focus:border-blue-500 role-select">
              <option value="approve">승인</option>
              <option value="reference">참조</option>
            </select>
            
            <button type="button"
                    data-action="click->approval-line-form#removeApprover"
                    class="text-red-600 hover:text-red-800 transition-colors"
                    title="삭제">
              <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
              </svg>
            </button>
          </div>
        </div>
      </div>
    `
    
    const wrapper = document.createElement('div')
    wrapper.innerHTML = approverHtml
    const newApprover = wrapper.firstElementChild
    
    approversContainer.appendChild(newApprover)
    
    // 새로 추가된 요소들 초기화
    const newSelect = newApprover.querySelector('.approver-select')
    this.initializeChoices(newSelect)
    // Choices.js가 자동 선택하지 않도록 빈 값으로 설정
    if (newSelect.choices) {
      newSelect.choices.setChoiceByValue('')
    }
    newSelect.addEventListener('change', (e) => this.handleApproverChange(e))
    
    const roleSelect = newApprover.querySelector('.role-select')
    roleSelect.addEventListener('change', (e) => this.handleRoleChange(e))
    
    this.updateApprovalTypeVisibility(stepGroup)
    this.updateAvailableApprovers(stepGroup)
  }

  removeApprover(event) {
    event.preventDefault()
    event.stopPropagation()
    
    const approver = event.target.closest('.approval-step')
    const stepGroup = event.target.closest('.approval-step-group')
    const approversContainer = stepGroup.querySelector('.approvers-container')
    
    // 현재 표시되는 승인자 수 확인
    const visibleApprovers = approversContainer.querySelectorAll('.approval-step:not([style*="display: none"])')
    
    // 마지막 승인자인 경우 단계 전체 삭제
    if (visibleApprovers.length <= 1) {
      if (confirm('이 단계를 삭제하시겠습니까?')) {
        // removeStepGroup 대신 직접 처리
        stepGroup.querySelectorAll('.approval-step').forEach(step => {
          const destroyInput = step.querySelector('[name*="_destroy"]')
          if (destroyInput) {
            destroyInput.value = '1'
          }
        })
        
        stepGroup.style.display = 'none'
        this.updateStepNumbers()
      }
      return
    }
    
    // destroy 플래그 설정 또는 요소 제거
    const destroyInput = approver.querySelector('[name*="_destroy"]')
    if (approver.querySelector('[name*="[id]"]')) {
      // 기존 레코드인 경우 destroy 플래그 설정
      destroyInput.value = '1'
      approver.style.display = 'none'
    } else {
      // 새로 추가된 경우 바로 제거
      approver.remove()
    }
    
    this.updateApprovalTypeVisibility(stepGroup)
    this.updateAvailableApprovers(stepGroup)
  }

  removeStepGroup(event) {
    event.preventDefault()
    
    const stepGroup = event.target.closest('.approval-step-group')
    
    // 모든 승인자에 destroy 플래그 설정
    stepGroup.querySelectorAll('.approval-step').forEach(step => {
      const destroyInput = step.querySelector('[name*="_destroy"]')
      if (destroyInput) {
        destroyInput.value = '1'
      }
    })
    
    stepGroup.style.display = 'none'
    this.updateStepNumbers()
  }

  handleRoleChange(event) {
    const stepGroup = event.target.closest('.approval-step-group')
    const approver = event.target.closest('.approval-step')
    const approvalTypeHidden = approver.querySelector('[name*="[approval_type]"]')
    const approvalTypeSelect = stepGroup.querySelector('.approval-type-select')
    
    // 역할이 '승인'으로 변경되면 approval_type 설정
    if (event.target.value === 'approve' && approvalTypeHidden && approvalTypeSelect) {
      approvalTypeHidden.value = approvalTypeSelect.value
    } else if (event.target.value === 'reference' && approvalTypeHidden) {
      // 참조로 변경되면 approval_type을 비움
      approvalTypeHidden.value = ''
    }
    
    this.updateApprovalTypeVisibility(stepGroup)
  }

  updateApprovalTypeVisibility(stepGroup) {
    const approvalTypeField = stepGroup.querySelector('.approval-type-field')
    const visibleApprovers = stepGroup.querySelectorAll('.approval-step:not([style*="display: none"])')
    const approveCount = Array.from(visibleApprovers).filter(step => {
      const roleSelect = step.querySelector('.role-select')
      return roleSelect && roleSelect.value === 'approve'
    }).length
    
    // 승인자가 2명 이상인 경우에만 승인 타입 표시
    if (approveCount >= 2) {
      approvalTypeField.style.display = 'flex'
    } else {
      approvalTypeField.style.display = 'none'
    }
  }

  updateStepNumbers() {
    const visibleStepGroups = this.stepsTarget.querySelectorAll('.approval-step-group:not([style*="display: none"])')
    
    visibleStepGroups.forEach((stepGroup, index) => {
      const stepNumber = index + 1
      
      // 단계 번호 표시 업데이트
      const stepNumberElement = stepGroup.querySelector('.step-number')
      if (stepNumberElement) {
        stepNumberElement.textContent = stepNumber
      }
      
      // 모든 승인자의 step_order 업데이트 - 표시되는 승인자만
      stepGroup.querySelectorAll('.approval-step:not([style*="display: none"]) [name*="[step_order]"]').forEach(input => {
        console.log(`Updating step_order from ${input.value} to ${stepNumber}`)
        input.value = stepNumber
      })
      
      stepGroup.setAttribute('data-step-order', stepNumber)
    })
    
    // 디버깅: 업데이트 후 모든 step_order 값 확인
    console.log('After updateStepNumbers:')
    this.stepsTarget.querySelectorAll('.approval-step-group:not([style*="display: none"])').forEach((group, idx) => {
      const stepOrder = group.getAttribute('data-step-order')
      const inputs = group.querySelectorAll('.approval-step:not([style*="display: none"]) [name*="[step_order]"]')
      console.log(`Step ${idx + 1}: data-step-order=${stepOrder}, input values=${Array.from(inputs).map(i => i.value).join(', ')}`)
    })
  }

  getMaxStepOrder() {
    const stepGroups = this.stepsTarget.querySelectorAll('.approval-step-group')
    if (stepGroups.length === 0) return 0
    
    let maxOrder = 0
    stepGroups.forEach(group => {
      const order = parseInt(group.getAttribute('data-step-order') || 0)
      if (order > maxOrder) maxOrder = order
    })
    
    return maxOrder
  }

  initializeSortable() {
    this.sortable = Sortable.create(this.stepsTarget, {
      animation: 150,
      handle: '.drag-handle',
      draggable: '.approval-step-group',
      filter: '[style*="display: none"]',
      ghostClass: 'opacity-50',
      dragClass: 'bg-blue-50',
      onStart: (evt) => {
        console.log('Drag started for step group at index:', evt.oldIndex)
      },
      onEnd: (evt) => {
        console.log(`Drag ended: moved from index ${evt.oldIndex} to ${evt.newIndex}`)
        
        // DOM이 재정렬된 후 step_order 값 업데이트
        this.updateStepNumbers()
        
        // 각 단계 내의 승인자들도 올바른 step_order를 갖도록 재확인
        this.recalculateAllStepOrders()
        
        this.showSaveNotice()
      }
    })
  }
  
  recalculateAllStepOrders() {
    // 모든 표시되는 단계를 순회하며 step_order 재계산
    const visibleStepGroups = this.stepsTarget.querySelectorAll('.approval-step-group:not([style*="display: none"])')
    
    visibleStepGroups.forEach((stepGroup, index) => {
      const stepNumber = index + 1
      
      // 해당 단계의 모든 승인자 step_order 업데이트
      stepGroup.querySelectorAll('.approval-step').forEach(approverStep => {
        const stepOrderInput = approverStep.querySelector('[name*="[step_order]"]')
        const destroyInput = approverStep.querySelector('[name*="[_destroy]"]')
        
        // 삭제 표시되지 않은 승인자만 업데이트
        if (stepOrderInput && (!destroyInput || destroyInput.value === 'false')) {
          if (approverStep.style.display !== 'none') {
            stepOrderInput.value = stepNumber
          }
        }
      })
    })
  }

  showSaveNotice() {
    // 순서 변경 시 저장 필요 알림
    if (!this.hasChangesNotice) {
      const notice = document.createElement('div')
      notice.className = 'mt-2 text-sm text-amber-600 bg-amber-50 p-2 rounded'
      notice.textContent = '※ 단계 순서가 변경되었습니다. 저장 버튼을 클릭해주세요.'
      this.stepsTarget.parentElement.appendChild(notice)
      this.hasChangesNotice = true
    }
  }
  
  handleApproverChange(event) {
    const stepGroup = event.target.closest('.approval-step-group')
    this.updateAvailableApprovers(stepGroup)
  }
  
  updateApprovalType(event) {
    const selectedValue = event.target.value
    const stepGroup = event.target.closest('.approval-step-group')
    
    // 해당 단계의 모든 승인자의 approval_type hidden field 업데이트
    stepGroup.querySelectorAll('.approval-step:not([style*="display: none"])').forEach(step => {
      const roleSelect = step.querySelector('.role-select')
      const approvalTypeHidden = step.querySelector('[name*="[approval_type]"]')
      
      if (roleSelect && roleSelect.value === 'approve' && approvalTypeHidden) {
        approvalTypeHidden.value = selectedValue
      }
    })
  }
  
  updateAvailableApprovers(stepGroup) {
    // 같은 단계에서 이미 선택된 승인자들 목록
    const selectedApprovers = new Set()
    stepGroup.querySelectorAll('.approval-step:not([style*="display: none"]) .approver-select').forEach(select => {
      if (select.value) {
        selectedApprovers.add(select.value)
      }
    })
    
    // 모든 선택 필드의 옵션 업데이트
    stepGroup.querySelectorAll('.approval-step:not([style*="display: none"]) .approver-select').forEach(select => {
      const currentValue = select.value || ''
      if (select.choices) {
        // Choices.js 인스턴스가 있는 경우 - 옵션을 다시 설정
        const choices = [{
          value: '',
          label: '승인자를 선택하세요',
          placeholder: true
        }]
        
        window.approvalLineUsers.forEach(user => {
          const orgName = user.organization?.name || "소속 없음"
          const isDisabled = user.id.toString() !== currentValue && selectedApprovers.has(user.id.toString())
          choices.push({
            value: user.id.toString(),
            label: `${user.name} (${orgName})`,
            disabled: isDisabled
          })
        })
        
        // 기존 선택값 유지하면서 choices 업데이트
        select.choices.clearStore()
        select.choices.setChoices(choices, 'value', 'label', false)
        
        // 현재 값 재설정 (빈 값 포함)
        if (currentValue) {
          select.choices.setChoiceByValue(currentValue)
        }
      } else {
        // 일반 select의 경우
        select.querySelectorAll('option').forEach(option => {
          if (option.value !== currentValue && selectedApprovers.has(option.value)) {
            option.disabled = true
          } else {
            option.disabled = false
          }
        })
      }
    })
  }
}