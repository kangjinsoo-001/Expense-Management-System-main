import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="progress-animation"
export default class extends Controller {
  static targets = [ "bar" ]
  
  connect() {
    // 프로그레스 바가 있는 경우 애니메이션 실행
    if (this.hasBarTarget) {
      this.animateProgress()
    }
  }
  
  animateProgress() {
    const percentage = this.barTarget.dataset.progressPercentage
    
    // 초기값을 0으로 설정
    this.barTarget.style.width = '0%'
    
    // 약간의 지연 후 애니메이션 시작
    setTimeout(() => {
      this.barTarget.style.width = `${percentage}%`
    }, 100)
    
    // 숫자 카운트 애니메이션 (선택사항)
    const percentageDisplay = this.element.querySelector('[data-progress-percentage-display]')
    if (percentageDisplay) {
      this.animateNumber(percentageDisplay, 0, parseInt(percentage), 1000)
    }
  }
  
  animateNumber(element, start, end, duration) {
    const startTime = performance.now()
    
    const updateNumber = (currentTime) => {
      const elapsed = currentTime - startTime
      const progress = Math.min(elapsed / duration, 1)
      
      const current = Math.floor(start + (end - start) * this.easeOutQuad(progress))
      element.textContent = `${current}%`
      
      if (progress < 1) {
        requestAnimationFrame(updateNumber)
      }
    }
    
    requestAnimationFrame(updateNumber)
  }
  
  // 이징 함수
  easeOutQuad(t) {
    return t * (2 - t)
  }
}