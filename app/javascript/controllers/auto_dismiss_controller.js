import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { delay: Number }
  
  connect() {
    // 기본 3초 후 자동 사라짐
    const delay = this.hasDelayValue ? this.delayValue : 3000
    
    setTimeout(() => {
      this.dismiss()
    }, delay)
  }
  
  dismiss() {
    // 페이드 아웃 애니메이션
    this.element.style.transition = "opacity 0.3s ease-out"
    this.element.style.opacity = "0"
    
    // 애니메이션 완료 후 요소 제거
    setTimeout(() => {
      this.element.remove()
    }, 300)
  }
}