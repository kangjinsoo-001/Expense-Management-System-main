// 결재선 검증 헬퍼 - 클라이언트 사이드 검증 로직
export class ApprovalValidationHelper {
  constructor(expenseCodesData, approvalLinesData, currentUserGroups) {
    this.expenseCodesData = expenseCodesData || {}
    this.approvalLinesData = approvalLinesData || {}
    this.currentUserGroups = currentUserGroups || []
  }

  // 조건식 평가
  evaluateCondition(condition, context) {
    if (!condition || condition.trim() === '') {
      return true // 조건이 없으면 항상 적용
    }

    try {
      // 컨텍스트 변수 추출
      const { amount = 0, budget_amount = 0, is_budget = false } = context
      
      // NaN 처리 및 금액 계산
      let evalAmount = is_budget ? (budget_amount || 0) : (amount || 0)
      evalAmount = isNaN(evalAmount) ? 0 : evalAmount

      // #금액 > 100000 형식 (한글 라벨 기반)
      if (condition.match(/#금액\s*>\s*(\d+)/)) {
        const threshold = parseInt(condition.match(/#금액\s*>\s*(\d+)/)[1])
        return evalAmount > threshold
      }

      // #금액 < 100000 형식
      if (condition.match(/#금액\s*<\s*(\d+)/)) {
        const threshold = parseInt(condition.match(/#금액\s*<\s*(\d+)/)[1])
        return evalAmount < threshold
      }

      // #금액 >= 100000 형식
      if (condition.match(/#금액\s*>=\s*(\d+)/)) {
        const threshold = parseInt(condition.match(/#금액\s*>=\s*(\d+)/)[1])
        return evalAmount >= threshold
      }

      // #금액 <= 100000 형식
      if (condition.match(/#금액\s*<=\s*(\d+)/)) {
        const threshold = parseInt(condition.match(/#금액\s*<=\s*(\d+)/)[1])
        return evalAmount <= threshold
      }

      // #금액 == 100000 형식
      if (condition.match(/#금액\s*==\s*(\d+)/)) {
        const threshold = parseInt(condition.match(/#금액\s*==\s*(\d+)/)[1])
        return evalAmount === threshold
      }

      // amount > 100000 형식 (영문 변수명 - 하위 호환성)
      if (condition.match(/amount\s*>\s*(\d+)/)) {
        const threshold = parseInt(condition.match(/amount\s*>\s*(\d+)/)[1])
        return evalAmount > threshold
      }

      // amount < 100000 형식
      if (condition.match(/amount\s*<\s*(\d+)/)) {
        const threshold = parseInt(condition.match(/amount\s*<\s*(\d+)/)[1])
        return evalAmount < threshold
      }

      // amount >= 100000 형식
      if (condition.match(/amount\s*>=\s*(\d+)/)) {
        const threshold = parseInt(condition.match(/amount\s*>=\s*(\d+)/)[1])
        return evalAmount >= threshold
      }

      // amount <= 100000 형식
      if (condition.match(/amount\s*<=\s*(\d+)/)) {
        const threshold = parseInt(condition.match(/amount\s*<=\s*(\d+)/)[1])
        return evalAmount <= threshold
      }

      // amount == 100000 형식
      if (condition.match(/amount\s*==\s*(\d+)/)) {
        const threshold = parseInt(condition.match(/amount\s*==\s*(\d+)/)[1])
        return evalAmount === threshold
      }

      // between 형식
      if (condition.match(/amount\s+between\s+(\d+)\s+and\s+(\d+)/i)) {
        const matches = condition.match(/amount\s+between\s+(\d+)\s+and\s+(\d+)/i)
        const min = parseInt(matches[1])
        const max = parseInt(matches[2])
        return evalAmount >= min && evalAmount <= max
      }

      // is_budget 관련 조건
      if (condition.match(/is_budget\s*==\s*true/i)) {
        return is_budget === true
      }

      if (condition.match(/is_budget\s*==\s*false/i)) {
        return is_budget === false
      }

      // 기본값 - 파싱할 수 없는 조건은 false
      console.warn(`파싱할 수 없는 조건식: ${condition}`)
      return false

    } catch (error) {
      console.error('조건식 평가 오류:', error)
      return false
    }
  }

  // 경비 코드의 승인 규칙 가져오기
  getApprovalRules(expenseCodeId, context) {
    const expenseCode = this.expenseCodesData[expenseCodeId]
    if (!expenseCode || !expenseCode.approval_rules) {
      return []
    }

    // 조건을 평가하여 적용되는 규칙만 필터링
    return expenseCode.approval_rules.filter(rule => {
      return this.evaluateCondition(rule.condition, context)
    })
  }

  // 결재선이 승인 규칙을 충족하는지 확인
  validateApprovalLine(expenseCodeId, approvalLineId, context) {
    const result = {
      valid: true,
      errors: [],
      warnings: [],
      info: []
    }

    // 경비 코드 확인
    const expenseCode = this.expenseCodesData[expenseCodeId]
    if (!expenseCode) {
      return result // 경비 코드가 없으면 검증 건너뛰기
    }

    // 적용되는 승인 규칙 가져오기
    const applicableRules = this.getApprovalRules(expenseCodeId, context)
    
    if (applicableRules.length === 0) {
      // 승인 규칙이 없으면 결재선 선택은 자유
      return result
    }

    // 결재선 확인
    if (!approvalLineId || approvalLineId === '') {
      // 승인 규칙이 있는데 결재선이 없음 - 필요한 그룹들을 우선순위 순으로 정렬
      result.valid = false
      
      const requiredGroups = applicableRules.map(rule => ({
        name: rule.approver_group ? rule.approver_group.name : rule.group_name,
        priority: rule.approver_group ? rule.approver_group.priority : rule.group_priority
      }))
      
      // 우선순위 높은 순으로 정렬 (내림차순)
      requiredGroups.sort((a, b) => b.priority - a.priority)
      
      // 하나의 통합된 에러 메시지만 생성
      const groupNames = requiredGroups.map(g => g.name).join(', ')
      result.errors.push(`승인 필요: ${groupNames}`)
      
      return result
    }

    // 선택된 결재선 정보
    const approvalLine = this.approvalLinesData[approvalLineId]
    if (!approvalLine) {
      result.valid = false
      result.errors.push('유효하지 않은 결재선입니다.')
      return result
    }

    // 각 승인 규칙에 대해 충족 여부 확인
    const missingGroups = []
    const userSatisfiedGroups = []
    const excessiveGroups = []

    // 필요한 최대 권한 레벨 계산
    const requiredMaxPriority = Math.max(...applicableRules.map(rule => 
      rule.approver_group ? rule.approver_group.priority : rule.group_priority
    ), 0)

    applicableRules.forEach(rule => {
      // 현재 사용자가 이미 필요한 권한을 가지고 있는지 확인
      const userMaxPriority = Math.max(...this.currentUserGroups.map(g => g.priority || 0), 0)
      
      const groupPriority = rule.approver_group ? rule.approver_group.priority : rule.group_priority
      const groupName = rule.approver_group ? rule.approver_group.name : rule.group_name
      
      if (userMaxPriority >= groupPriority) {
        // 사용자가 이미 충분한 권한을 가지고 있음
        userSatisfiedGroups.push({name: groupName, priority: groupPriority})
      } else {
        // 결재선에 필요한 그룹의 승인자가 있는지 확인
        const hasRequiredApprover = this.checkApprovalLineHasGroup(approvalLine, rule)
        
        if (!hasRequiredApprover) {
          missingGroups.push({name: groupName, priority: groupPriority})
        }
      }
    })

    // 과도한 결재선 체크 - 필요한 것보다 높은 권한의 승인자들 찾기
    if (approvalLine.steps) {
      approvalLine.steps.forEach(step => {
        step.approvers.forEach(approver => {
          if (approver.role === 'approve' && approver.groups && approver.groups.length > 0) {
            const approverMaxPriority = Math.max(...approver.groups.map(g => g.priority || 0), 0)
            
            // 필요한 최대 권한보다 높은 권한을 가진 승인자
            if (approverMaxPriority > requiredMaxPriority) {
              const highestGroup = approver.groups.find(g => g.priority === approverMaxPriority)
              if (highestGroup && !excessiveGroups.some(g => g.name === highestGroup.name)) {
                excessiveGroups.push({
                  name: highestGroup.name,
                  priority: highestGroup.priority
                })
              }
            }
          }
        })
      })
    }

    // 검증 결과 설정
    if (missingGroups.length > 0) {
      result.valid = false
      // 우선순위 높은 순으로 정렬
      missingGroups.sort((a, b) => b.priority - a.priority)
      const groupNames = missingGroups.map(g => g.name).join(', ')
      result.errors.push(`승인 필요: ${groupNames}`)
    }

    // 과도한 결재선 경고
    if (excessiveGroups.length > 0) {
      // 우선순위 높은 순으로 정렬
      excessiveGroups.sort((a, b) => b.priority - a.priority)
      const groupNames = excessiveGroups.map(g => g.name).join(', ')
      result.warnings.push(`필수 아님: ${groupNames}`)
      result.warnings.push('제출은 가능하지만, 불필요한 승인 단계가 포함되어 있습니다.')
    }

    // 사용자가 이미 충족한 그룹 정보 (정보성)
    if (userSatisfiedGroups.length > 0) {
      // 우선순위 높은 순으로 정렬
      userSatisfiedGroups.sort((a, b) => b.priority - a.priority)
      const groupNames = userSatisfiedGroups.map(g => g.name).join(', ')
      result.info.push(`귀하는 이미 ${groupNames} 권한을 보유하고 있습니다.`)
    }

    // 한도 체크
    if (expenseCode.limit_amount) {
      const amount = context.is_budget ? (context.budget_amount || 0) : (context.amount || 0)
      if (amount > expenseCode.limit_amount) {
        result.warnings.push(`경비 한도(${this.formatCurrency(expenseCode.limit_amount)})를 초과했습니다.`)
      }
    }

    return result
  }

  // 결재선에 특정 그룹의 승인자가 있는지 확인
  checkApprovalLineHasGroup(approvalLine, rule) {
    if (!approvalLine.steps) return false

    // 결재선의 모든 승인자 확인
    for (const step of approvalLine.steps) {
      for (const approver of step.approvers) {
        // 승인 역할인 경우만 체크
        if (approver.role !== 'approve') continue

        // 승인자의 그룹 확인
        if (approver.groups && approver.groups.length > 0) {
          // 최고 우선순위 그룹 확인
          const maxPriority = Math.max(...approver.groups.map(g => g.priority || 0), 0)
          
          // 위계 체크: 승인자의 최고 권한이 요구되는 권한 이상인지
          const requiredPriority = rule.approver_group ? rule.approver_group.priority : rule.group_priority
          if (maxPriority >= requiredPriority) {
            return true
          }
        }
      }
    }

    return false
  }

  // 금액 포맷팅
  formatCurrency(amount) {
    return new Intl.NumberFormat('ko-KR', {
      style: 'currency',
      currency: 'KRW'
    }).format(amount)
  }

  // 검증 메시지 생성
  generateValidationMessage(expenseCodeId, context) {
    const messages = []
    const applicableRules = this.getApprovalRules(expenseCodeId, context)

    applicableRules.forEach(rule => {
      const groupName = rule.approver_group ? rule.approver_group.name : rule.group_name
      
      if (rule.condition && rule.condition.trim() !== '') {
        // 조건부 규칙
        if (rule.condition.includes('amount') || rule.condition.includes('#금액')) {
          messages.push(this.generateAmountMessage(rule, context))
        } else if (rule.condition.includes('is_budget')) {
          messages.push(`예산 항목인 경우 ${groupName} 승인이 필요합니다.`)
        } else {
          messages.push(`${groupName} 승인이 필요합니다.`)
        }
      } else {
        // 무조건 규칙
        messages.push(`이 경비 코드는 항상 ${groupName} 승인이 필요합니다.`)
      }
    })

    return messages
  }

  // 금액 관련 메시지 생성
  generateAmountMessage(rule, context) {
    const condition = rule.condition
    const groupName = rule.approver_group ? rule.approver_group.name : rule.group_name
    
    // #금액 또는 amount 모두 처리
    if (condition.match(/(#금액|amount)\s*>\s*(\d+)/)) {
      const threshold = parseInt(condition.match(/(#금액|amount)\s*>\s*(\d+)/)[2])
      return `금액이 ${this.formatCurrency(threshold)}을 초과하면 ${groupName} 승인이 필요합니다.`
    }
    
    if (condition.match(/(#금액|amount)\s*<\s*(\d+)/)) {
      const threshold = parseInt(condition.match(/(#금액|amount)\s*<\s*(\d+)/)[2])
      return `금액이 ${this.formatCurrency(threshold)} 미만이면 ${groupName} 승인이 필요합니다.`
    }
    
    if (condition.match(/(#금액|amount)\s*>=\s*(\d+)/)) {
      const threshold = parseInt(condition.match(/(#금액|amount)\s*>=\s*(\d+)/)[2])
      return `금액이 ${this.formatCurrency(threshold)} 이상이면 ${groupName} 승인이 필요합니다.`
    }
    
    if (condition.match(/(#금액|amount)\s*<=\s*(\d+)/)) {
      const threshold = parseInt(condition.match(/(#금액|amount)\s*<=\s*(\d+)/)[2])
      return `금액이 ${this.formatCurrency(threshold)} 이하이면 ${groupName} 승인이 필요합니다.`
    }
    
    if (condition.match(/between\s+(\d+)\s+and\s+(\d+)/i)) {
      const matches = condition.match(/between\s+(\d+)\s+and\s+(\d+)/i)
      const min = parseInt(matches[1])
      const max = parseInt(matches[2])
      return `금액이 ${this.formatCurrency(min)} ~ ${this.formatCurrency(max)} 범위면 ${groupName} 승인이 필요합니다.`
    }
    
    return `${groupName} 승인이 필요합니다.`
  }
}