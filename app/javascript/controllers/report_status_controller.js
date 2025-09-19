import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["export"]
  
  connect() {
    console.log("Report status controller connected")
    this.checkExportStatuses()
    
    // 주기적으로 상태 확인 (5초마다)
    this.statusCheckInterval = setInterval(() => {
      this.checkExportStatuses()
    }, 5000)
  }
  
  disconnect() {
    if (this.statusCheckInterval) {
      clearInterval(this.statusCheckInterval)
    }
  }
  
  checkExportStatuses() {
    this.exportTargets.forEach(exportElement => {
      const exportId = exportElement.dataset.exportId
      const currentStatus = this.getStatusFromElement(exportElement)
      
      // 이미 완료되거나 실패한 경우 체크하지 않음
      if (currentStatus === 'completed' || currentStatus === 'failed') {
        return
      }
      
      // 상태 확인 API 호출
      fetch(`/admin/reports/${exportId}/status`, {
        headers: {
          'Accept': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        }
      })
      .then(response => response.json())
      .then(data => {
        this.updateExportStatus(exportElement, data)
      })
      .catch(error => {
        console.error('Error checking export status:', error)
      })
    })
  }
  
  getStatusFromElement(element) {
    if (element.querySelector('.text-green-500')) return 'completed'
    if (element.querySelector('.text-red-500')) return 'failed'
    if (element.querySelector('.text-indigo-600')) return 'processing'
    return 'pending'
  }
  
  updateExportStatus(element, data) {
    const currentStatus = this.getStatusFromElement(element)
    
    // 상태가 변경된 경우에만 업데이트
    if (currentStatus !== data.status) {
      // 아이콘 업데이트
      const iconContainer = element.querySelector('.flex-1 .flex')
      const iconHtml = this.getStatusIconHtml(data.status)
      
      // 첫 번째 SVG 요소를 새로운 아이콘으로 교체
      const oldIcon = iconContainer.querySelector('svg')
      if (oldIcon) {
        oldIcon.outerHTML = iconHtml
      }
      
      // 완료된 경우 다운로드 버튼 추가
      if (data.status === 'completed' && data.download_url) {
        const buttonContainer = element.querySelector('.flex > :last-child')
        if (buttonContainer && !buttonContainer.querySelector('a')) {
          buttonContainer.innerHTML = `
            <a href="${data.download_url}" 
               class="inline-flex items-center px-3 py-1 border border-transparent text-sm leading-4 font-medium rounded-md text-indigo-700 bg-indigo-100 hover:bg-indigo-200"
               data-turbo="false">
              <svg class="mr-1.5 h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 10v6m0 0l-3-3m3 3l3-3m2 8H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
              </svg>
              다운로드
            </a>
          `
        }
      }
      
      // 알림 표시
      if (data.status === 'completed') {
        this.showNotification('리포트 생성이 완료되었습니다.', 'success')
      } else if (data.status === 'failed') {
        this.showNotification('리포트 생성에 실패했습니다.', 'error')
      }
    }
  }
  
  getStatusIconHtml(status) {
    switch(status) {
      case 'pending':
        return `<svg class="animate-spin h-5 w-5 text-gray-400 mr-2" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>`
      case 'processing':
        return `<svg class="animate-spin h-5 w-5 text-indigo-600 mr-2" fill="none" viewBox="0 0 24 24">
          <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
          <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
        </svg>`
      case 'completed':
        return `<svg class="h-5 w-5 text-green-500 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12l2 2 4-4m6 2a9 9 0 11-18 0 9 9 0 0118 0z" />
        </svg>`
      case 'failed':
        return `<svg class="h-5 w-5 text-red-500 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M12 8v4m0 4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
        </svg>`
      default:
        return ''
    }
  }
  
  showNotification(message, type = 'info') {
    // 알림 표시 (실제로는 더 나은 알림 시스템 사용)
    const notification = document.createElement('div')
    notification.className = `fixed bottom-4 right-4 px-6 py-3 rounded-lg shadow-lg text-white transform transition-all duration-300 ${this.getNotificationClass(type)}`
    notification.textContent = message
    
    document.body.appendChild(notification)
    
    // 애니메이션으로 표시
    setTimeout(() => {
      notification.classList.add('translate-y-0', 'opacity-100')
    }, 10)
    
    // 3초 후 제거
    setTimeout(() => {
      notification.classList.add('translate-y-2', 'opacity-0')
      setTimeout(() => notification.remove(), 300)
    }, 3000)
  }
  
  getNotificationClass(type) {
    const classes = {
      success: 'bg-green-500',
      error: 'bg-red-500',
      info: 'bg-blue-500'
    }
    return classes[type] || classes.info
  }
}