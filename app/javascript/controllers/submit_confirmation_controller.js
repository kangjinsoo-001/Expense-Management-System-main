import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { 
    url: String,
    validateUrl: String 
  }

  connect() {
    this.modal = document.getElementById('submit_confirmation_modal')
    this.confirmButton = document.getElementById('confirm_submit_button')
    this.cancelButton = document.getElementById('cancel_submit_button')
    
    if (this.confirmButton) {
      this.confirmButton.addEventListener('click', () => this.submit())
    }
    
    if (this.cancelButton) {
      this.cancelButton.addEventListener('click', () => this.close())
    }
  }

  async open() {
    // 먼저 검증 상태를 확인
    await this.validateItems()
    
    // 모달 표시
    this.modal.classList.remove('hidden')
  }

  close() {
    this.modal.classList.add('hidden')
  }

  async validateItems() {
    try {
      const response = await fetch(this.validateUrlValue, {
        headers: {
          'Accept': 'application/json'
        }
      })
      
      if (response.ok) {
        const data = await response.json()
        
        // 검증 결과 표시
        const resultDiv = document.getElementById('validation_result')
        document.getElementById('total_items').textContent = data.total_count
        document.getElementById('valid_items').textContent = data.valid_count
        document.getElementById('invalid_items').textContent = data.invalid_count
        
        resultDiv.classList.remove('hidden')
        
        // 유효하지 않은 항목이 있으면 제출 버튼 비활성화
        if (!data.all_valid) {
          this.confirmButton.disabled = true
          this.confirmButton.textContent = '검증이 필요한 항목이 있습니다'
        } else if (data.total_count === 0) {
          this.confirmButton.disabled = true
          this.confirmButton.textContent = '경비 항목이 없습니다'
        } else {
          this.confirmButton.disabled = false
          this.confirmButton.textContent = '제출'
        }
      }
    } catch (error) {
      console.error('검증 중 오류 발생:', error)
    }
  }

  async submit() {
    this.confirmButton.disabled = true
    this.confirmButton.textContent = '제출 중...'
    
    try {
      const response = await fetch(this.urlValue, {
        method: 'POST',
        headers: {
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content,
          'Accept': 'text/vnd.turbo-stream.html, text/html'
        }
      })
      
      if (response.ok) {
        // Turbo가 자동으로 리디렉션 처리
        this.close()
      } else {
        this.confirmButton.disabled = false
        this.confirmButton.textContent = '제출'
        alert('제출 중 오류가 발생했습니다.')
      }
    } catch (error) {
      console.error('제출 중 오류 발생:', error)
      this.confirmButton.disabled = false
      this.confirmButton.textContent = '제출'
    }
  }

  disconnect() {
    if (this.confirmButton) {
      this.confirmButton.removeEventListener('click', () => this.submit())
    }
    
    if (this.cancelButton) {
      this.cancelButton.removeEventListener('click', () => this.close())
    }
  }
}