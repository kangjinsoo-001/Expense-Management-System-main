import consumer from "channels/consumer"

const dashboardChannel = consumer.subscriptions.create("DashboardChannel", {
  connected() {
    console.log("Connected to Dashboard channel")
  },

  disconnected() {
    console.log("Disconnected from Dashboard channel")
  },

  received(data) {
    console.log("Received data:", data)
    
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
    }
    
    // 최종 업데이트 시간 갱신
    this.updateLastUpdatedTime()
  },
  
  updateStats(stats) {
    // 대기중 승인 건수 업데이트
    if (stats.pending_approvals !== undefined) {
      const pendingElement = document.getElementById('pending-approvals')
      if (pendingElement) {
        pendingElement.textContent = stats.pending_approvals
      }
    }
    
    // 총 경비 업데이트
    if (stats.summary && stats.summary.total_amount !== undefined) {
      const totalElement = document.querySelector('[data-total-expense]')
      if (totalElement) {
        totalElement.textContent = new Intl.NumberFormat('ko-KR', {
          style: 'currency',
          currency: 'KRW'
        }).format(stats.summary.total_amount)
      }
    }
  },
  
  updateApproval(data) {
    // 승인 통계 업데이트
    if (data.stats) {
      this.updateStats(data.stats)
    }
    
    // 특정 승인 상태 변경 시 시각적 피드백
    if (data.approval_id && data.status) {
      const approvalElement = document.querySelector(`[data-approval-id="${data.approval_id}"]`)
      if (approvalElement) {
        approvalElement.classList.add('bg-yellow-50')
        setTimeout(() => {
          approvalElement.classList.remove('bg-yellow-50')
        }, 3000)
      }
    }
  },
  
  updateChart(data) {
    // Chart.js 차트 업데이트 로직
    if (data.chart_id && window[data.chart_id + 'Chart']) {
      const chart = window[data.chart_id + 'Chart']
      chart.data = data.chart_data
      chart.update()
    }
  },
  
  updateLastUpdatedTime() {
    const element = document.getElementById('last-updated')
    if (element) {
      const now = new Date()
      const timeString = now.toLocaleTimeString('ko-KR')
      element.textContent = `최종 업데이트: ${timeString}`
    }
  }
})

export default dashboardChannel
