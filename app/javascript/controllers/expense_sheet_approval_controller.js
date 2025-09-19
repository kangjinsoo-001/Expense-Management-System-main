import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["selectRadio", "chip", "preview", "validationArea", "approvalLineField"]
  static values = { sheetId: Number }
  
  connect() {
    console.log("ExpenseSheetApproval controller connected - v2025.01.04.2")
    
    // 디버깅: window 객체에 데이터가 제대로 로드되었는지 확인
    console.log('=== ExpenseSheetApprovalController 디버깅 시작 (v2025.01.04.2) ===')
    console.log('1. window.expenseSheetRulesData:', window.expenseSheetRulesData)
    console.log('2. window.currentUserGroups:', window.currentUserGroups)
    console.log('3. window.currentUserId:', window.currentUserId)
    
    if (window.expenseSheetRulesData) {
      console.log('4. 규칙 상세:')
      window.expenseSheetRulesData.forEach((rule, index) => {
        console.log(`  규칙 ${index + 1}:`, {
          id: rule.id,
          rule_type: rule.rule_type,
          condition: rule.condition,
          submitter_group_id: rule.submitter_group_id,
          approver_group_name: rule.approver_group?.name
        })
      })
    }
    
    if (window.currentUserGroups) {
      console.log('5. 현재 사용자가 속한 그룹:')
      window.currentUserGroups.forEach(group => {
        console.log(`  - ${group.name} (ID: ${group.id})`)
      })
    }
    console.log('=== 디버깅 끝 ===')
    
    // AI 검증 상태 체크
    const submitButton = document.getElementById('expense-sheet-submit-button')
    console.log('Submit button found:', submitButton)
    
    if (submitButton) {
      console.log('Submit button dataset:', submitButton.dataset)
      console.log('data-ai-validated (camelCase):', submitButton.dataset.aiValidated)
      console.log('data-ai_validated (underscore):', submitButton.dataset.ai_validated)
      
      // 실제 HTML 속성 확인
      console.log('getAttribute data-ai-validated:', submitButton.getAttribute('data-ai-validated'))
      console.log('getAttribute data-ai_validated:', submitButton.getAttribute('data-ai_validated'))
    }
    
    // Rails에서 boolean은 문자열로 렌더링됨 ('true' 또는 'false')
    // underscore가 hyphen으로 변환되므로 둘 다 체크
    const aiValidated = submitButton?.dataset.aiValidated === 'true' || 
                       submitButton?.getAttribute('data-ai-validated') === 'true' ||
                       submitButton?.getAttribute('data-ai_validated') === 'true'
                       
    console.log('AI validated final status:', aiValidated)
    
    if (!aiValidated) {
      console.log('AI 검증이 완료되지 않아 결재선 검증을 건너뜁니다')
      return
    }
    
    console.log('✅ AI 검증 완료 - 결재선 검증 진행')
    
    // 초기 선택된 결재선 검증
    const selectedRadio = this.selectRadioTargets.find(radio => radio.checked)
    if (selectedRadio) {
      const approvalLineId = selectedRadio.value
      console.log('초기 선택된 결재선 ID:', approvalLineId || '결재 없음')
      if (approvalLineId) {
        this.showPreview(approvalLineId)
      }
      this.validateApprovalLine(approvalLineId || null)
    }
  }
  
  selectApprovalLine(event) {
    const approvalLineId = event.target.value
    console.log('선택된 결재선 ID:', approvalLineId || '결재 없음')
    
    // 칩 스타일 업데이트
    this.updateChipStyles()
    
    // 미리보기 업데이트 및 검증
    if (approvalLineId) {
      this.showPreview(approvalLineId)
      this.validateApprovalLine(approvalLineId)
    } else {
      // 결재 없음 선택 - 검증 필요
      this.hidePreview()
      this.validateApprovalLine(null)
    }
  }
  
  updateChipStyles() {
    this.chipTargets.forEach((chip) => {
      const radio = chip.previousElementSibling
      if (radio && radio.checked) {
        chip.classList.remove('border-gray-300', 'bg-white', 'text-gray-700', 'hover:border-gray-400')
        chip.classList.add('border-indigo-500', 'bg-indigo-50', 'text-indigo-700')
      } else {
        chip.classList.remove('border-indigo-500', 'bg-indigo-50', 'text-indigo-700')
        chip.classList.add('border-gray-300', 'bg-white', 'text-gray-700', 'hover:border-gray-400')
      }
    })
  }
  
  showPreview(approvalLineId) {
    const approvalLine = window.approvalLinesData && window.approvalLinesData[approvalLineId]
    if (!approvalLine) return
    
    if (this.hasPreviewTarget) {
      // 승인 단계별로 그룹화
      const stepsHTML = this.generateApprovalStepsHTML(approvalLine)
      
      this.previewTarget.innerHTML = `
        <div class="mt-2 p-3 bg-gray-50 border border-gray-200 rounded-lg">
          <h4 class="text-sm font-medium text-gray-700 mb-2">승인 단계</h4>
          <div class="space-y-2">
            ${stepsHTML}
          </div>
        </div>
      `
      this.previewTarget.classList.remove('hidden')
    }
  }
  
  generateApprovalStepsHTML(approvalLine) {
    if (!approvalLine.approvers || approvalLine.approvers.length === 0) {
      return '<p class="text-sm text-gray-500">승인자가 없습니다.</p>'
    }
    
    // approvers를 step_order로 그룹화 (서버에서 이미 정렬되어 있다고 가정)
    const groupedSteps = {}
    approvalLine.approvers.forEach((approver, index) => {
      const stepOrder = approver.step_order || (index + 1)
      if (!groupedSteps[stepOrder]) {
        groupedSteps[stepOrder] = []
      }
      groupedSteps[stepOrder].push(approver)
    })
    
    let html = ''
    Object.keys(groupedSteps).sort((a, b) => a - b).forEach(stepOrder => {
      const steps = groupedSteps[stepOrder]
      const approvers = steps.filter(s => s.role === 'approve')
      
      html += '<div class="text-sm flex items-center">'
      html += `<span class="font-medium text-gray-600 mr-2">${stepOrder}.</span>`
      
      // 전체 합의/단독 가능 표시 (승인자가 2명 이상일 때)
      if (approvers.length >= 2) {
        const approvalType = approvers[0].approval_type || 'any_one'
        const bgClass = approvalType === 'all_required' ? 'bg-purple-100 text-purple-800' : 'bg-green-100 text-green-800'
        const label = approvalType === 'all_required' ? '전체 합의' : '단독 가능'
        html += `<span class="mr-2 inline-flex items-center px-2 py-0.5 rounded text-xs font-medium ${bgClass}">${label}</span>`
      }
      
      steps.forEach((step, index) => {
        if (index > 0) {
          html += '<span class="mx-1 text-gray-300">|</span>'
        }
        
        html += '<span class="text-gray-700">'
        html += step.name
        
        // 최고 우선순위 그룹 표시
        if (step.groups && step.groups.length > 0) {
          const highestGroup = step.groups.reduce((max, g) => 
            (!max || g.priority > max.priority) ? g : max, null)
          if (highestGroup) {
            html += `<span class="text-gray-500">(${highestGroup.name})</span>`
          }
        }
        html += '</span>'
        
        // 승인/참조 구분
        const roleClass = step.role === 'approve' ? 'bg-blue-100 text-blue-700' : 'bg-gray-100 text-gray-600'
        const roleLabel = step.role === 'approve' ? '승인' : '참조'
        html += `<span class="ml-1 inline-flex items-center px-1.5 py-0.5 rounded text-xs font-medium ${roleClass}">${roleLabel}</span>`
      })
      
      html += '</div>'
    })
    
    return html
  }
  
  hidePreview() {
    if (this.hasPreviewTarget) {
      this.previewTarget.classList.add('hidden')
      this.previewTarget.innerHTML = ''
    }
  }
  
  validateApprovalLine(approvalLineId) {
    // 클라이언트 사이드 검증 (결재 없음도 검증 필요)
    const result = this.performClientSideValidation(approvalLineId)
    this.displayValidationResult(result)
  }
  
  performClientSideValidation(approvalLineId) {
    const result = {
      valid: true,
      errors: [],
      warnings: []
    }
    
    if (!window.expenseSheetRulesData || window.expenseSheetRulesData.length === 0) {
      // 규칙이 없으면 모든 결재선이 유효
      return result
    }
    
    // "결재 없음" 선택 시
    if (!approvalLineId) {
      // 경비 시트 총금액 확인
      const totalAmountElement = document.querySelector('[data-total-amount]')
      const totalAmount = totalAmountElement ? parseInt(totalAmountElement.dataset.totalAmount || 0) : 0
      
      // 필요한 승인 그룹 확인
      const requiredGroups = []
      console.log('=== 승인 규칙 평가 시작 (결재 없음 선택) ===')
      window.expenseSheetRulesData.forEach(rule => {
        console.log(`\n규칙 ${rule.id} 평가:`, {
          rule_type: rule.rule_type,
          submitter_group_id: rule.submitter_group_id,
          approver_group: rule.approver_group?.name
        })
        
        // submitter_based 규칙인 경우 사용자가 해당 그룹에 속하는지 먼저 확인
        if (rule.rule_type === 'submitter_based' && rule.submitter_group_id) {
          const userInSubmitterGroup = window.currentUserGroups && 
            window.currentUserGroups.some(g => g.id === rule.submitter_group_id)
          console.log(`  submitter_based 규칙 체크:`)
          console.log(`    - 필요한 제출자 그룹 ID: ${rule.submitter_group_id}`)
          console.log(`    - 사용자가 속한 그룹 IDs:`, window.currentUserGroups?.map(g => g.id))
          console.log(`    - 사용자가 제출자 그룹에 속함?: ${userInSubmitterGroup}`)
          
          // 사용자가 제출자 그룹에 속하지 않으면 이 규칙은 적용하지 않음
          if (!userInSubmitterGroup) {
            console.log(`  → 규칙 건너뜀 (사용자가 제출자 그룹에 속하지 않음)`)
            return
          }
        }
        
        const conditionMet = this.evaluateCondition(rule.condition, { total_amount: totalAmount })
        console.log(`  조건 평가:`)
        console.log(`    - 조건: ${rule.condition}`)
        console.log(`    - 총금액: ${totalAmount}`)
        console.log(`    - 조건 만족?: ${conditionMet}`)
        
        if (conditionMet) {
          // 사용자가 이미 해당 그룹에 속하는지 확인
          const userInGroup = window.currentUserGroups && 
            window.currentUserGroups.some(g => g.id === rule.approver_group.id)
          
          console.log(`  승인자 그룹 체크:`)
          console.log(`    - 필요한 승인자 그룹: ${rule.approver_group.name} (ID: ${rule.approver_group.id})`)
          console.log(`    - 사용자가 이 그룹에 속함?: ${userInGroup}`)
          
          if (!userInGroup && !requiredGroups.find(g => g.id === rule.approver_group.id)) {
            requiredGroups.push(rule.approver_group)
            console.log(`  → 승인 필요 그룹에 추가: ${rule.approver_group.name}`)
          } else if (userInGroup) {
            console.log(`  → 사용자가 이미 속한 그룹이므로 추가하지 않음`)
          }
        }
      })
      
      console.log('=== 승인 규칙 평가 끝 ===')
      console.log('최종 필요한 승인 그룹:', requiredGroups.map(g => g.name))
      
      if (requiredGroups.length > 0) {
        result.valid = false
        const groupNames = requiredGroups
          .sort((a, b) => b.priority - a.priority)
          .map(g => g.name)
          .join(', ')
        result.errors.push(`승인 필요: ${groupNames}`)
      }
      
      return result
    }
    
    const approvalLine = window.approvalLinesData && window.approvalLinesData[approvalLineId]
    if (!approvalLine) {
      result.valid = false
      result.errors.push('유효하지 않은 결재선입니다.')
      return result
    }
    
    // 경비 시트 총금액 계산 (이미 계산된 값 사용)
    const totalAmountElement = document.querySelector('[data-total-amount]')
    const totalAmount = totalAmountElement ? parseInt(totalAmountElement.dataset.totalAmount || 0) : 0
    
    // 각 규칙에 대해 검증
    const missingGroups = []
    const excessiveGroups = []
    
    window.expenseSheetRulesData.forEach(rule => {
      // submitter_based 규칙인 경우 사용자가 해당 그룹에 속하는지 먼저 확인
      if (rule.rule_type === 'submitter_based' && rule.submitter_group_id) {
        const userInSubmitterGroup = window.currentUserGroups && 
          window.currentUserGroups.some(g => g.id === rule.submitter_group_id)
        // 사용자가 제출자 그룹에 속하지 않으면 이 규칙은 적용하지 않음
        if (!userInSubmitterGroup) {
          console.log(`규칙 ${rule.id} 건너뜀 - submitter_based이지만 사용자가 그룹 ${rule.submitter_group_id}에 속하지 않음`)
          return
        }
      }
      
      // 조건 평가 (총금액, 경비코드 등)
      if (this.evaluateCondition(rule.condition, { total_amount: totalAmount })) {
        // 결재선에 필요한 그룹의 승인자가 있는지 확인
        const hasRequiredApprover = this.checkApprovalLineHasGroup(approvalLine, rule.approver_group)
        
        if (!hasRequiredApprover) {
          // 사용자가 이미 해당 그룹에 속하는지 확인
          const userInGroup = window.currentUserGroups && 
            window.currentUserGroups.some(g => g.id === rule.approver_group.id)
          
          if (!userInGroup) {
            missingGroups.push(rule.approver_group)
          }
        }
      }
    })
    
    // 결재선에 있지만 필요하지 않은 그룹 확인
    const requiredGroupIds = window.expenseSheetRulesData
      .filter(rule => {
        // submitter_based 규칙 체크
        if (rule.rule_type === 'submitter_based' && rule.submitter_group_id) {
          const userInSubmitterGroup = window.currentUserGroups && 
            window.currentUserGroups.some(g => g.id === rule.submitter_group_id)
          if (!userInSubmitterGroup) {
            return false
          }
        }
        return this.evaluateCondition(rule.condition, { total_amount: totalAmount })
      })
      .map(rule => rule.approver_group.id)
    
    console.log('필요한 그룹 IDs:', requiredGroupIds)
    console.log('결재선의 승인자들:', approvalLine.approvers)
    
    approvalLine.approvers.forEach(approver => {
      approver.groups.forEach(group => {
        console.log(`  그룹 체크: ${group.name} (ID: ${group.id}), 필요함?: ${requiredGroupIds.includes(group.id)}`)
        if (!requiredGroupIds.includes(group.id)) {
          // 필요하지 않은 그룹이 포함된 경우
          if (!excessiveGroups.find(g => g.id === group.id)) {
            console.log(`    → 불필요한 그룹으로 추가: ${group.name}`)
            excessiveGroups.push(group)
          }
        }
      })
    })
    
    // 중복 제거를 위한 unique 배열 생성
    const uniqueMissingGroups = []
    missingGroups.forEach(group => {
      if (!uniqueMissingGroups.find(g => g.id === group.id)) {
        uniqueMissingGroups.push(group)
      }
    })
    
    const uniqueExcessiveGroups = []
    excessiveGroups.forEach(group => {
      if (!uniqueExcessiveGroups.find(g => g.id === group.id)) {
        uniqueExcessiveGroups.push(group)
      }
    })
    
    // 에러 및 경고 메시지 생성
    if (uniqueMissingGroups.length > 0) {
      result.valid = false
      const groupNames = uniqueMissingGroups
        .sort((a, b) => b.priority - a.priority)
        .map(g => g.name)
        .join(', ')
      result.errors.push(`승인 필요: ${groupNames}`)
    }
    
    if (uniqueExcessiveGroups.length > 0) {
      const groupNames = uniqueExcessiveGroups
        .sort((a, b) => b.priority - a.priority)
        .map(g => g.name)
        .join(', ')
      result.warnings.push(`필수 아님: ${groupNames}`)
      result.warnings.push('제출은 가능하지만, 불필요한 승인 단계가 포함되어 있습니다.')
    }
    
    return result
  }
  
  evaluateCondition(condition, context) {
    if (!condition || condition.trim() === '') {
      return true
    }
    
    const { total_amount = 0 } = context
    
    // #총금액 조건 평가
    if (condition.includes('#총금액')) {
      const match = condition.match(/#총금액\s*([><=]+)\s*(\d+)/)
      if (match) {
        const operator = match[1]
        const threshold = parseInt(match[2])
        
        switch (operator) {
          case '>': return total_amount > threshold
          case '>=': return total_amount >= threshold
          case '<': return total_amount < threshold
          case '<=': return total_amount <= threshold
          case '==': return total_amount === threshold
        }
      }
    }
    
    // #경비코드 조건 평가 - 경비 시트에서는 항상 false
    // 경비 코드는 개별 경비 항목에만 적용되므로 경비 시트 레벨에서는 적용하지 않음
    if (condition.includes('#경비코드')) {
      console.log('경비코드 조건은 경비 시트에 적용되지 않음')
      return false
    }
    
    return true
  }
  
  checkApprovalLineHasGroup(approvalLine, approverGroup) {
    return approvalLine.approvers.some(approver => 
      approver.groups.some(group => 
        group.id === approverGroup.id || group.priority >= approverGroup.priority
      )
    )
  }
  
  displayValidationResult(result) {
    if (!this.hasValidationAreaTarget) return
    
    let html = ''
    
    // 에러 메시지 표시
    if (result.errors && result.errors.length > 0) {
      html += `
        <div class="mt-3 p-3 bg-red-50 border border-red-200 rounded-md">
          <div class="flex items-start gap-2">
            <svg class="h-4 w-4 text-red-600 mt-0.5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
            </svg>
            <div class="text-sm text-red-800">
              ${result.errors.map(error => {
                // "승인 필요:" 형식 처리
                if (error.includes('승인 필요:')) {
                  const parts = error.split(':')
                  return `<p><span class="font-semibold">${parts[0]}:</span>${parts.slice(1).join(':')}</p>`
                }
                return `<p>${error}</p>`
              }).join('')}
            </div>
          </div>
        </div>
      `
      this.disableSubmitButton()
    } else {
      // 성공 시에는 아무것도 표시하지 않음
      this.enableSubmitButton()
    }
    
    // 경고 메시지 표시
    if (result.warnings && result.warnings.length > 0) {
      html += `
        <div class="mt-3 p-3 bg-yellow-50 border border-yellow-200 rounded-md">
          <div class="flex items-start gap-2">
            <svg class="h-4 w-4 text-yellow-600 mt-0.5 flex-shrink-0" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 9v2m0 4h.01m-6.938 4h13.856c1.54 0 2.502-1.667 1.732-3L13.732 4c-.77-1.333-2.694-1.333-3.464 0L3.34 16c-.77 1.333.192 3 1.732 3z" />
            </svg>
            <div class="text-sm text-yellow-800">
              ${result.warnings.map(warning => {
                // "필수 아님:" 형식 처리
                if (warning.includes('필수 아님:')) {
                  const parts = warning.split(':')
                  return `<p><span class="font-semibold">${parts[0]}:</span>${parts.slice(1).join(':')}</p>`
                }
                return `<p>${warning}</p>`
              }).join('')}
            </div>
          </div>
        </div>
      `
    }
    
    this.validationAreaTarget.innerHTML = html
  }
  
  clearValidation() {
    if (this.hasValidationAreaTarget) {
      this.validationAreaTarget.innerHTML = ''
    }
    this.disableSubmitButton()
  }
  
  enableSubmitButton() {
    console.log('=== enableSubmitButton 호출됨 ===')
    const submitButton = document.getElementById('expense-sheet-submit-button')
    
    if (!submitButton) {
      console.log('❌ 제출 버튼을 찾을 수 없습니다')
      return
    }
    
    console.log('버튼 element:', submitButton)
    console.log('버튼 dataset 전체:', submitButton.dataset)
    
    // 1. AI 검증이 완료되었는지 체크 (data attribute로 전달)
    // data-ai-validated가 data-ai_validated로 변환될 수도 있음
    const aiValidated = submitButton.dataset.aiValidated === 'true' || 
                       submitButton.dataset.ai_validated === 'true'
    
    console.log('AI validated raw value:', submitButton.dataset.aiValidated)
    console.log('AI validated 체크 결과:', aiValidated)
    
    // 2. 결재선 검증이 통과했는지 체크 (현재 메서드 호출 컨텍스트에서 이미 확인됨)
    const approvalLineValid = true // displayValidationResult에서 에러가 없을 때만 호출됨
    
    // 3. 선택된 결재선 ID 가져오기
    const selectedRadio = document.querySelector('input[name="selected_approval_line_id"]:checked')
    const selectedApprovalLineId = selectedRadio?.value || ""
    
    console.log('선택된 radio element:', selectedRadio)
    console.log('제출 버튼 활성화 체크:', {
      aiValidated,
      approvalLineValid,
      selectedApprovalLineId: selectedApprovalLineId || '결재 없음'
    })
    
    if (aiValidated && approvalLineValid) {
      console.log('조건 충족 - 버튼 활성화 시작')
      submitButton.disabled = false
      submitButton.classList.remove('opacity-50', 'cursor-not-allowed')
      console.log('버튼 disabled 상태:', submitButton.disabled)
      console.log('버튼 클래스:', submitButton.className)
      
      // hidden field 업데이트 - ID로 직접 찾기
      const hiddenField = document.getElementById('expense_sheet_approval_line_id') || 
                         document.querySelector('[data-expense-sheet-approval-target="approvalLineField"]')
      if (hiddenField) {
        hiddenField.value = selectedApprovalLineId
        console.log('Hidden field 업데이트:', selectedApprovalLineId || '빈 값')
        console.log('Hidden field element:', hiddenField)
        console.log('Hidden field name:', hiddenField.name)
      } else {
        console.log('⚠️ Hidden field를 찾을 수 없음')
      }
      
      console.log('✅ 제출 버튼 활성화 완료')
    } else {
      console.log('조건 미충족 - 버튼 비활성화')
      this.disableSubmitButton()
      console.log('❌ 제출 버튼 비활성화: AI 검증=' + aiValidated + ', 결재선 유효=' + approvalLineValid)
    }
  }
  
  disableSubmitButton() {
    const submitButton = document.getElementById('expense-sheet-submit-button')
    if (submitButton) {
      submitButton.disabled = true
      submitButton.classList.add('opacity-50', 'cursor-not-allowed')
      console.log('제출 버튼 비활성화')
    }
  }
}