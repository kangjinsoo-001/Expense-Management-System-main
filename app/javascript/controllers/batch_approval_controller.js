import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["selectAll", "checkbox", "approveButton"]

  connect() {
    // approveButton이 없을 수도 있으므로 안전하게 처리
    if (this.hasApproveButtonTarget) {
      this.updateButtonState()
    }
  }

  toggleAll() {
    const isChecked = this.selectAllTarget.checked
    // 현재 보이는 체크박스만 선택
    const visibleCheckboxes = this.checkboxTargets.filter(checkbox => {
      const parent = checkbox.closest('.md\\:hidden, .md\\:block')
      if (!parent) return true
      
      const isMobile = window.innerWidth < 768
      if (parent.classList.contains('md:hidden')) {
        return isMobile
      } else if (parent.classList.contains('md:block')) {
        return !isMobile
      }
      return true
    })
    
    visibleCheckboxes.forEach(checkbox => {
      checkbox.checked = isChecked
    })
    this.updateButtonState()
  }

  updateButtonState() {
    // approveButton이 없으면 처리하지 않음
    if (!this.hasApproveButtonTarget) {
      return
    }
    
    // 현재 보이는 체크박스만 선택 (hidden 클래스가 없는 부모 요소의 체크박스)
    const visibleCheckboxes = this.checkboxTargets.filter(checkbox => {
      // 체크박스가 포함된 가장 가까운 .hidden 또는 .md:hidden, .md:block 요소를 찾음
      const parent = checkbox.closest('.md\\:hidden, .md\\:block')
      if (!parent) return true
      
      // 화면 크기에 따라 실제로 보이는지 확인
      const isMobile = window.innerWidth < 768
      if (parent.classList.contains('md:hidden')) {
        return isMobile // 모바일에서만 보임
      } else if (parent.classList.contains('md:block')) {
        return !isMobile // 데스크톱에서만 보임
      }
      return true
    })
    
    const checkedBoxes = visibleCheckboxes.filter(checkbox => checkbox.checked)
    const hasSelection = checkedBoxes.length > 0
    
    this.approveButtonTarget.disabled = !hasSelection
    
    // 버튼 텍스트 업데이트
    if (hasSelection) {
      this.approveButtonTarget.textContent = `선택 항목 일괄 승인 (${checkedBoxes.length}건)`
    } else {
      this.approveButtonTarget.textContent = '선택 항목 일괄 승인'
    }
    
    // 전체 선택 체크박스 상태 업데이트
    if (this.hasSelectAllTarget) {
      const allChecked = visibleCheckboxes.length > 0 && 
                         visibleCheckboxes.every(checkbox => checkbox.checked)
      const someChecked = visibleCheckboxes.some(checkbox => checkbox.checked)
      
      this.selectAllTarget.checked = allChecked
      this.selectAllTarget.indeterminate = someChecked && !allChecked
    }
  }

  async approveSelected() {
    // 현재 보이는 체크박스 중 체크된 것만 선택
    const visibleCheckboxes = this.checkboxTargets.filter(checkbox => {
      const parent = checkbox.closest('.md\\:hidden, .md\\:block')
      if (!parent) return true
      
      const isMobile = window.innerWidth < 768
      if (parent.classList.contains('md:hidden')) {
        return isMobile
      } else if (parent.classList.contains('md:block')) {
        return !isMobile
      }
      return true
    })
    
    const checkedBoxes = visibleCheckboxes.filter(checkbox => checkbox.checked)
    const approvalIds = checkedBoxes.map(checkbox => checkbox.dataset.approvalId)
    
    if (approvalIds.length === 0) {
      alert('승인할 항목을 선택해주세요.')
      return
    }
    
    if (!confirm(`선택한 ${approvalIds.length}건을 모두 승인하시겠습니까?`)) {
      return
    }
    
    try {
      // 버튼 비활성화 및 로딩 상태 표시
      this.approveButtonTarget.disabled = true
      const originalText = this.approveButtonTarget.textContent
      this.approveButtonTarget.textContent = '처리 중...'
      
      // 일괄 승인 요청 보내기
      const token = document.querySelector('meta[name="csrf-token"]').content
      
      const response = await fetch('/approvals/batch_approve', {
        method: 'POST',
        headers: {
          'X-CSRF-Token': token,
          'Content-Type': 'application/json',
          'Accept': 'application/json'
        },
        body: JSON.stringify({ approval_ids: approvalIds })
      })
      
      const data = await response.json()
      
      if (response.ok && data.success) {
        // 성공 메시지 표시
        if (data.failed_count > 0) {
          alert(`${data.success_count}건 승인 완료, ${data.failed_count}건 실패\n\n실패 사유:\n${data.errors.join('\n')}`)
        } else {
          alert(data.message)
        }
        // 페이지 새로고침
        window.location.reload()
      } else {
        // 에러 메시지 표시
        const errorMessage = data.errors && data.errors.length > 0 
          ? `${data.message}\n\n상세 오류:\n${data.errors.join('\n')}` 
          : data.message || '승인 처리 중 오류가 발생했습니다.'
        alert(errorMessage)
        
        // 버튼 원상복구
        this.approveButtonTarget.disabled = false
        this.approveButtonTarget.textContent = originalText
      }
      
    } catch (error) {
      console.error('Batch approval error:', error)
      alert('승인 처리 중 오류가 발생했습니다. 네트워크 연결을 확인해주세요.')
      
      // 버튼 원상복구
      this.approveButtonTarget.disabled = false
      this.updateButtonState()
    }
  }
}