import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { timeout: Number }
  
  connect() {
    // data-turbo-temporary 속성이 있는 flash 메시지는 자동 제거
    if (this.element.dataset.turboTemporary) {
      const timeout = this.hasTimeoutValue ? this.timeoutValue : 5000
      setTimeout(() => {
        this.remove()
      }, timeout)
    }
  }

  remove() {
    // 페이드 아웃 애니메이션
    this.element.style.transition = "opacity 0.5s ease-out"
    this.element.style.opacity = "0"
    
    setTimeout(() => {
      this.element.remove()
    }, 500)
  }

  // 사용자가 X 버튼을 클릭했을 때
  close(event) {
    event.preventDefault()
    this.remove()
  }
}