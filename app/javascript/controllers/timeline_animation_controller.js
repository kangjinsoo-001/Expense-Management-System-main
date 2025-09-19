import { Controller } from "@hotwired/stimulus"

// 타임라인 애니메이션을 관리하는 컨트롤러
export default class extends Controller {
  static targets = ["progressBar", "node"]
  
  connect() {
    // 페이지 로드 시 애니메이션 실행
    this.animateTimeline()
  }
  
  animateTimeline() {
    // 진행률 바 애니메이션
    if (this.hasProgressBarTarget) {
      const targetWidth = this.progressBarTarget.style.width
      this.progressBarTarget.style.width = "0%"
      
      setTimeout(() => {
        this.progressBarTarget.style.transition = "width 1s ease-out"
        this.progressBarTarget.style.width = targetWidth
      }, 100)
    }
    
    // 노드 애니메이션 (순차적으로 나타남)
    if (this.hasNodeTarget) {
      this.nodeTargets.forEach((node, index) => {
        node.style.opacity = "0"
        node.style.transform = "scale(0.8)"
        
        setTimeout(() => {
          node.style.transition = "all 0.3s ease-out"
          node.style.opacity = "1"
          node.style.transform = "scale(1)"
        }, 100 + (index * 150))
      })
    }
  }
}