import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["approvalRulesList", "addRuleForm", "flashContainer"]
  
  connect() {
    console.log("ExpenseCode controller connected")
    console.log("Controller element:", this.element)
    console.log("Available targets:", this.targets)
  }
  
  // 승인 규칙 추가 성공 시
  ruleAdded(event) {
    const [data, status, xhr] = event.detail
    
    if (status === "ok") {
      this.showFlash("notice", "승인 규칙이 추가되었습니다.")
    }
  }
  
  // 승인 규칙 삭제 성공 시
  ruleRemoved(event) {
    const [data, status, xhr] = event.detail
    
    if (status === "ok") {
      this.showFlash("notice", "승인 규칙이 삭제되었습니다.")
      
      // 남은 규칙이 없으면 빈 메시지 표시
      setTimeout(() => {
        const tbody = document.getElementById("approval_rules_tbody")
        if (tbody && tbody.children.length === 0) {
          const wrapper = document.getElementById("approval_rules_table_wrapper")
          if (wrapper) {
            wrapper.innerHTML = '<p class="text-gray-500 text-center py-4" id="no_rules_message">아직 승인 규칙이 없습니다.</p>'
          }
        }
      }, 100)
    }
  }
  
  // 플래시 메시지 표시
  showFlash(type, message) {
    const timestamp = new Date().getTime()
    const flashId = `flash_${timestamp}_${Math.random().toString(36).substr(2, 9)}`
    
    const flashHTML = `
      <div id="${flashId}" class="flash-message flash-${type} p-4 mb-4 rounded-lg ${type === 'notice' ? 'bg-green-50 text-green-800 border border-green-200' : 'bg-red-50 text-red-800 border border-red-200'}">
        <div class="flex items-center justify-between">
          <span>${message}</span>
          <button onclick="this.parentElement.parentElement.remove()" class="ml-4 text-sm hover:opacity-75">
            <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
            </svg>
          </button>
        </div>
      </div>
    `
    
    // 플래시 컨테이너 찾기
    let container = document.getElementById("flash_container")
    if (!container) {
      container = document.querySelector('[data-controller="expense-code"]')
      if (container) {
        const flashDiv = document.createElement('div')
        flashDiv.id = 'flash_container'
        container.insertBefore(flashDiv, container.firstChild)
        container = flashDiv
      }
    }
    
    if (container) {
      container.insertAdjacentHTML("afterbegin", flashHTML)
      
      // 5초 후 자동 제거
      setTimeout(() => {
        const flash = document.getElementById(flashId)
        if (flash) {
          flash.style.transition = "opacity 0.5s ease-out"
          flash.style.opacity = "0"
          setTimeout(() => flash.remove(), 500)
        }
      }, 5000)
    }
  }
}