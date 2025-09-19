import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["chartContainer", "exportButton"]
  
  connect() {
    console.log("Chart export controller connected")
  }

  // PNG로 차트 내보내기
  exportAsPNG(event) {
    event.preventDefault()
    
    const chartCanvas = this.chartContainerTarget.querySelector('canvas')
    if (!chartCanvas) {
      console.error('Chart canvas not found')
      return
    }

    // Canvas를 Blob으로 변환
    chartCanvas.toBlob((blob) => {
      const url = URL.createObjectURL(blob)
      const link = document.createElement('a')
      link.href = url
      link.download = `chart_${new Date().toISOString().split('T')[0]}.png`
      link.click()
      URL.revokeObjectURL(url)
    })
  }

  // CSV로 데이터 내보내기
  exportAsCSV(event) {
    event.preventDefault()
    
    const chartController = this.chartContainerTarget.querySelector('[data-controller*="chart"]')
    if (!chartController) {
      console.error('Chart controller not found')
      return
    }

    // 차트 타입에 따라 데이터 추출
    let csvContent = ''
    const controllerName = chartController.dataset.controller
    
    if (controllerName.includes('organization-chart')) {
      csvContent = this.generateOrganizationCSV(chartController)
    } else if (controllerName.includes('expense-code-chart')) {
      csvContent = this.generateExpenseCodeCSV(chartController)
    } else if (controllerName.includes('trend-chart')) {
      csvContent = this.generateTrendCSV(chartController)
    } else if (controllerName.includes('budget-gauge')) {
      csvContent = this.generateBudgetCSV(chartController)
    }

    if (csvContent) {
      this.downloadCSV(csvContent, `${controllerName}_export.csv`)
    }
  }

  generateOrganizationCSV(controller) {
    const data = JSON.parse(controller.dataset.organizationChartDataValue || '[]')
    let csv = '\uFEFF조직명,금액,비율(%)\n' // BOM 추가 for 한글
    
    data.forEach(item => {
      csv += `"${item.name}",${item.amount},${item.percentage}\n`
    })
    
    return csv
  }

  generateExpenseCodeCSV(controller) {
    const data = JSON.parse(controller.dataset.expenseCodeChartDataValue || '[]')
    let csv = '\uFEFF경비코드,경비명,금액,비율(%),건수\n'
    
    data.forEach(item => {
      csv += `"${item.code}","${item.name}",${item.amount},${item.percentage},${item.item_count}\n`
    })
    
    return csv
  }

  generateTrendCSV(controller) {
    const data = JSON.parse(controller.dataset.trendChartDataValue || '[]')
    let csv = '\uFEFF기간,날짜,금액\n'
    
    data.forEach(item => {
      csv += `"${item.label}","${item.period}",${item.amount}\n`
    })
    
    return csv
  }

  generateBudgetCSV(controller) {
    const name = controller.dataset.budgetGaugeNameValue
    const budget = controller.dataset.budgetGaugeBudgetValue
    const actual = controller.dataset.budgetGaugeActualValue
    const rate = controller.dataset.budgetGaugeRateValue
    const status = controller.dataset.budgetGaugeStatusValue
    
    let csv = '\uFEFF코스트센터,예산,사용액,실행률(%),상태\n'
    csv += `"${name}",${budget},${actual},${rate},"${this.getStatusText(status)}"\n`
    
    return csv
  }

  getStatusText(status) {
    const texts = {
      safe: '안전',
      normal: '정상',
      warning: '주의',
      danger: '위험'
    }
    return texts[status] || status
  }

  downloadCSV(content, filename) {
    const blob = new Blob([content], { type: 'text/csv;charset=utf-8;' })
    const url = URL.createObjectURL(blob)
    const link = document.createElement('a')
    link.href = url
    link.download = filename
    link.click()
    URL.revokeObjectURL(url)
  }

  // 인쇄용 레이아웃
  printChart(event) {
    event.preventDefault()
    
    const chartContainer = this.chartContainerTarget
    const printWindow = window.open('', '_blank')
    
    // 차트 캔버스를 이미지로 변환
    const canvas = chartContainer.querySelector('canvas')
    const imageUrl = canvas.toDataURL('image/png')
    
    const printContent = `
      <!DOCTYPE html>
      <html>
      <head>
        <title>차트 인쇄</title>
        <style>
          body { 
            font-family: Arial, sans-serif; 
            margin: 20px;
          }
          h1 { 
            font-size: 24px; 
            margin-bottom: 20px;
          }
          .chart-image {
            max-width: 100%;
            height: auto;
          }
          .print-date {
            margin-top: 20px;
            font-size: 12px;
            color: #666;
          }
          @media print {
            body { margin: 0; }
          }
        </style>
      </head>
      <body>
        <h1>경비 관리 시스템 - 차트</h1>
        <img src="${imageUrl}" class="chart-image" />
        <div class="print-date">
          인쇄일: ${new Date().toLocaleString('ko-KR')}
        </div>
      </body>
      </html>
    `
    
    printWindow.document.write(printContent)
    printWindow.document.close()
    
    // 이미지 로드 후 인쇄
    printWindow.onload = function() {
      printWindow.print()
      printWindow.close()
    }
  }
}