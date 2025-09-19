import { Controller } from "@hotwired/stimulus"

// 경비 마감 대시보드 컨트롤러
export default class extends Controller {
  static targets = ["statusFilter", "searchInput", "selectAllCheckbox", "statusCheckbox", "selectedCount"]
  
  connect() {
    console.log("Closing dashboard controller connected")
    this.updateSelectedCount()
  }
  
  // 구성원 목록 새로고침
  refreshMembers(event) {
    event.preventDefault()
    
    // Turbo Frame 새로고침
    const memberStatusFrame = document.getElementById('member_statuses')
    if (memberStatusFrame && memberStatusFrame.src) {
      // src를 다시 설정하여 새로고침
      const currentSrc = memberStatusFrame.src
      memberStatusFrame.src = currentSrc
    }
  }
  
  // 상태별 필터링
  filterByStatus(event) {
    const status = event.currentTarget.value
    this.applyFilters()
  }
  
  // 검색
  searchMembers(event) {
    // 디바운싱을 위해 타이머 사용
    clearTimeout(this.searchTimeout)
    this.searchTimeout = setTimeout(() => {
      this.applyFilters()
    }, 300)
  }
  
  // 필터 적용
  applyFilters() {
    const url = new URL(window.location.href)
    const baseUrl = url.pathname
    
    // 현재 파라미터 가져오기
    const params = new URLSearchParams(url.search)
    
    // 상태 필터
    if (this.hasStatusFilterTarget) {
      const statusFilter = this.statusFilterTarget.value
      if (statusFilter) {
        params.set('status_filter', statusFilter)
      } else {
        params.delete('status_filter')
      }
    }
    
    // 검색어
    if (this.hasSearchInputTarget) {
      const search = this.searchInputTarget.value.trim()
      if (search) {
        params.set('search', search)
      } else {
        params.delete('search')
      }
    }
    
    // Turbo Frame으로 구성원 목록 업데이트
    const memberStatusFrame = document.getElementById('member_statuses')
    if (memberStatusFrame) {
      const organizationId = params.get('organization_id')
      const year = params.get('year') || new Date().getFullYear()
      const month = params.get('month') || new Date().getMonth() + 1
      
      // organization_members 액션 URL 생성
      const membersUrl = `/admin/closing/dashboard/organization_members?${params.toString()}`
      memberStatusFrame.src = membersUrl
    }
  }
  
  // 전체 선택/해제
  toggleAllCheckboxes(event) {
    const isChecked = event.currentTarget.checked
    
    this.statusCheckboxTargets.forEach(checkbox => {
      checkbox.checked = isChecked
    })
    
    this.updateSelectedCount()
  }
  
  // 개별 체크박스 변경 시
  checkboxChanged(event) {
    this.updateSelectedCount()
  }
  
  // 선택된 개수 업데이트
  updateSelectedCount() {
    const selectedCount = this.getSelectedStatusIds().length
    
    if (this.hasSelectedCountTarget) {
      if (selectedCount > 0) {
        this.selectedCountTarget.textContent = `(${selectedCount}건)`
      } else {
        this.selectedCountTarget.textContent = ''
      }
    }
  }
  
  // 일괄 마감 모달 열기
  openBatchCloseModal(event) {
    event.preventDefault()
    
    const selectedIds = this.getSelectedStatusIds()
    
    if (selectedIds.length === 0) {
      alert('마감할 항목을 선택해주세요.')
      return
    }
    
    if (confirm(`선택한 ${selectedIds.length}건의 경비를 마감하시겠습니까?`)) {
      this.performBatchClose(selectedIds)
    }
  }
  
  
  // 선택된 상태 ID 가져오기
  getSelectedStatusIds() {
    const selectedCheckboxes = this.statusCheckboxTargets.filter(checkbox => checkbox.checked)
    return selectedCheckboxes.map(checkbox => checkbox.dataset.statusId)
  }
  
  // 일괄 마감 처리
  async performBatchClose(statusIds) {
    const url = new URL(window.location.href)
    const params = new URLSearchParams(url.search)
    
    const formData = new FormData()
    statusIds.forEach(id => {
      formData.append('status_ids[]', id)
    })
    
    // 필수 파라미터들 추가
    formData.append('organization_id', params.get('organization_id'))
    formData.append('year', params.get('year'))
    formData.append('month', params.get('month'))
    
    // include_descendants 파라미터도 추가 (있는 경우)
    if (params.has('include_descendants')) {
      formData.append('include_descendants', params.get('include_descendants'))
    }
    
    try {
      const response = await fetch('/admin/closing/dashboard/batch_close', {
        method: 'POST',
        headers: {
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content,
          'Accept': 'text/vnd.turbo-stream.html'
        },
        body: formData
      })
      
      if (response.ok) {
        const turboStream = await response.text()
        Turbo.renderStreamMessage(turboStream)
        // Turbo Stream이 모든 업데이트를 처리 (Rails Way)
      } else {
        alert('마감 처리 중 오류가 발생했습니다.')
      }
    } catch (error) {
      console.error('Batch close error:', error)
      alert('마감 처리 중 오류가 발생했습니다.')
    }
  }
  
}