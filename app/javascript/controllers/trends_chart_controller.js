import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    // 호버 시 툴팁 표시를 위한 이벤트 리스너 추가
    this.element.querySelectorAll('[data-amount]').forEach(bar => {
      bar.addEventListener('mouseenter', this.showTooltip.bind(this))
      bar.addEventListener('mouseleave', this.hideTooltip.bind(this))
    })
  }

  showTooltip(event) {
    const bar = event.currentTarget
    const amount = bar.dataset.amount
    const label = bar.dataset.label
    
    // 기존 툴팁 제거
    this.hideTooltip()
    
    // 새 툴팁 생성
    const tooltip = document.createElement('div')
    tooltip.className = 'absolute bg-gray-900 text-white text-xs rounded py-1 px-2 z-50'
    tooltip.style.bottom = '100%'
    tooltip.style.left = '50%'
    tooltip.style.transform = 'translateX(-50%) translateY(-8px)'
    tooltip.innerHTML = `
      <div>${label}</div>
      <div class="font-semibold">${amount}</div>
    `
    
    // 툴팁 추가
    bar.style.position = 'relative'
    bar.appendChild(tooltip)
  }

  hideTooltip() {
    const existingTooltip = this.element.querySelector('.absolute.bg-gray-900')
    if (existingTooltip) {
      existingTooltip.remove()
    }
  }

  disconnect() {
    this.hideTooltip()
  }
}