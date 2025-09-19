import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["newItemForm", "itemsContainer"]
  
  connect() {
    console.log("ExpenseSheetController connected")
  }

  toggleNewItemForm(event) {
    event.preventDefault()
    
    if (this.hasNewItemFormTarget) {
      this.newItemFormTarget.classList.toggle('hidden')
    }
  }

  hideNewItemForm() {
    if (this.hasNewItemFormTarget) {
      this.newItemFormTarget.classList.add('hidden')
    }
  }

  // Turbo Streams가 성공적으로 항목을 추가한 후 폼을 숨김
  itemAdded() {
    this.hideNewItemForm()
  }

  // Flash 메시지 자동 제거
  removeFlashMessage(event) {
    const flashMessage = event.currentTarget
    setTimeout(() => {
      flashMessage.style.transition = 'opacity 0.5s'
      flashMessage.style.opacity = '0'
      setTimeout(() => flashMessage.remove(), 500)
    }, 3000)
  }
}