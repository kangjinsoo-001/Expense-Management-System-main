import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["submit"]

  connect() {
    console.log("Form controller connected")
  }

  // 엔터키로 인한 자동 제출 방지
  preventEnterSubmit(event) {
    if (event.key === 'Enter' && event.target.tagName !== 'TEXTAREA') {
      event.preventDefault()
      
      // 탭키처럼 다음 입력 필드로 이동
      const formElements = Array.from(this.element.elements).filter(el => 
        !el.disabled && (el.tagName === 'INPUT' || el.tagName === 'SELECT' || el.tagName === 'TEXTAREA')
      )
      
      const currentIndex = formElements.indexOf(event.target)
      if (currentIndex < formElements.length - 1) {
        formElements[currentIndex + 1].focus()
      }
    }
  }

  // 명시적 제출 (버튼 클릭 시)
  submit(event) {
    event.preventDefault()
    
    // 제출 버튼 비활성화 (중복 제출 방지)
    if (this.hasSubmitTarget) {
      this.submitTarget.disabled = true
      this.submitTarget.textContent = "저장 중..."
    }
    
    // 폼 제출
    this.element.requestSubmit()
  }
}