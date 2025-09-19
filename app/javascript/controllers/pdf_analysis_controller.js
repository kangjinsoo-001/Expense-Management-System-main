import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [ "resultItem", "chevron", "details", "toggleText" ]
  
  connect() {
    this.expanded = false
  }
  
  toggle(event) {
    const index = event.currentTarget.dataset.index
    const resultItem = this.resultItemTargets[index]
    const chevron = resultItem.querySelector('[data-pdf-analysis-target="chevron"]')
    const details = resultItem.querySelector('[data-pdf-analysis-target="details"]')
    
    if (details.classList.contains('hidden')) {
      details.classList.remove('hidden')
      chevron.classList.add('rotate-90')
    } else {
      details.classList.add('hidden')
      chevron.classList.remove('rotate-90')
    }
  }
  
  toggleAll() {
    this.expanded = !this.expanded
    
    this.resultItemTargets.forEach((item) => {
      const chevron = item.querySelector('[data-pdf-analysis-target="chevron"]')
      const details = item.querySelector('[data-pdf-analysis-target="details"]')
      
      if (this.expanded) {
        details.classList.remove('hidden')
        chevron.classList.add('rotate-90')
      } else {
        details.classList.add('hidden')
        chevron.classList.remove('rotate-90')
      }
    })
    
    this.toggleTextTarget.textContent = this.expanded ? '모두 접기' : '모두 펼치기'
  }
}