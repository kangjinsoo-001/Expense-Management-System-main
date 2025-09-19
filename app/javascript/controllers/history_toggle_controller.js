import { Controller } from "@hotwired/stimulus"

// 이력 섹션을 토글하는 컨트롤러
export default class extends Controller {
  static targets = ["content", "toggleButton", "showText", "hideText"]
  
  connect() {
    this.isVisible = false
    this.updateVisibility()
  }
  
  toggle() {
    this.isVisible = !this.isVisible
    this.updateVisibility()
  }
  
  updateVisibility() {
    if (this.hasContentTarget) {
      if (this.isVisible) {
        this.contentTarget.classList.remove("hidden")
        // 애니메이션 효과
        setTimeout(() => {
          this.contentTarget.classList.remove("opacity-0", "max-h-0")
          this.contentTarget.classList.add("opacity-100", "max-h-screen")
        }, 10)
      } else {
        this.contentTarget.classList.remove("opacity-100", "max-h-screen")
        this.contentTarget.classList.add("opacity-0", "max-h-0")
        // 애니메이션 후 숨기기
        setTimeout(() => {
          this.contentTarget.classList.add("hidden")
        }, 300)
      }
    }
    
    // 버튼 텍스트 업데이트
    if (this.hasShowTextTarget && this.hasHideTextTarget) {
      if (this.isVisible) {
        this.showTextTarget.classList.add("hidden")
        this.hideTextTarget.classList.remove("hidden")
      } else {
        this.showTextTarget.classList.remove("hidden")
        this.hideTextTarget.classList.add("hidden")
      }
    }
  }
}