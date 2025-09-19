import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { 
    deleteUrl: String 
  }
  
  connect() {
    console.log("Draft notification controller connected")
  }
  
  async deleteDraft(event) {
    event.preventDefault()
    
    // 비동기로 서버에 삭제 요청
    try {
      const response = await fetch(this.deleteUrlValue, {
        method: 'DELETE',
        headers: {
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content,
          'Accept': 'application/json'
        }
      })
      
      if (response.ok) {
        // 성공 알림을 먼저 표시
        this.showNotification('임시 저장된 항목이 삭제되었습니다.')
      } else {
        console.error('Failed to delete draft')
        this.showNotification('임시 저장 삭제에 실패했습니다.', 'error')
      }
    } catch (error) {
      console.error('Error deleting draft:', error)
      this.showNotification('임시 저장 삭제 중 오류가 발생했습니다.', 'error')
    }
  }
  
  showNotification(message, type = 'success') {
    const bgColor = type === 'success' ? 'bg-green-50 border-green-200' : 'bg-red-50 border-red-200'
    const textColor = type === 'success' ? 'text-green-800' : 'text-red-800'
    const iconColor = type === 'success' ? 'text-green-600' : 'text-red-600'
    
    // 현재 알림 영역의 내용을 성공 메시지로 대체
    this.element.className = `mb-4 p-4 ${bgColor} border rounded-lg transition-all duration-300`
    this.element.innerHTML = `
      <div class="flex items-center">
        <svg class="h-5 w-5 ${iconColor} mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          ${type === 'success' 
            ? '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />'
            : '<path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />'
          }
        </svg>
        <p class="text-sm ${textColor}">${message}</p>
      </div>
    `
    
    // 5초 후 페이드 아웃 후 제거
    setTimeout(() => {
      this.element.style.opacity = '0'
      setTimeout(() => {
        this.element.remove()
      }, 300)
    }, 5000)
  }
}