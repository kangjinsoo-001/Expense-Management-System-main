import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["menu", "panel", "hamburger"]
  
  connect() {
    // 모바일 메뉴 초기 상태 설정
    if (this.hasMenuTarget) {
      this.menuTarget.classList.add("hidden")
    }
    
    // 화면 크기 변경 감지
    this.handleResize = this.handleResize.bind(this)
    window.addEventListener('resize', this.handleResize)
  }
  
  disconnect() {
    window.removeEventListener('resize', this.handleResize)
  }
  
  toggle() {
    const isHidden = this.menuTarget.classList.contains("hidden")
    
    if (isHidden) {
      this.open()
    } else {
      this.close()
    }
  }
  
  open() {
    this.menuTarget.classList.remove("hidden")
    document.body.style.overflow = 'hidden' // 스크롤 방지
    
    // 애니메이션을 위한 지연
    setTimeout(() => {
      if (this.hasPanelTarget) {
        this.panelTarget.classList.remove("translate-x-full")
        this.panelTarget.classList.add("translate-x-0")
      }
    }, 10)
  }
  
  close() {
    if (this.hasPanelTarget) {
      this.panelTarget.classList.add("translate-x-full")
      this.panelTarget.classList.remove("translate-x-0")
    }
    
    setTimeout(() => {
      this.menuTarget.classList.add("hidden")
      document.body.style.overflow = '' // 스크롤 복원
    }, 300)
  }
  
  // 메뉴 외부 클릭 시 닫기
  closeOnOutsideClick(event) {
    if (!this.element.contains(event.target)) {
      this.close()
    }
  }
  
  // 화면 크기가 데스크톱으로 변경되면 메뉴 닫기
  handleResize() {
    if (window.innerWidth >= 768) {
      this.close()
    }
  }
}