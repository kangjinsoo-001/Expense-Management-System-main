import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  connect() {
    console.log("Refresh controller connected")
  }

  refreshAll(event) {
    event.preventDefault()
    
    // 버튼에 로딩 상태 추가
    const button = event.currentTarget
    const originalContent = button.innerHTML
    button.disabled = true
    button.innerHTML = `
      <svg class="animate-spin mr-2 h-4 w-4 text-gray-500" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
      </svg>
      새로고침 중...
    `
    
    // 현재 페이지를 Turbo로 새로고침
    fetch(window.location.href, {
      headers: {
        'Accept': 'text/vnd.turbo-stream.html, text/html, application/xhtml+xml',
        'Turbo-Frame': '_top'
      }
    })
    .then(response => response.text())
    .then(html => {
      // Turbo를 사용하여 페이지 업데이트
      Turbo.renderStreamMessage(html)
    })
    .catch(error => {
      console.error('Refresh error:', error)
    })
    .finally(() => {
      // 버튼 원래 상태로 복원
      setTimeout(() => {
        button.disabled = false
        button.innerHTML = originalContent
      }, 1000)
    })
  }
}