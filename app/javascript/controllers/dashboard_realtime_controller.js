import { Controller } from "@hotwired/stimulus"
import consumer from "channels/consumer"

export default class extends Controller {
  static targets = ["connectionStatus", "connectionIcon", "lastUpdate", "autoRefresh"]
  static values = { 
    refreshInterval: { type: Number, default: 30000 },
    throttleDelay: { type: Number, default: 1000 }
  }
  
  connect() {
    console.log("Dashboard Realtime Controller connected")
    this.subscription = null
    this.updateQueue = []
    this.isProcessing = false
    this.lastUpdateTime = Date.now()
    
    this.setupChannel()
    this.startAutoRefresh()
    this.updateConnectionStatus('connecting')
  }
  
  disconnect() {
    if (this.subscription) {
      this.subscription.unsubscribe()
    }
    if (this.refreshTimer) {
      clearInterval(this.refreshTimer)
    }
  }
  
  setupChannel() {
    this.subscription = consumer.subscriptions.create(
      { channel: "DashboardChannel" },
      {
        connected: () => {
          console.log("Connected to Dashboard channel")
          this.updateConnectionStatus('connected')
          this.showNotification('실시간 업데이트 연결됨', 'success')
        },
        
        disconnected: () => {
          console.log("Disconnected from Dashboard channel")
          this.updateConnectionStatus('disconnected')
          this.showNotification('실시간 업데이트 연결 끊김', 'warning')
        },
        
        received: (data) => {
          console.log("Received realtime data:", data)
          this.queueUpdate(data)
        }
      }
    )
  }
  
  queueUpdate(data) {
    // 스로틀링을 위해 업데이트를 큐에 추가
    this.updateQueue.push(data)
    
    if (!this.isProcessing) {
      this.processUpdateQueue()
    }
  }
  
  async processUpdateQueue() {
    if (this.updateQueue.length === 0) {
      this.isProcessing = false
      return
    }
    
    this.isProcessing = true
    
    // 스로틀링 확인
    const now = Date.now()
    const timeSinceLastUpdate = now - this.lastUpdateTime
    
    if (timeSinceLastUpdate < this.throttleDelayValue) {
      // 대기 후 다시 시도
      setTimeout(() => this.processUpdateQueue(), this.throttleDelayValue - timeSinceLastUpdate)
      return
    }
    
    // 큐에서 업데이트 가져오기
    const updates = this.updateQueue.splice(0, this.updateQueue.length)
    
    // 업데이트 처리
    updates.forEach(data => {
      switch(data.action) {
        case 'update_stats':
          this.updateStats(data.stats)
          break
        case 'update_approval':
          this.updateApproval(data)
          break
        case 'update_chart':
          this.updateChart(data)
          break
        case 'refresh_section':
          this.refreshSection(data.section)
          break
      }
    })
    
    this.lastUpdateTime = now
    this.updateLastUpdateTime()
    
    // 다음 업데이트 처리
    setTimeout(() => this.processUpdateQueue(), this.throttleDelayValue)
  }
  
  updateStats(stats) {
    // 실시간 통계 업데이트 애니메이션과 함께
    Object.keys(stats).forEach(key => {
      const element = document.querySelector(`[data-stat="${key}"]`)
      if (element) {
        this.animateValueChange(element, stats[key])
      }
    })
  }
  
  updateApproval(data) {
    // 승인 관련 업데이트 처리
    if (data.approval_id) {
      const approvalElement = document.querySelector(`[data-approval-id="${data.approval_id}"]`)
      if (approvalElement) {
        approvalElement.classList.add('animate-pulse', 'bg-yellow-100')
        setTimeout(() => {
          approvalElement.classList.remove('animate-pulse', 'bg-yellow-100')
        }, 3000)
      }
    }
    
    if (data.stats) {
      this.updateStats(data.stats)
    }
  }
  
  updateChart(data) {
    // 차트 업데이트 이벤트 발송
    const event = new CustomEvent('dashboard:chart-update', {
      detail: data,
      bubbles: true
    })
    this.element.dispatchEvent(event)
  }
  
  refreshSection(sectionId) {
    // Turbo Frame을 통한 섹션 새로고침
    const frame = document.querySelector(`turbo-frame#${sectionId}`)
    if (frame) {
      frame.reload()
    }
  }
  
  animateValueChange(element, newValue) {
    const oldValue = element.textContent
    element.classList.add('text-yellow-600', 'font-bold')
    element.textContent = newValue
    
    setTimeout(() => {
      element.classList.remove('text-yellow-600', 'font-bold')
    }, 2000)
  }
  
  updateConnectionStatus(status) {
    if (!this.hasConnectionStatusTarget) return
    
    const statusConfig = {
      connecting: { color: 'yellow', icon: '⟳', text: '연결 중...' },
      connected: { color: 'green', icon: '●', text: '실시간 연결됨' },
      disconnected: { color: 'red', icon: '○', text: '연결 끊김' }
    }
    
    const config = statusConfig[status]
    
    this.connectionStatusTarget.className = `text-${config.color}-500 text-sm flex items-center gap-1`
    this.connectionIconTarget.textContent = config.icon
    this.connectionIconTarget.className = status === 'connecting' ? 'animate-spin' : ''
    this.connectionStatusTarget.querySelector('span').textContent = config.text
  }
  
  updateLastUpdateTime() {
    if (!this.hasLastUpdateTarget) return
    
    const now = new Date()
    const timeString = now.toLocaleTimeString('ko-KR')
    this.lastUpdateTarget.textContent = timeString
  }
  
  startAutoRefresh() {
    if (!this.hasAutoRefreshTarget) return
    
    if (this.autoRefreshTarget.checked) {
      this.refreshTimer = setInterval(() => {
        this.refreshDashboard()
      }, this.refreshIntervalValue)
    }
  }
  
  toggleAutoRefresh() {
    if (this.refreshTimer) {
      clearInterval(this.refreshTimer)
      this.refreshTimer = null
    }
    
    if (this.autoRefreshTarget.checked) {
      this.startAutoRefresh()
      this.showNotification('자동 새로고침 활성화됨', 'success')
    } else {
      this.showNotification('자동 새로고침 비활성화됨', 'info')
    }
  }
  
  refreshDashboard() {
    // 전체 대시보드 새로고침
    const mainFrame = document.querySelector('turbo-frame#dashboard-main')
    if (mainFrame) {
      mainFrame.reload()
    }
  }
  
  manualRefresh() {
    this.refreshDashboard()
    this.showNotification('대시보드를 새로고침했습니다', 'success')
  }
  
  showNotification(message, type = 'info') {
    // 토스트 알림 표시
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
      warning: 'bg-yellow-500',
      error: 'bg-red-500',
      info: 'bg-blue-500'
    }
    return classes[type] || classes.info
  }
}