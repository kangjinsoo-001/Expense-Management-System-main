import { Controller } from "@hotwired/stimulus"

// 결재 상세 정보를 인라인으로 토글하는 컨트롤러
export default class extends Controller {
  static targets = ["toggleBtn", "detailsRow", "icon"]
  static values = { openItems: Array }
  
  connect() {
    // 열려있는 항목들을 추적
    this.openItemsValue = this.openItemsValue || []
  }
  
  toggle(event) {
    event.preventDefault()
    event.stopPropagation()
    
    const button = event.currentTarget
    const itemId = button.dataset.itemId
    
    if (!itemId) return
    
    // 대상 행 찾기
    const detailsRow = document.getElementById(`approval-details-${itemId}`)
    const icon = this.iconTargets.find(el => el.dataset.approvalDetailsTarget === `icon${itemId}`)
    
    if (!detailsRow) return
    
    const isOpen = !detailsRow.classList.contains("hidden")
    
    if (isOpen) {
      // 닫기
      this.hideRow(detailsRow, icon)
      this.openItemsValue = this.openItemsValue.filter(id => id !== itemId)
    } else {
      // 열기
      this.showRow(detailsRow, icon)
      
      // 다른 열려있는 행들 닫기 (한 번에 하나만 열리도록)
      this.closeOtherRows(itemId)
      
      this.openItemsValue = [itemId]
    }
  }
  
  showRow(row, icon) {
    if (row) {
      row.classList.remove("hidden")
      
      // 부드러운 애니메이션을 위해
      setTimeout(() => {
        row.classList.add("opacity-100")
        row.classList.remove("opacity-0")
      }, 10)
    }
    
    if (icon) {
      icon.classList.add("rotate-180")
    }
  }
  
  hideRow(row, icon) {
    if (row) {
      row.classList.add("opacity-0")
      row.classList.remove("opacity-100")
      
      // 애니메이션 후 숨기기
      setTimeout(() => {
        row.classList.add("hidden")
      }, 200)
    }
    
    if (icon) {
      icon.classList.remove("rotate-180")
    }
  }
  
  closeOtherRows(currentItemId) {
    this.openItemsValue.forEach(itemId => {
      if (itemId !== currentItemId) {
        const row = document.getElementById(`approval-details-${itemId}`)
        const icon = this.iconTargets.find(el => el.dataset.approvalDetailsTarget === `icon${itemId}`)
        
        if (row) {
          this.hideRow(row, icon)
        }
      }
    })
  }
  
  // 페이지 로드 시 모든 상세 행이 숨겨져 있는지 확인
  disconnect() {
    // 페이지를 떠날 때 열려있는 행들 닫기
    this.openItemsValue.forEach(itemId => {
      const row = document.getElementById(`approval-details-${itemId}`)
      if (row) {
        row.classList.add("hidden")
      }
    })
  }
}