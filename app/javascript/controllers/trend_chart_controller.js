import { Controller } from "@hotwired/stimulus"

let Chart

export default class extends Controller {
  static targets = ["canvas"]
  static values = { 
    data: Array,
    period: { type: String, default: "this_month" }
  }

  async connect() {
    console.log("Trend chart controller connected")
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
    
    // 차트 유형 결정 (데이터 포인트 수에 따라)
    const chartType = this.dataValue.length > 7 ? 'line' : 'bar'
    
    this.chart = new Chart(ctx, {
      type: chartType,
      data: {
        labels: this.dataValue.map(d => d.label),
        datasets: [{
          label: '경비 금액',
          data: this.dataValue.map(d => d.amount),
          backgroundColor: chartType === 'bar' 
            ? 'rgba(59, 130, 246, 0.8)' 
            : 'rgba(59, 130, 246, 0.1)',
          borderColor: 'rgba(59, 130, 246, 1)',
          borderWidth: 2,
          borderRadius: chartType === 'bar' ? 4 : 0,
          fill: chartType === 'line',
          tension: 0.4,
          pointBackgroundColor: 'rgba(59, 130, 246, 1)',
          pointBorderColor: '#fff',
          pointBorderWidth: 2,
          pointRadius: 4,
          pointHoverRadius: 6
        }]
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        animation: {
          duration: 1000,
          easing: 'easeInOutQuart'
        },
        interaction: {
          mode: 'index',
          intersect: false
        },
        plugins: {
          legend: {
            display: false
          },
          tooltip: {
            callbacks: {
              title: function(tooltipItems) {
                const item = this.dataValue[tooltipItems[0].dataIndex]
                return item.period // 전체 날짜 표시
              }.bind(this),
              label: function(context) {
                return `경비: ${new Intl.NumberFormat('ko-KR', { 
                  style: 'currency', 
                  currency: 'KRW' 
                }).format(context.parsed.y)}`
              }
            }
          }
        },
        scales: {
          y: {
            beginAtZero: true,
            ticks: {
              callback: function(value) {
                return new Intl.NumberFormat('ko-KR', {
                  notation: 'compact',
                  compactDisplay: 'short'
                }).format(value)
              }
            },
            grid: {
              drawBorder: false
            }
          },
          x: {
            ticks: {
              maxRotation: 45,
              minRotation: 0,
              autoSkip: true,
              maxTicksLimit: 12
            },
            grid: {
              display: false
            }
          }
        }
      }
    })
  }

  // 추세 분석 정보 표시
  showTrendAnalysis() {
    if (this.dataValue.length < 2) return

    const values = this.dataValue.map(d => d.amount)
    const average = values.reduce((a, b) => a + b, 0) / values.length
    const max = Math.max(...values)
    const min = Math.min(...values)
    
    // 추세 계산 (간단한 선형 회귀)
    const trend = this.calculateTrend(values)
    
    // 분석 결과를 UI에 표시 (필요시 구현)
    console.log('Trend Analysis:', {
      average,
      max,
      min,
      trend: trend > 0 ? 'increasing' : trend < 0 ? 'decreasing' : 'stable'
    })
  }

  calculateTrend(values) {
    const n = values.length
    let sumX = 0
    let sumY = 0
    let sumXY = 0
    let sumXX = 0

    for (let i = 0; i < n; i++) {
      sumX += i
      sumY += values[i]
      sumXY += i * values[i]
      sumXX += i * i
    }

    return (n * sumXY - sumX * sumY) / (n * sumXX - sumX * sumX)
  }

  // 데이터 업데이트 메서드
  updateData(newData) {
    this.dataValue = newData
    if (this.chart) {
      this.chart.destroy()
      this.initializeChart()
    }
  }

  // 차트 타입 변경
  toggleChartType() {
    if (this.chart) {
      const currentType = this.chart.config.type
      this.chart.config.type = currentType === 'line' ? 'bar' : 'line'
      this.chart.update('active')
    }
  }
}