import { Controller } from "@hotwired/stimulus"

let Chart

export default class extends Controller {
  static targets = ["canvas"]
  static values = { 
    data: Array,
    maxItems: { type: Number, default: 8 }
  }

  async connect() {
    console.log("Expense code chart controller connected")
    await this.loadChartJS()
    this.initializeChart()
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
    
    // 상위 N개만 표시
    const chartData = this.dataValue.slice(0, this.maxItemsValue)
    
    // 나머지 항목들의 합계
    if (this.dataValue.length > this.maxItemsValue) {
      const others = this.dataValue.slice(this.maxItemsValue)
      const othersTotal = others.reduce((sum, item) => sum + item.amount, 0)
      const othersPercentage = others.reduce((sum, item) => sum + item.percentage, 0)
      chartData.push({
        code: 'OTHERS',
        name: `기타 (${others.length}개)`,
        amount: othersTotal,
        percentage: othersPercentage,
        item_count: others.reduce((sum, item) => sum + item.item_count, 0)
      })
    }

    // 색상 팔레트
    const colors = [
      'rgba(34, 197, 94, 0.8)',   // green-500
      'rgba(59, 130, 246, 0.8)',   // blue-500
      'rgba(168, 85, 247, 0.8)',   // purple-500
      'rgba(251, 146, 60, 0.8)',   // orange-400
      'rgba(236, 72, 153, 0.8)',   // pink-500
      'rgba(14, 165, 233, 0.8)',   // sky-500
      'rgba(250, 204, 21, 0.8)',   // yellow-400
      'rgba(239, 68, 68, 0.8)',    // red-500
      'rgba(156, 163, 175, 0.8)'   // gray-400 (기타)
    ]

    this.chart = new Chart(ctx, {
      type: 'doughnut',
      data: {
        labels: chartData.map(d => `${d.name} (${d.code})`),
        datasets: [{
          data: chartData.map(d => d.amount),
          backgroundColor: colors.slice(0, chartData.length),
          borderColor: colors.slice(0, chartData.length).map(c => c.replace('0.8', '1')),
          borderWidth: 2
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        animation: {
          animateRotate: true,
          animateScale: false,
          duration: 1000
        },
        plugins: {
          legend: {
            position: 'right',
            labels: {
              padding: 15,
              usePointStyle: true,
              font: {
                size: 12
              },
              generateLabels: function(chart) {
                const data = chart.data
                if (data.labels.length && data.datasets.length) {
                  return data.labels.map((label, i) => {
                    const dataset = data.datasets[0]
                    const value = dataset.data[i]
                    const item = chartData[i]
                    return {
                      text: `${label}: ${item.percentage}%`,
                      fillStyle: dataset.backgroundColor[i],
                      hidden: false,
                      index: i
                    }
                  })
                }
                return []
              }
            }
          },
          tooltip: {
            callbacks: {
              label: function(context) {
                const item = chartData[context.dataIndex]
                return [
                  `${item.name} (${item.code})`,
                  `금액: ${new Intl.NumberFormat('ko-KR', { 
                    style: 'currency', 
                    currency: 'KRW',
                    maximumFractionDigits: 0
                  }).format(item.amount)}`,
                  `비율: ${item.percentage}%`,
                  `건수: ${item.item_count}건`
                ]
              }
            }
          }
        },
        onClick: (event, activeElements) => {
          if (activeElements.length > 0) {
            const index = activeElements[0].index
            const item = chartData[index]
            this.handleChartClick(item)
          }
        }
      }
    })
  }

  handleChartClick(item) {
    console.log('Clicked expense code:', item)
    
    // 경비 코드 상세 페이지로 이동 (기타 제외)
    if (item.id && item.code !== 'OTHERS') {
      // Turbo.visit(`/admin/expense_codes/${item.id}/expenses`)
    }
  }

  // 데이터 업데이트 메서드
  updateData(newData) {
    this.dataValue = newData
    if (this.chart) {
      this.chart.destroy()
      this.initializeChart()
    }
  }
}