import { Controller } from "@hotwired/stimulus"

// 드롭다운 메뉴 컨트롤러
export default class extends Controller {
  static targets = ["menu", "button"]
  
  connect() {
    // 외부 클릭 감지를 위한 이벤트 리스너
    this.handleClickOutside = this.clickOutside.bind(this)
    document.addEventListener("click", this.handleClickOutside)
  }
  
  disconnect() {
    document.removeEventListener("click", this.handleClickOutside)
  }
  
  toggle(event) {
    event.stopPropagation()
    
    // 다른 모든 드롭다운 닫기
    this.closeOtherDropdowns()
    
    // 현재 드롭다운 토글
    this.menuTarget.classList.toggle("hidden")
  }
  
  show() {
    // 다른 모든 드롭다운 닫기
    this.closeOtherDropdowns()
    this.menuTarget.classList.remove("hidden")
  }
  
  hide() {
    this.menuTarget.classList.add("hidden")
  }
  
  closeOtherDropdowns() {
    // 페이지의 모든 드롭다운 찾아서 닫기
    document.querySelectorAll('[data-controller="dropdown"]').forEach(dropdown => {
      if (dropdown !== this.element) {
        const menu = dropdown.querySelector('[data-dropdown-target="menu"]')
        if (menu) {
          menu.classList.add("hidden")
        }
      }
    })
  }
  
  clickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.hide()
    }
  }
}