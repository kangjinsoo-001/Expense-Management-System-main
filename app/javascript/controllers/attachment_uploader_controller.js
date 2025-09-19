import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "fileInput", "attachmentsList", "uploadButton"
  ]
  
  static values = {
    expenseSheetId: Number,
    expenseItemId: Number
  }
  
  connect() {
    console.log("Attachment uploader connected")
    // 기존 첨부파일 상태 확인 (자동 새로고침 시작)
    this.checkExistingAttachments()
  }
  
  disconnect() {
    // 상태 체크 인터벌 정리
    if (this.statusCheckIntervals) {
      this.statusCheckIntervals.forEach(interval => clearInterval(interval))
    }
  }
  
  // 파일 선택 버튼 클릭 처리
  triggerFileSelect(event) {
    event.preventDefault()
    this.fileInputTarget.click()
  }
  
  // 파일 선택 시 즉시 업로드 (기존 기능 유지)
  fileSelected(event) {
    const files = event.target.files
    if (files.length > 0) {
      Array.from(files).forEach(file => {
        this.uploadFile(file)
      })
      // 입력 필드 초기화
      event.target.value = ''
    }
  }
  
  // 파일 업로드 처리
  async uploadFile(file) {
    // 파일 타입 검증
    const acceptedTypes = ['application/pdf', 'image/jpeg', 'image/jpg', 'image/png']
    if (!acceptedTypes.includes(file.type)) {
      alert('PDF, JPG, PNG 파일만 업로드 가능합니다.')
      return
    }
    
    // 파일 크기 검증 (10MB)
    if (file.size > 10 * 1024 * 1024) {
      alert('파일 크기는 10MB 이하여야 합니다.')
      return
    }
    
    // FormData 생성
    const formData = new FormData()
    formData.append('attachment[file]', file)
    
    // CSRF 토큰
    const csrfToken = document.querySelector('[name="csrf-token"]').content
    
    try {
      // 임시 UI 추가 (업로드 중 표시)
      const tempId = `temp-${Date.now()}`
      this.addUploadingItem(tempId, file.name)
      
      // 파일 업로드
      const response = await fetch('/expense_attachments/upload_and_extract', {
        method: 'POST',
        headers: {
          'X-CSRF-Token': csrfToken,
          'Accept': 'application/json'
        },
        body: formData
      })
      
      if (response.ok) {
        const data = await response.json()
        // 임시 UI 제거하고 실제 첨부파일 항목 추가
        this.removeUploadingItem(tempId)
        this.addAttachmentItem(data.id, file.name, 'processing')
        // 상태 체크 시작
        this.startStatusCheck(data.id)
        
        // 첨부파일 검증 다시 실행
        this.triggerAttachmentValidation()
      } else {
        this.removeUploadingItem(tempId)
        alert('파일 업로드 실패')
      }
    } catch (error) {
      console.error('Upload error:', error)
      alert('파일 업로드 중 오류가 발생했습니다.')
    }
  }
  
  // 업로드 중 임시 UI 추가
  addUploadingItem(tempId, fileName) {
    const html = `
      <div id="${tempId}" class="flex items-center justify-between p-3 bg-gray-50 rounded-lg mb-2">
        <div class="flex items-center">
          <svg class="animate-spin h-5 w-5 text-gray-400 mr-3" fill="none" viewBox="0 0 24 24">
            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
          </svg>
          <div>
            <p class="text-sm font-medium text-gray-900">${fileName}</p>
            <p class="text-xs text-gray-500">업로드 중...</p>
          </div>
        </div>
      </div>
    `
    this.attachmentsListTarget.insertAdjacentHTML('afterbegin', html)
  }
  
  // 임시 UI 제거
  removeUploadingItem(tempId) {
    const element = document.getElementById(tempId)
    if (element) element.remove()
  }
  
  // 첨부파일 항목 추가
  addAttachmentItem(id, fileName, status) {
    const statusText = this.getStatusText(status)
    const statusClass = this.getStatusClass(status)
    
    const html = `
      <div id="attachment-${id}" class="flex items-center justify-between p-3 bg-white border border-gray-200 rounded-lg mb-2 hover:shadow-sm transition-shadow">
        <input type="hidden" name="attachment_ids[]" value="${id}" />
        <div class="flex items-center flex-1">
          <svg class="h-8 w-8 text-gray-400 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
          </svg>
          <div class="flex-1">
            <p class="text-sm font-medium text-gray-900">${fileName}</p>
            <p class="text-xs ${statusClass}" data-status-id="${id}">${statusText}</p>
          </div>
        </div>
        <div class="flex items-center space-x-2">
          <button type="button" 
                  class="hidden text-sm text-indigo-600 hover:text-indigo-500"
                  data-view-btn-id="${id}"
                  data-action="click->attachment-uploader#viewExtractedText"
                  data-attachment-id="${id}">
            내용 보기
          </button>
          <button type="button"
                  class="text-gray-400 hover:text-red-500"
                  data-action="click->attachment-uploader#removeAttachment"
                  data-attachment-id="${id}">
            <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
            </svg>
          </button>
        </div>
      </div>
    `
    
    // 기존 항목이 있는지 확인
    const existing = document.getElementById(`attachment-${id}`)
    if (existing) {
      existing.outerHTML = html
    } else {
      this.attachmentsListTarget.insertAdjacentHTML('afterbegin', html)
    }
  }
  
  // 상태 텍스트 반환
  getStatusText(status) {
    const statusMap = {
      'uploading': '업로드중...',
      'processing': 'AI 분석중...',  // 추출 단계 없이 바로 분석중으로
      'completed': 'AI 분석 완료',
      'failed': 'AI 분석 실패'
    }
    return statusMap[status] || status
  }
  
  // 상태 클래스 반환
  getStatusClass(status) {
    const classMap = {
      'processing': 'text-yellow-600',
      'completed': 'text-green-600',
      'failed': 'text-red-600'
    }
    return classMap[status] || 'text-gray-500'
  }
  
  // 상태 체크 시작
  startStatusCheck(attachmentId) {
    if (!this.statusCheckIntervals) {
      this.statusCheckIntervals = []
    }
    
    const interval = setInterval(async () => {
      try {
        const response = await fetch(`/expense_attachments/${attachmentId}/status`, {
          headers: {
            'Accept': 'application/json',
            'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
          }
        })
        
        if (response.ok) {
          const data = await response.json()
          this.updateAttachmentStatus(attachmentId, data.status, data.processing_stage, data.extracted_text, data.summary_data)
          
          if (data.status === 'completed' || data.status === 'failed') {
            // 상태 체크 중지
            clearInterval(interval)
            const index = this.statusCheckIntervals.indexOf(interval)
            if (index > -1) {
              this.statusCheckIntervals.splice(index, 1)
            }
            
            // 완료 시 첨부파일 검증 다시 실행
            if (data.status === 'completed') {
              this.triggerAttachmentValidation()
            }
          }
        }
      } catch (error) {
        console.error('Status check error:', error)
      }
    }, 2000) // 2초마다 체크
    
    this.statusCheckIntervals.push(interval)
  }
  
  // 첨부파일 상태 업데이트
  updateAttachmentStatus(id, status, processingStage, extractedText, summaryData) {
    const statusElement = document.querySelector(`[data-status-id="${id}"]`)
    if (statusElement) {
      // processing_stage에 따라 상태 텍스트 결정
      let statusText = ''
      let statusClass = ''
      
      if (status === 'uploading') {
        statusText = '업로드중...'
        statusClass = 'text-blue-600'
      } else if (status === 'processing') {
        // 추출 단계 없이 바로 분석으로
        if (processingStage === 'summarizing') {
          statusText = 'AI 분석중...'
          statusClass = 'text-purple-600'
        } else {
          statusText = 'AI 처리중...'
          statusClass = 'text-yellow-600'
        }
      } else if (status === 'completed') {
        statusText = 'AI 분석 완료'
        statusClass = 'text-green-600'
      } else if (status === 'failed') {
        statusText = 'AI 처리 실패'
        statusClass = 'text-red-600'
      } else {
        statusText = status
        statusClass = 'text-gray-500'
      }
      
      statusElement.textContent = statusText
      statusElement.className = `text-xs ${statusClass}`
    }
    
    // 분석 완료 시 "내용 보기" 버튼 표시
    if (status === 'completed') {
      const viewBtn = document.querySelector(`[data-view-btn-id="${id}"]`)
      if (viewBtn) {
        viewBtn.classList.remove('hidden')
        // summary 데이터가 있으면 저장
        if (summaryData) {
          viewBtn.dataset.summaryData = typeof summaryData === 'string' ? summaryData : JSON.stringify(summaryData)
        }
      }
    }
  }
  
  // 추출된 텍스트 보기 (구 버전 - 호환성 유지)
  viewExtractedText(event) {
    const attachmentId = event.currentTarget.dataset.attachmentId
    // 항상 서버에서 최신 데이터를 가져오도록 변경
    this.fetchAndShowText(attachmentId)
  }
  
  // AI 분석 결과 보기
  viewSummary(event) {
    const attachmentId = event.currentTarget.dataset.attachmentId
    const summaryData = event.currentTarget.dataset.summaryData
    const receiptType = event.currentTarget.dataset.receiptType
    
    // 서버에서 최신 데이터 가져오기
    this.fetchAndShowSummary(attachmentId)
  }
  
  // 서버에서 텍스트 가져와서 표시
  async fetchAndShowText(attachmentId) {
    try {
      const response = await fetch(`/expense_attachments/${attachmentId}/status`, {
        headers: {
          'Accept': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        }
      })
      
      if (response.ok) {
        const data = await response.json()
        if (data.extracted_text || data.summary_data) {
          this.showTextModal(attachmentId, data.extracted_text, data)
        }
      }
    } catch (error) {
      console.error('Error fetching text:', error)
    }
  }
  
  // 서버에서 AI 분석 결과 가져와서 표시
  async fetchAndShowSummary(attachmentId) {
    try {
      const response = await fetch(`/expense_attachments/${attachmentId}/status`, {
        headers: {
          'Accept': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        }
      })
      
      if (response.ok) {
        const data = await response.json()
        console.log('Fetched data:', data) // 디버깅 로그
        if (data.summary_data) {
          // showTextModal을 재사용하여 요약 표시
          this.showTextModal(attachmentId, null, data)
        }
      }
    } catch (error) {
      console.error('Error fetching summary:', error)
    }
  }
  
  // 텍스트 모달 표시
  async showTextModal(attachmentId, text, fullData = null) {
    // 기존 모달 제거
    const existingModal = document.getElementById('text-view-modal')
    if (existingModal) existingModal.remove()
    
    // 텍스트 안전하게 이스케이프
    const escapeHtml = (str) => {
      const div = document.createElement('div')
      div.textContent = str
      return div.innerHTML
    }
    
    const safeText = escapeHtml(text || '')
    
    // AI 요약 HTML 생성 - 서버에서 가져오기 시도
    let summaryHtml = ''
    let jsonHtml = ''  // JSON 데이터 표시용
    console.log('showTextModal - fullData:', fullData) // 디버깅 로그
    
    // 서버에서 렌더링된 HTML을 가져오기 시도
    if (fullData && fullData.ai_processed && fullData.summary_data && attachmentId) {
      try {
        const response = await fetch(`/expense_sheets/${this.expenseSheetIdValue}/expense_items/${this.expenseItemIdValue}/expense_attachments/${attachmentId}/summary_html`)
        
        if (response.ok) {
          summaryHtml = await response.text()
          console.log('Got summary HTML from server')
        } else {
          console.log('Failed to get summary HTML from server, using fallback')
          // 서버 요청 실패 시 기존 클라이언트 렌더링 사용
          summaryHtml = this.generateSummaryHtmlFallback(fullData, escapeHtml)
        }
      } catch (error) {
        console.error('Error fetching summary HTML:', error)
        // 에러 발생 시 기존 클라이언트 렌더링 사용
        summaryHtml = this.generateSummaryHtmlFallback(fullData, escapeHtml)
      }
      
      // JSON 데이터 HTML 생성 (디버깅용)
      try {
        const summaryData = typeof fullData.summary_data === 'string' ? 
          JSON.parse(fullData.summary_data) : fullData.summary_data
        
        jsonHtml = `
          <div class="mt-4">
            <h4 class="text-sm font-medium text-gray-700 mb-2">원본 JSON 데이터</h4>
            <div class="p-4 bg-gray-900 text-gray-100 rounded-lg overflow-x-auto">
              <pre class="text-xs font-mono">${escapeHtml(JSON.stringify(summaryData, null, 2))}</pre>
            </div>
          </div>
        `
      } catch (e) {
        console.error('Error generating JSON HTML:', e)
      }
    } else if (fullData && fullData.ai_processed && fullData.summary_data) {
      try {
        const summaryData = typeof fullData.summary_data === 'string' ? 
          JSON.parse(fullData.summary_data) : fullData.summary_data
        
        console.log('Parsed summaryData:', summaryData) // 디버깅 로그
        
        // JSON 데이터 HTML 생성
        jsonHtml = `
          <div class="mt-4">
            <h4 class="text-sm font-medium text-gray-700 mb-2">원본 JSON 데이터</h4>
            <div class="p-4 bg-gray-900 text-gray-100 rounded-lg overflow-x-auto">
              <pre class="text-xs font-mono">${escapeHtml(JSON.stringify(summaryData, null, 2))}</pre>
            </div>
          </div>
        `
        
        // type과 data 분리
        let receiptType = summaryData.type || summaryData.receipt_type || fullData.receipt_type || 'unknown'
        const data = summaryData.data || summaryData.summary || summaryData
        
        // type이 없고 transactions가 있으면 corporate_card로 판단
        if ((!receiptType || receiptType === 'unknown') && data.transactions && Array.isArray(data.transactions)) {
          receiptType = 'corporate_card'
        }
        
        console.log('Receipt type:', receiptType) // 디버깅 로그
        console.log('Data:', data) // 디버깅 로그
        
        let summaryContent = ''
        
        // 타입별 렌더링
        if (receiptType === 'corporate_card') {
          // 법인카드 명세서 - 테이블 형식
          if (data.transactions && Array.isArray(data.transactions)) {
            summaryContent = `
              <div class="mb-4">
                <h5 class="font-medium text-gray-700 mb-2">거래 내역 (${data.transactions.length}건)</h5>
                <div class="overflow-x-auto">
                  <table class="min-w-full text-sm">
                    <thead>
                      <tr class="border-b">
                        <th class="text-left px-2 py-1 font-medium text-gray-600">날짜</th>
                        <th class="text-left px-2 py-1 font-medium text-gray-600">가맹점</th>
                        <th class="text-right px-2 py-1 font-medium text-gray-600">원금</th>
                        <th class="text-right px-2 py-1 font-medium text-gray-600">수수료</th>
                        <th class="text-right px-2 py-1 font-medium text-gray-600">합계</th>
                      </tr>
                    </thead>
                    <tbody>
                      ${data.transactions.map(tx => `
                        <tr class="border-b">
                          <td class="px-2 py-1">${escapeHtml(tx.date || '')}</td>
                          <td class="px-2 py-1">${escapeHtml(tx.merchant || '')}</td>
                          <td class="text-right px-2 py-1">₩${(tx.amount || 0).toLocaleString()}</td>
                          <td class="text-right px-2 py-1">₩${(tx.fee || 0).toLocaleString()}</td>
                          <td class="text-right px-2 py-1 font-medium">₩${(tx.total || 0).toLocaleString()}</td>
                        </tr>
                      `).join('')}
                    </tbody>
                    <tfoot>
                      <tr class="font-bold border-t-2">
                        <td colspan="2" class="px-2 py-2">합계</td>
                        <td class="text-right px-2 py-2">₩${(data.total_amount || 0).toLocaleString()}</td>
                        <td class="text-right px-2 py-2">₩${(data.total_fee || 0).toLocaleString()}</td>
                        <td class="text-right px-2 py-2 text-blue-600">₩${(data.grand_total || 0).toLocaleString()}</td>
                      </tr>
                    </tfoot>
                  </table>
                </div>
              </div>
            `
          }
        } else if (receiptType === 'telecom') {
          // 통신비 영수증
          summaryContent = '<div class="space-y-1">'
          if (data.total_amount) {
            summaryContent += `<p class="text-lg text-gray-900 mb-2"><span class="font-bold">총 청구금액:</span> ₩${data.total_amount.toLocaleString()}</p>`
          }
          if (data.billing_period) {
            summaryContent += `<p class="text-sm text-gray-700"><span class="font-medium">사용기간:</span> ${data.billing_period}</p>`
          }
          summaryContent += '<div class="ml-4 border-l-2 border-gray-300 pl-3">'
          if (data.service_charge) {
            summaryContent += `<p class="text-sm text-gray-700"><span class="font-medium">통신 서비스 요금:</span> ₩${data.service_charge.toLocaleString()}</p>`
          }
          if (data.additional_service_charge && data.additional_service_charge > 0) {
            summaryContent += `<p class="text-sm text-gray-700"><span class="font-medium">부가 서비스 요금:</span> ₩${data.additional_service_charge.toLocaleString()}</p>`
          }
          if (data.device_installment && data.device_installment > 0) {
            summaryContent += `<p class="text-sm text-gray-700"><span class="font-medium">단말기 할부금:</span> ₩${data.device_installment.toLocaleString()}</p>`
          }
          if (data.other_charges && data.other_charges > 0) {
            summaryContent += `<p class="text-sm text-gray-700"><span class="font-medium">기타 요금:</span> ₩${data.other_charges.toLocaleString()}</p>`
          }
          if (data.discount_amount && data.discount_amount > 0) {
            summaryContent += `<p class="text-sm text-red-600"><span class="font-medium">할인 금액:</span> -₩${data.discount_amount.toLocaleString()}</p>`
          }
          summaryContent += '</div></div>'
        } else if (receiptType === 'general') {
          // 일반 영수증
          summaryContent = '<div class="space-y-1">'
          if (data.store_name) {
            summaryContent += `<p class="text-sm text-gray-700"><span class="font-medium">상호명:</span> ${escapeHtml(data.store_name)}</p>`
          }
          if (data.date) {
            summaryContent += `<p class="text-sm text-gray-700"><span class="font-medium">날짜:</span> ${escapeHtml(data.date)}</p>`
          }
          if (data.location) {
            summaryContent += `<p class="text-sm text-gray-700"><span class="font-medium">위치:</span> ${escapeHtml(data.location)}</p>`
          }
          if (data.total_amount) {
            summaryContent += `<p class="text-sm text-gray-700"><span class="font-medium">총 금액:</span> ₩${data.total_amount.toLocaleString()}</p>`
          }
          if (data.items && Array.isArray(data.items) && data.items.length > 0) {
            summaryContent += '<div class="mt-2"><span class="font-medium text-sm text-gray-700">구매 항목:</span>'
            summaryContent += '<div class="ml-4 mt-1">'
            data.items.forEach(item => {
              if (item && item.name) {
                const itemAmount = item.amount ? `₩${item.amount.toLocaleString()}` : ''
                summaryContent += `<p class="text-xs text-gray-600">• ${escapeHtml(item.name)}: ${itemAmount}</p>`
              }
            })
            summaryContent += '</div></div>'
          }
          summaryContent += '</div>'
        } else if (receiptType === 'unknown') {
          // 분류 불가
          summaryContent = `<p class="text-sm text-gray-700">${escapeHtml(data.summary_text || '분석할 수 없음')}</p>`
        }
        
        if (summaryContent) {
          const receiptTypeLabel = {
            'corporate_card': '법인카드',
            'telecom': '통신비',
            'general': '일반',
            'unknown': '기타'
          }[receiptType] || receiptType
          
          summaryHtml = `
            <div class="mb-4">
              <div class="flex items-center mb-2">
                <svg class="h-5 w-5 mr-2 text-blue-600" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9.663 17h4.673M12 3v1m6.364 1.636l-.707.707M21 12h-1M4 12H3m3.343-5.657l-.707-.707m2.828 9.9a5 5 0 117.072 0l-.548.547A3.374 3.374 0 0014 18.469V19a2 2 0 11-4 0v-.531c0-.895-.356-1.754-.988-2.386l-.548-.547z" />
                </svg>
                <h4 class="text-sm font-medium text-blue-700">AI 분석 결과</h4>
                <span class="ml-2 px-2 py-0.5 text-xs bg-blue-100 text-blue-700 rounded">${receiptTypeLabel}</span>
              </div>
              <div class="p-3 bg-blue-50 border border-blue-200 rounded-lg">
                ${summaryContent}
              </div>
            </div>
          `
        }
      } catch (e) {
        console.error('Error parsing summary data:', e)
      }
    }
    
    const modalHtml = `
      <div id="text-view-modal" class="fixed inset-0 z-50 overflow-y-auto">
        <div class="fixed inset-0 bg-gray-500 bg-opacity-75 transition-opacity"></div>
        <div class="flex min-h-full items-center justify-center p-4">
          <div class="relative transform overflow-hidden rounded-lg bg-white shadow-xl transition-all sm:max-w-4xl sm:w-full">
            <div class="bg-white px-6 py-4 border-b border-gray-200">
              <div class="flex items-center justify-between">
                <h3 class="text-lg font-medium text-gray-900">첨부파일 분석 결과</h3>
                <button type="button" onclick="document.getElementById('text-view-modal').remove()"
                        class="text-gray-400 hover:text-gray-500">
                  <svg class="h-6 w-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                    <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
                  </svg>
                </button>
              </div>
            </div>
            <div class="bg-white px-6 py-4 max-h-[32rem] overflow-y-auto">
              ${summaryHtml || '<p class="text-gray-500">AI 분석 결과를 불러오는 중...</p>'}
              ${jsonHtml}
              ${text ? `
                <div class="mt-4">
                  <h4 class="text-sm font-medium text-gray-700 mb-2">추출된 원본 텍스트</h4>
                  <div class="p-4 bg-gray-50 border border-gray-200 rounded-lg">
                    <pre class="text-sm text-gray-700 whitespace-pre-wrap font-mono">${safeText}</pre>
                  </div>
                </div>
              ` : ''}
            </div>
            <div class="bg-gray-50 px-6 py-3 flex justify-end gap-2">
              <button type="button" 
                      onclick="navigator.clipboard.writeText(${JSON.stringify(text)}); alert('텍스트가 복사되었습니다.')"
                      class="inline-flex justify-center rounded-md border border-gray-300 shadow-sm px-4 py-2 bg-white text-sm font-medium text-gray-700 hover:bg-gray-50">
                <svg class="h-4 w-4 mr-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M8 16H6a2 2 0 01-2-2V6a2 2 0 012-2h8a2 2 0 012 2v2m-6 12h8a2 2 0 002-2v-8a2 2 0 00-2-2h-8a2 2 0 00-2 2v8a2 2 0 002 2z" />
                </svg>
                복사
              </button>
              <button type="button" onclick="document.getElementById('text-view-modal').remove()"
                      class="inline-flex justify-center rounded-md border border-gray-300 shadow-sm px-4 py-2 bg-white text-sm font-medium text-gray-700 hover:bg-gray-50">
                닫기
              </button>
            </div>
          </div>
        </div>
      </div>
    `
    
    document.body.insertAdjacentHTML('beforeend', modalHtml)
  }
  
  // Fallback: 클라이언트에서 AI 요약 HTML 생성
  generateSummaryHtmlFallback(fullData, escapeHtml) {
    if (!fullData || !fullData.summary_data) return ''
    
    try {
      const summaryData = typeof fullData.summary_data === 'string' ? 
        JSON.parse(fullData.summary_data) : fullData.summary_data
      
      // type과 data 분리
      let receiptType = summaryData.type || summaryData.receipt_type || fullData.receipt_type || 'unknown'
      const data = summaryData.data || summaryData.summary || summaryData
      
      // type이 없고 transactions가 있으면 corporate_card로 판단
      if ((!receiptType || receiptType === 'unknown') && data.transactions && Array.isArray(data.transactions)) {
        receiptType = 'corporate_card'
      }
      
      // 서버 partial과 동일한 스타일로 렌더링
      return `
        <div class="bg-white border border-gray-200 rounded-lg p-4 mb-4">
          <h4 class="text-sm font-medium text-gray-900 mb-3">AI 요약</h4>
          ${this.renderSummaryByType(receiptType, data, escapeHtml)}
        </div>
      `
    } catch (e) {
      console.error('Error in generateSummaryHtmlFallback:', e)
      return ''
    }
  }
  
  // 타입별 요약 렌더링 (서버 partial과 동일한 스타일)
  renderSummaryByType(receiptType, data, escapeHtml) {
    if (receiptType === 'telecom') {
      return `
        <div class="space-y-2">
          ${data.total_amount ? `
            <div class="flex items-center justify-between">
              <span class="text-xs text-gray-500">전체 청구 금액:</span>
              <span class="text-sm font-semibold text-gray-900">₩${data.total_amount.toLocaleString()}</span>
            </div>` : ''}
          ${data.service_charge ? `
            <div class="flex items-center justify-between">
              <span class="text-xs text-gray-500">통신 서비스:</span>
              <span class="text-sm text-gray-700">₩${data.service_charge.toLocaleString()}</span>
            </div>` : ''}
          ${data.additional_service_charge && data.additional_service_charge > 0 ? `
            <div class="flex items-center justify-between">
              <span class="text-xs text-gray-500">부가 서비스:</span>
              <span class="text-sm text-gray-700">₩${data.additional_service_charge.toLocaleString()}</span>
            </div>` : ''}
          ${data.other_charges && data.other_charges > 0 ? `
            <div class="flex items-center justify-between">
              <span class="text-xs text-gray-500">기타 요금:</span>
              <span class="text-sm text-gray-700">₩${data.other_charges.toLocaleString()}</span>
            </div>` : ''}
          ${data.device_installment && data.device_installment > 0 ? `
            <div class="flex items-center justify-between">
              <span class="text-xs text-gray-500">단말기 할부금:</span>
              <span class="text-sm text-gray-700">₩${data.device_installment.toLocaleString()}</span>
            </div>` : ''}
          ${data.discount_amount && data.discount_amount != 0 ? `
            <div class="flex items-center justify-between">
              <span class="text-xs text-gray-500">할인 금액:</span>
              <span class="text-sm text-red-600">-₩${Math.abs(data.discount_amount).toLocaleString()}</span>
            </div>` : ''}
          ${data.billing_period || data.billing_month ? `
            <div class="flex items-center justify-between">
              <span class="text-xs text-gray-500">청구 기간:</span>
              <span class="text-sm text-gray-700">${data.billing_period || data.billing_month}</span>
            </div>` : ''}
        </div>
      `
    } else if (receiptType === 'general') {
      return `
        <div class="space-y-2">
          ${data.store_name ? `
            <div class="flex items-center justify-between">
              <span class="text-xs text-gray-500">상호명:</span>
              <span class="text-sm text-gray-700">${escapeHtml(data.store_name)}</span>
            </div>` : ''}
          ${data.date ? `
            <div class="flex items-center justify-between">
              <span class="text-xs text-gray-500">날짜:</span>
              <span class="text-sm text-gray-700">${escapeHtml(data.date)}</span>
            </div>` : ''}
          ${data.location ? `
            <div class="flex items-center justify-between">
              <span class="text-xs text-gray-500">위치:</span>
              <span class="text-sm text-gray-700">${escapeHtml(data.location)}</span>
            </div>` : ''}
          ${data.total_amount ? `
            <div class="flex items-center justify-between">
              <span class="text-xs text-gray-500">총 금액:</span>
              <span class="text-sm font-semibold text-gray-900">₩${data.total_amount.toLocaleString()}</span>
            </div>` : ''}
          ${data.items && data.items.length > 0 ? `
            <div class="mt-2 pt-2 border-t border-gray-200">
              <span class="text-xs text-gray-500">구매 항목:</span>
              <div class="mt-1 space-y-1">
                ${data.items.map(item => `
                  <div class="flex items-center justify-between pl-2">
                    <span class="text-xs text-gray-600">• ${escapeHtml(item.name)}</span>
                    ${item.amount ? `<span class="text-xs text-gray-700">₩${item.amount.toLocaleString()}</span>` : ''}
                  </div>
                `).join('')}
              </div>
            </div>` : ''}
        </div>
      `
    } else {
      return `<p class="text-sm text-gray-700">${escapeHtml(data.summary_text || '요약 정보가 없습니다.')}</p>`
    }
  }
  
  // 첨부파일 삭제
  async removeAttachment(event) {
    if (!confirm('이 첨부파일을 삭제하시겠습니까?')) return
    
    const attachmentId = event.currentTarget.dataset.attachmentId
    const attachmentElement = document.getElementById(`attachment-${attachmentId}`)
    
    try {
      const response = await fetch(`/expense_attachments/${attachmentId}`, {
        method: 'DELETE',
        headers: {
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content,
          'Accept': 'application/json'
        }
      })
      
      if (response.ok) {
        // 성공 시 화면에서 제거
        if (attachmentElement) {
          attachmentElement.remove()
        }
        // hidden field도 제거
        const hiddenField = document.querySelector(`input[type="hidden"][value="${attachmentId}"][name="attachment_ids[]"]`)
        if (hiddenField) {
          hiddenField.remove()
        }
        // 첨부파일 검증 다시 실행
        this.triggerAttachmentValidation()
      } else if (response.status === 404) {
        // 이미 삭제된 경우에도 화면에서 제거
        console.warn(`Attachment ${attachmentId} not found on server, removing from UI`)
        if (attachmentElement) {
          attachmentElement.remove()
        }
        // hidden field도 제거
        const hiddenField = document.querySelector(`input[type="hidden"][value="${attachmentId}"][name="attachment_ids[]"]`)
        if (hiddenField) {
          hiddenField.remove()
        }
      } else {
        console.error('Delete failed with status:', response.status)
        alert('삭제 중 오류가 발생했습니다.')
      }
    } catch (error) {
      console.error('Delete error:', error)
      alert('삭제 중 오류가 발생했습니다.')
    }
  }
  
  // 기존 첨부파일 상태 확인
  checkExistingAttachments() {
    // 페이지 로드 시 이미 processing 상태인 첨부파일들의 상태 체크 시작
    const processingAttachments = document.querySelectorAll('[data-status-id]')
    processingAttachments.forEach(element => {
      const id = element.dataset.statusId
      const currentStatus = element.textContent
      if (currentStatus === '분석 중...') {
        this.startStatusCheck(id)
      }
    })
  }
  
  // 첨부파일 검증 트리거
  triggerAttachmentValidation() {
    console.log('첨부파일 검증 트리거')
    // client-validation 컨트롤러 찾기
    const form = document.querySelector('form[data-controller*="client-validation"]')
    if (form) {
      const controller = this.application.getControllerForElementAndIdentifier(
        form, 
        'client-validation'
      )
      if (controller && controller.validateAttachments) {
        console.log('validateAttachments 호출')
        controller.validateAttachments()
      } else {
        console.log('client-validation 컨트롤러 또는 validateAttachments 메서드를 찾을 수 없음')
      }
    }
  }
}