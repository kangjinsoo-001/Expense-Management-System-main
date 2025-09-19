import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["fullText"]
  static values = { 
    id: Number,
    status: String
  }
  
  connect() {
    // 상태가 processing인 경우 주기적으로 상태 체크
    if (this.statusValue === 'processing' || this.statusValue === 'uploading') {
      this.startStatusPolling()
    }
  }
  
  disconnect() {
    if (this.pollInterval) {
      clearInterval(this.pollInterval)
    }
  }
  
  startStatusPolling() {
    this.pollInterval = setInterval(() => {
      this.checkStatus()
    }, 2000) // 2초마다 체크
  }
  
  async checkStatus() {
    try {
      const response = await fetch(`/expense_attachments/${this.idValue}/status`, {
        headers: {
          'Accept': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        }
      })
      
      if (response.ok) {
        const data = await response.json()
        
        // 상태가 변경되었으면
        if (data.status !== this.statusValue) {
          this.statusValue = data.status
          
          // 완료 또는 실패 상태면 폴링 중지
          if (data.status === 'completed' || data.status === 'failed') {
            clearInterval(this.pollInterval)
            
            // Turbo를 사용하여 해당 부분만 업데이트
            // 서버에서 turbo_stream으로 업데이트를 보내도록 할 수도 있음
            location.reload() // 임시로 페이지 리로드
          }
        }
      }
    } catch (error) {
      console.error('Status check failed:', error)
    }
  }
  
  toggleFullText(event) {
    event.preventDefault()
    
    if (this.hasFullTextTarget) {
      this.fullTextTarget.classList.toggle('hidden')
      
      const button = event.target
      if (this.fullTextTarget.classList.contains('hidden')) {
        button.textContent = '전체 보기'
      } else {
        button.textContent = '접기'
      }
    }
  }
}