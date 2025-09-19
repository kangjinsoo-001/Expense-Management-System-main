import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["swipeable", "actions"]
  static values = { 
    threshold: { type: Number, default: 50 },
    open: { type: Boolean, default: false }
  }
  
  connect() {
    this.startX = null
    this.startY = null
    this.currentX = null
    
    // 터치 이벤트 리스너 추가
    this.element.addEventListener('touchstart', this.handleTouchStart.bind(this), { passive: false })
    this.element.addEventListener('touchmove', this.handleTouchMove.bind(this), { passive: false })
    this.element.addEventListener('touchend', this.handleTouchEnd.bind(this))
    
    // 초기 상태 설정
    if (this.hasActionsTarget) {
      this.actionsTarget.style.transform = 'translateX(100%)'
      this.actionsTarget.style.transition = 'transform 0.3s ease'
    }
  }
  
  disconnect() {
    this.element.removeEventListener('touchstart', this.handleTouchStart)
    this.element.removeEventListener('touchmove', this.handleTouchMove)
    this.element.removeEventListener('touchend', this.handleTouchEnd)
  }
  
  handleTouchStart(e) {
    this.startX = e.touches[0].clientX
    this.startY = e.touches[0].clientY
    this.currentX = this.startX
    
    // 트랜지션 비활성화
    if (this.hasSwipeableTarget) {
      this.swipeableTarget.style.transition = 'none'
    }
  }
  
  handleTouchMove(e) {
    if (!this.startX) return
    
    const currentX = e.touches[0].clientX
    const currentY = e.touches[0].clientY
    const diffX = currentX - this.startX
    const diffY = currentY - this.startY
    
    // 수직 스크롤이 더 크면 스와이프 취소
    if (Math.abs(diffY) > Math.abs(diffX)) {
      this.reset()
      return
    }
    
    // 수평 스와이프 방지
    e.preventDefault()
    
    // 왼쪽 스와이프만 허용
    if (diffX < 0 && this.hasSwipeableTarget) {
      const translateX = Math.max(diffX, -100) // 최대 100px 이동
      this.swipeableTarget.style.transform = `translateX(${translateX}px)`
      
      if (this.hasActionsTarget) {
        const actionsTranslate = Math.min(100 + translateX, 100)
        this.actionsTarget.style.transform = `translateX(${actionsTranslate}%)`
      }
    }
    
    this.currentX = currentX
  }
  
  handleTouchEnd(e) {
    if (!this.startX) return
    
    const diffX = this.currentX - this.startX
    
    // 트랜지션 활성화
    if (this.hasSwipeableTarget) {
      this.swipeableTarget.style.transition = 'transform 0.3s ease'
    }
    
    // 임계값 이상 스와이프했으면 열기
    if (diffX < -this.thresholdValue) {
      this.open()
    } else {
      this.close()
    }
    
    this.reset()
  }
  
  open() {
    this.openValue = true
    
    if (this.hasSwipeableTarget) {
      this.swipeableTarget.style.transform = 'translateX(-100px)'
    }
    
    if (this.hasActionsTarget) {
      this.actionsTarget.style.transform = 'translateX(0)'
    }
    
    // 다른 열린 항목 닫기
    this.closeOthers()
  }
  
  close() {
    this.openValue = false
    
    if (this.hasSwipeableTarget) {
      this.swipeableTarget.style.transform = 'translateX(0)'
    }
    
    if (this.hasActionsTarget) {
      this.actionsTarget.style.transform = 'translateX(100%)'
    }
  }
  
  toggle() {
    if (this.openValue) {
      this.close()
    } else {
      this.open()
    }
  }
  
  closeOthers() {
    // 같은 컨트롤러를 사용하는 다른 요소들 찾기
    const otherElements = document.querySelectorAll('[data-controller~="touch-gestures"]')
    otherElements.forEach(element => {
      if (element !== this.element) {
        const controller = this.application.getControllerForElementAndIdentifier(element, 'touch-gestures')
        if (controller && controller.openValue) {
          controller.close()
        }
      }
    })
  }
  
  reset() {
    this.startX = null
    this.startY = null
    this.currentX = null
  }
  
  // 외부 클릭으로 닫기
  closeOnOutsideClick(event) {
    if (!this.element.contains(event.target) && this.openValue) {
      this.close()
    }
  }
}