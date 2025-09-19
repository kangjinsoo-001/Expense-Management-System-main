import { Controller } from "@hotwired/stimulus"

let Chart

export default class extends Controller {
  static targets = ["canvas", "info"]
  static values = { 
    budget: Number,
    actual: Number,
    rate: Number,
    status: String,
    name: String
  }

  async connect() {
    console.log("Budget gauge controller connected")
    await this.loadChartJS()
    this.initializeChart()
    this.updateInfo()
  }
  
  async loadChartJS() {
    if (window.Chart) {
      Chart = window.Chart
      return
    }
    
    return new Promise((resolve) => {
      const script = document.createElement('script')
      script.src = '/javascripts/chart.umd.js'
      script.onload = () => {
        Chart = window.Chart
        resolve()
      }
      script.onerror = () => {
        console.error("Failed to load Chart.js")
        resolve()
      }
      if (!document.querySelector('script[src="/javascripts/chart.umd.js"]')) {
        document.head.appendChild(script)
      } else {
        resolve()
      }
    })
  }

  disconnect() {
    if (this.chart) {
      this.chart.destroy()
    }
  }

  initializeChart() {
    if (!this.hasCanvasTarget) return
    
    const ctx = this.canvasTarget.getContext('2d')
    
    // 상태별 색상
    const statusColors = {
      safe: 'rgba(34, 197, 94, 0.8)',      // green-500
      normal: 'rgba(59, 130, 246, 0.8)',   // blue-500
      warning: 'rgba(251, 146, 60, 0.8)',  // orange-400
      danger: 'rgba(239, 68, 68, 0.8)'     // red-500
    }
    
    const color = statusColors[this.statusValue] || statusColors.normal
    const remaining = Math.max(0, 100 - this.rateValue)

    this.chart = new Chart(ctx, {
      type: 'doughnut',
      data: {
        labels: ['사용액', '잔액'],
        datasets: [{
          data: [this.rateValue, remaining],
          backgroundColor: [
            color,
            'rgba(229, 231, 235, 0.3)' // gray-200 with opacity
          ],
          borderColor: [
            color.replace('0.8', '1'),
            'rgba(229, 231, 235, 0.5)'
          ],
          borderWidth: 2
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        cutout: '70%',
        rotation: -90,
        circumference: 180,
        animation: {
          animateRotate: true,
          duration: 1500,
          easing: 'easeInOutQuart'
        },
        plugins: {
          legend: {
            display: false
          },
          tooltip: {
            callbacks: {
              label: function(context) {
                const label = context.label || ''
                const value = context.parsed
                
                if (label === '사용액') {
                  return [
                    `사용액: ${new Intl.NumberFormat('ko-KR', { 
                      style: 'currency', 
                      currency: 'KRW' 
                    }).format(this.actualValue)}`,
                    `실행률: ${this.rateValue}%`
                  ]
                } else {
                  const remainingAmount = this.budgetValue - this.actualValue
                  return [
                    `잔액: ${new Intl.NumberFormat('ko-KR', { 
                      style: 'currency', 
                      currency: 'KRW' 
                    }).format(remainingAmount)}`,
                    `잔여율: ${remaining}%`
                  ]
                }
              }.bind(this)
            }
          }
        }
      }
    })
    
    // 중앙에 텍스트 추가
    this.drawCenterText()
  }

  drawCenterText() {
    // Chart.js 플러그인으로 중앙 텍스트 추가
    const centerTextPlugin = {
      id: 'centerText',
      beforeDraw: (chart) => {
        const { ctx, chartArea: { left, right, top, bottom } } = chart
        const centerX = (left + right) / 2
        const centerY = (top + bottom) / 2 + (bottom - top) * 0.1

        ctx.save()
        
        // 실행률 텍스트
        ctx.font = 'bold 24px sans-serif'
        ctx.fillStyle = this.getStatusColor()
        ctx.textAlign = 'center'
        ctx.textBaseline = 'middle'
        ctx.fillText(`${this.rateValue}%`, centerX, centerY)
        
        // 상태 텍스트
        ctx.font = '14px sans-serif'
        ctx.fillStyle = '#6B7280' // gray-500
        ctx.fillText(this.getStatusText(), centerX, centerY + 25)
        
        ctx.restore()
      }
    }
    
    // 플러그인 등록
    Chart.register(centerTextPlugin)
  }

  updateInfo() {
    if (!this.hasInfoTarget) return
    
    const infoHtml = `
      <div class="text-center">
        <h4 class="font-semibold text-gray-900">${this.nameValue}</h4>
        <div class="mt-2 space-y-1 text-sm">
          <div class="flex justify-between">
            <span class="text-gray-500">예산:</span>
            <span class="font-medium">${this.formatCurrency(this.budgetValue)}</span>
          </div>
          <div class="flex justify-between">
            <span class="text-gray-500">사용:</span>
            <span class="font-medium">${this.formatCurrency(this.actualValue)}</span>
          </div>
          <div class="flex justify-between">
            <span class="text-gray-500">잔액:</span>
            <span class="font-medium ${this.budgetValue - this.actualValue < 0 ? 'text-red-600' : ''}">
              ${this.formatCurrency(this.budgetValue - this.actualValue)}
            </span>
          </div>
        </div>
      </div>
    `
    
    this.infoTarget.innerHTML = infoHtml
  }

  getStatusColor() {
    const colors = {
      safe: '#22C55E',    // green-500
      normal: '#3B82F6',  // blue-500
      warning: '#FB923C', // orange-400
      danger: '#EF4444'   // red-500
    }
    return colors[this.statusValue] || colors.normal
  }

  getStatusText() {
    const texts = {
      safe: '안전',
      normal: '정상',
      warning: '주의',
      danger: '위험'
    }
    return texts[this.statusValue] || '정상'
  }

  formatCurrency(value) {
    return new Intl.NumberFormat('ko-KR', { 
      style: 'currency', 
      currency: 'KRW',
      maximumFractionDigits: 0
    }).format(value)
  }
}