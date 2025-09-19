import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["fileInput", "attachmentsList"]
  static values = { expenseSheetId: Number }
  
  connect() {
    console.log("Sheet attachment uploader connected for sheet:", this.expenseSheetIdValue)
    console.log("Available targets:", this.fileInputTarget, this.attachmentsListTarget)
    this.csrfToken = document.querySelector('meta[name="csrf-token"]').content
    
    // 기존 첨부파일의 상태 체크 시작
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
    console.log("Trigger file select clicked")
    event.preventDefault()
    if (this.hasFileInputTarget) {
      console.log("File input target found, clicking...")
      this.fileInputTarget.click()
    } else {
      console.error("File input target not found!")
    }
  }
  
  // 파일 선택 시 즉시 업로드
  fileSelected(event) {
    console.log("File selected event triggered")
    const files = event.target.files
    console.log("Selected files:", files)
    if (files.length > 0) {
      Array.from(files).forEach(file => {
        console.log("Uploading file:", file.name, file.type, file.size)
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
    formData.append('expense_sheet_attachment[file]', file)
    
    try {
      // 임시 UI 추가 (업로드 중 표시)
      const tempId = `temp-${Date.now()}`
      this.addUploadingItem(tempId, file.name)
      
      // 파일 업로드 - JSON 응답 우선
      const response = await fetch(`/expense_sheets/${this.expenseSheetIdValue}/expense_sheet_attachments`, {
        method: 'POST',
        headers: {
          'X-CSRF-Token': this.csrfToken,
          'Accept': 'application/json'
        },
        body: formData
      })
      
      if (response.ok) {
        const data = await response.json()
        // 임시 UI 제거하고 실제 첨부파일 항목 추가
        this.removeUploadingItem(tempId)
        this.addAttachmentItem(data.id, data.file_name, data.status || 'processing', data.processing_stage || 'pending')
        // 상태 체크 시작
        this.startStatusCheck(data.id)
      } else {
        console.error('Upload failed:', response.statusText)
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
      <div id="${tempId}" class="flex items-center justify-between p-3 bg-white border border-gray-200 rounded-lg mb-2 hover:shadow-sm transition-shadow">
        <div class="flex items-center flex-1">
          <svg class="h-8 w-8 text-gray-400 mr-3" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" />
          </svg>
          <div class="flex-1">
            <p class="text-sm font-medium text-gray-900">${fileName}</p>
            <p class="text-xs text-blue-600">업로드중</p>
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
  addAttachmentItem(id, fileName, status, processingStage) {
    const statusText = this.getStatusText(status, processingStage)
    const statusClass = this.getStatusClass(status, processingStage)
    
    const html = `
      <div id="sheet-attachment-${id}" class="flex items-center justify-between p-3 bg-white border border-gray-200 rounded-lg mb-2 hover:shadow-sm transition-shadow">
        <input type="hidden" name="sheet_attachment_ids[]" value="${id}" />
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
                  class="hidden text-sm text-indigo-600 hover:text-indigo-500 flex items-center gap-1"
                  data-view-btn-id="${id}"
                  data-action="click->sheet-attachment-uploader#viewSummary"
                  data-attachment-id="${id}">
            <svg class="h-4 w-4" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M2.458 12C3.732 7.943 7.523 5 12 5c4.478 0 8.268 2.943 9.542 7-1.274 4.057-5.064 7-9.542 7-4.477 0-8.268-2.943-9.542-7z" />
            </svg>
            내용 보기
          </button>
          <button type="button"
                  class="text-gray-400 hover:text-red-500"
                  data-action="click->sheet-attachment-uploader#removeAttachment"
                  data-attachment-id="${id}">
            <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M19 7l-.867 12.142A2 2 0 0116.138 21H7.862a2 2 0 01-1.995-1.858L5 7m5 4v6m4-6v6m1-10V4a1 1 0 00-1-1h-4a1 1 0 00-1 1v3M4 7h16" />
            </svg>
          </button>
        </div>
      </div>
    `
    
    // 기존 항목이 있는지 확인
    const existing = document.getElementById(`sheet-attachment-${id}`)
    if (existing) {
      existing.outerHTML = html
    } else {
      this.attachmentsListTarget.insertAdjacentHTML('afterbegin', html)
    }
  }
  
  // 상태 텍스트 반환
  getStatusText(status, processingStage) {
    if (status === 'uploading') {
      return '업로드중...'
    } else if (status === 'processing') {
      // 추출 단계 없이 바로 분석으로
      if (processingStage === 'summarizing') {
        return 'AI 분석중...'
      } else {
        return 'AI 분석중...'
      }
    } else if (status === 'completed') {
      return 'AI 분석 완료'
    } else if (status === 'failed') {
      return 'AI 분석 실패'
    } else if (status === 'pending') {
      return '업로드중...'
    }
    return '업로드중...'
  }
  
  // 상태 클래스 반환
  getStatusClass(status, processingStage) {
    if (status === 'uploading') {
      return 'text-blue-600'
    } else if (status === 'processing') {
      // 추출 단계 없이 바로 분석으로
      if (processingStage === 'summarizing') {
        return 'text-purple-600'
      } else {
        return 'text-purple-600'
      }
    } else if (status === 'completed') {
      return 'text-green-600'
    } else if (status === 'failed') {
      return 'text-red-600'
    } else if (status === 'pending') {
      return 'text-blue-600'
    }
    return 'text-blue-600'
  }
  
  // 상태 체크 시작
  startStatusCheck(attachmentId) {
    if (!this.statusCheckIntervals) {
      this.statusCheckIntervals = []
    }
    
    const interval = setInterval(async () => {
      try {
        const response = await fetch(`/expense_sheets/${this.expenseSheetIdValue}/expense_sheet_attachments/${attachmentId}/status`, {
          headers: {
            'Accept': 'application/json',
            'X-CSRF-Token': this.csrfToken
          }
        })
        
        if (response.ok) {
          const data = await response.json()
          this.updateAttachmentStatus(attachmentId, data.status, data.processing_stage, data.analysis_result)
          
          if (data.status === 'completed' || data.status === 'failed') {
            // 상태 체크 중지
            clearInterval(interval)
            const index = this.statusCheckIntervals.indexOf(interval)
            if (index > -1) {
              this.statusCheckIntervals.splice(index, 1)
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
  updateAttachmentStatus(id, status, processingStage, analysisResult) {
    const statusElement = document.querySelector(`[data-status-id="${id}"]`)
    if (statusElement) {
      // getStatusText와 getStatusClass 메서드 재사용
      const statusText = this.getStatusText(status, processingStage)
      const statusClass = this.getStatusClass(status, processingStage)
      
      statusElement.textContent = statusText
      statusElement.className = `text-xs ${statusClass}`
    }
    
    // 분석 완료 시 "내용 보기" 버튼 표시
    if (status === 'completed') {
      const viewBtn = document.querySelector(`[data-view-btn-id="${id}"]`)
      if (viewBtn) {
        viewBtn.classList.remove('hidden')
        viewBtn.classList.add('flex')  // flex 추가
        // 분석 결과를 데이터 속성에 저장
        if (analysisResult) {
          viewBtn.dataset.analysisResult = typeof analysisResult === 'string' ? analysisResult : JSON.stringify(analysisResult)
        }
      }
      
      // AI 검증 버튼 활성화 체크
      this.checkAndEnableAIValidation()
    }
  }
  
  // AI 검증 버튼 활성화 체크
  checkAndEnableAIValidation() {
    // AI validation 컨트롤러가 있는지 확인
    const aiValidationElement = document.querySelector('[data-controller="ai-validation"]')
    if (aiValidationElement) {
      // 완료된 첨부파일이 있는지 확인
      const completedAttachments = document.querySelectorAll('[data-status-id]')
      let hasCompleted = false
      
      completedAttachments.forEach(element => {
        if (element.textContent === 'AI 분석 완료') {
          hasCompleted = true
        }
      })
      
      if (hasCompleted) {
        // AI 검증 버튼 활성화
        const validateButton = aiValidationElement.querySelector('[data-ai-validation-target="validateButton"]')
        if (validateButton) {
          validateButton.disabled = false
          validateButton.classList.remove('text-gray-400', 'bg-gray-200', 'cursor-not-allowed')
          validateButton.classList.add('text-white', 'bg-green-600', 'hover:bg-green-700', 'focus:outline-none', 'focus:ring-2', 'focus:ring-offset-2', 'focus:ring-green-500')
          
          // 안내 메시지 업데이트
          const statusMessage = aiValidationElement.querySelector('.validation-status-message')
          if (statusMessage && statusMessage.textContent.includes('AI 분석이 완료된')) {
            statusMessage.textContent = '검증 버튼을 클릭하여 경비 항목을 검증하세요.'
          }
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
    // 서버에서 최신 데이터 가져오기
    this.fetchAndShowSummary(attachmentId)
  }
  
  // 서버에서 텍스트 가져와서 표시
  async fetchAndShowText(attachmentId) {
    try {
      const response = await fetch(`/expense_sheets/${this.expenseSheetIdValue}/expense_sheet_attachments/${attachmentId}/status`, {
        headers: {
          'Accept': 'application/json',
          'X-CSRF-Token': this.csrfToken
        }
      })
      
      if (response.ok) {
        const data = await response.json()
        if (data.analysis_result) {
          this.showTextModal(attachmentId, null, data.analysis_result)
        }
      }
    } catch (error) {
      console.error('Error fetching text:', error)
    }
  }
  
  // 서버에서 AI 분석 결과 가져와서 표시
  async fetchAndShowSummary(attachmentId) {
    try {
      const response = await fetch(`/expense_sheets/${this.expenseSheetIdValue}/expense_sheet_attachments/${attachmentId}/status`, {
        headers: {
          'Accept': 'application/json',
          'X-CSRF-Token': this.csrfToken
        }
      })
      
      if (response.ok) {
        const data = await response.json()
        console.log('Fetched data:', data) // 디버깅 로그
        if (data.analysis_result) {
          // showTextModal을 재사용하여 요약 표시
          this.showTextModal(attachmentId, null, data.analysis_result)
        }
      }
    } catch (error) {
      console.error('Error fetching summary:', error)
    }
  }
  
  // 텍스트 모달 표시
  showTextModal(attachmentId, text, analysisResult = null) {
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
    
    // AI 요약 데이터 파싱
    let summaryHtml = ''
    let jsonHtml = ''  // JSON 데이터 표시용
    console.log('showTextModal - analysisResult:', analysisResult) // 디버깅 로그
    if (analysisResult && analysisResult.summary_data) {
      const summaryData = typeof analysisResult.summary_data === 'string' ? 
        JSON.parse(analysisResult.summary_data) : analysisResult.summary_data
      
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
      let receiptType = summaryData.type || summaryData.receipt_type || 'unknown'
      const data = summaryData.data || summaryData.summary || summaryData
      
      // type이 없고 transactions가 있으면 corporate_card로 판단
      if ((!receiptType || receiptType === 'unknown') && data.transactions && Array.isArray(data.transactions)) {
        receiptType = 'corporate_card'
      }
      
      console.log('Receipt type:', receiptType) // 디버깅 로그
      console.log('Data:', data) // 디버깅 로그
      
      // 타입별 렌더링
      if (receiptType === 'corporate_card') {
        // 법인카드 명세서 - 테이블 형식
        if (data.transactions && Array.isArray(data.transactions)) {
          summaryHtml = `
            <div class="mt-4">
              <h4 class="text-sm font-medium text-gray-700 mb-2">법인카드 명세서 분석 결과</h4>
              <div class="p-4 bg-blue-50 border border-blue-200 rounded-lg">
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
                            <td class="text-right px-2 py-1 font-medium">₩${(tx.total || tx.amount || 0).toLocaleString()}</td>
                          </tr>
                        `).join('')}
                      </tbody>
                      <tfoot>
                        <tr class="font-bold border-t-2">
                          <td colspan="2" class="px-2 py-2">합계</td>
                          <td class="text-right px-2 py-2">₩${(data.total_amount || 0).toLocaleString()}</td>
                          <td class="text-right px-2 py-2">₩${(data.total_fee || 0).toLocaleString()}</td>
                          <td class="text-right px-2 py-2 text-blue-600">₩${(data.grand_total || data.total_amount || 0).toLocaleString()}</td>
                        </tr>
                      </tfoot>
                    </table>
                  </div>
                </div>
              </div>
            </div>
          `
        }
      } else if (receiptType === 'telecom') {
        // 통신비 영수증
        summaryHtml = `
          <div class="mt-4">
            <h4 class="text-sm font-medium text-gray-700 mb-2">통신비 영수증 분석 결과</h4>
            <div class="p-4 bg-blue-50 border border-blue-200 rounded-lg">
              <div class="space-y-1">
                ${data.total_amount ? `
                  <p class="text-lg text-gray-900 mb-2"><span class="font-bold">총 청구금액:</span> ₩${data.total_amount.toLocaleString()}</p>
                ` : ''}
                ${data.billing_period ? `
                  <p class="text-sm text-gray-700"><span class="font-medium">사용기간:</span> ${data.billing_period}</p>
                ` : ''}
                <div class="ml-4 border-l-2 border-gray-300 pl-3">
                  ${data.service_charge ? `
                    <p class="text-sm text-gray-700"><span class="font-medium">통신 서비스 요금:</span> ₩${data.service_charge.toLocaleString()}</p>
                  ` : ''}
                  ${data.additional_service_charge && data.additional_service_charge > 0 ? `
                    <p class="text-sm text-gray-700"><span class="font-medium">부가 서비스 요금:</span> ₩${data.additional_service_charge.toLocaleString()}</p>
                  ` : ''}
                  ${data.device_installment && data.device_installment > 0 ? `
                    <p class="text-sm text-gray-700"><span class="font-medium">단말기 할부금:</span> ₩${data.device_installment.toLocaleString()}</p>
                  ` : ''}
                  ${data.other_charges && data.other_charges > 0 ? `
                    <p class="text-sm text-gray-700"><span class="font-medium">기타 요금:</span> ₩${data.other_charges.toLocaleString()}</p>
                  ` : ''}
                  ${data.discount_amount && data.discount_amount > 0 ? `
                    <p class="text-sm text-red-600"><span class="font-medium">할인 금액:</span> -₩${data.discount_amount.toLocaleString()}</p>
                  ` : ''}
                </div>
              </div>
            </div>
          </div>
        `
      } else if (receiptType === 'general') {
        // 일반 영수증
        summaryHtml = `
          <div class="mt-4">
            <h4 class="text-sm font-medium text-gray-700 mb-2">일반 영수증 분석 결과</h4>
            <div class="p-4 bg-blue-50 border border-blue-200 rounded-lg">
              <dl class="grid grid-cols-2 gap-4 text-sm">
                ${data.store_name ? `
                  <div>
                    <dt class="font-medium text-gray-600">상호명</dt>
                    <dd class="mt-1 text-gray-900">${escapeHtml(data.store_name)}</dd>
                  </div>
                ` : ''}
                ${data.date ? `
                  <div>
                    <dt class="font-medium text-gray-600">날짜</dt>
                    <dd class="mt-1 text-gray-900">${escapeHtml(data.date)}</dd>
                  </div>
                ` : ''}
                ${data.location ? `
                  <div>
                    <dt class="font-medium text-gray-600">위치</dt>
                    <dd class="mt-1 text-gray-900">${escapeHtml(data.location)}</dd>
                  </div>
                ` : ''}
                ${data.total_amount ? `
                  <div>
                    <dt class="font-medium text-gray-600">총 금액</dt>
                    <dd class="mt-1 text-gray-900">₩${data.total_amount.toLocaleString()}</dd>
                  </div>
                ` : ''}
              </dl>
              ${data.items && data.items.length > 0 ? `
                <div class="mt-4">
                  <h5 class="font-medium text-gray-600 mb-2">구매 항목</h5>
                  <ul class="space-y-1">
                    ${data.items.map(item => `
                      <li class="flex justify-between text-gray-700">
                        <span>${escapeHtml(item.name)}</span>
                        <span class="font-medium">₩${item.amount.toLocaleString()}</span>
                      </li>
                    `).join('')}
                  </ul>
                </div>
              ` : ''}
            </div>
          </div>
        `
      } else if (receiptType === 'unknown') {
        // 분류 불가
        summaryHtml = `
          <div class="mt-4">
            <h4 class="text-sm font-medium text-gray-700 mb-2">문서 분석 결과</h4>
            <div class="p-4 bg-yellow-50 border border-yellow-200 rounded-lg">
              <p class="text-sm text-gray-700">${escapeHtml(data.summary_text || '문서 타입을 식별할 수 없습니다.')}</p>
            </div>
          </div>
        `
      } else {
        // 타입이 없는 경우 기본 처리
        summaryHtml = `
          <div class="mt-4">
            <h4 class="text-sm font-medium text-gray-700 mb-2">분석 결과</h4>
            <div class="p-4 bg-blue-50 border border-blue-200 rounded-lg">
              <pre class="text-sm text-gray-700 whitespace-pre-wrap">${JSON.stringify(data, null, 2)}</pre>
            </div>
          </div>
        `
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
  
  // 첨부파일 삭제
  async removeAttachment(event) {
    if (!confirm('이 첨부파일을 삭제하시겠습니까?')) return
    
    const attachmentId = event.currentTarget.dataset.attachmentId
    const attachmentElement = document.getElementById(`sheet-attachment-${attachmentId}`)
    
    try {
      const response = await fetch(`/expense_sheets/${this.expenseSheetIdValue}/expense_sheet_attachments/${attachmentId}`, {
        method: 'DELETE',
        headers: {
          'X-CSRF-Token': this.csrfToken,
          'Accept': 'application/json'
        }
      })
      
      if (response.ok) {
        // 성공 시 화면에서 제거
        if (attachmentElement) {
          attachmentElement.remove()
        }
        // hidden field도 제거
        const hiddenField = document.querySelector(`input[type="hidden"][value="${attachmentId}"][name="sheet_attachment_ids[]"]`)
        if (hiddenField) {
          hiddenField.remove()
        }
      } else if (response.status === 404) {
        // 이미 삭제된 경우에도 화면에서 제거
        console.warn(`Attachment ${attachmentId} not found on server, removing from UI`)
        if (attachmentElement) {
          attachmentElement.remove()
        }
        // hidden field도 제거
        const hiddenField = document.querySelector(`input[type="hidden"][value="${attachmentId}"][name="sheet_attachment_ids[]"]`)
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
      const currentStatus = element.textContent.trim()
      // 완료나 실패가 아닌 모든 상태에서 체크 시작
      if (currentStatus !== 'AI 분석 완료' && currentStatus !== 'AI 분석 실패' && currentStatus !== '완료' && currentStatus !== '실패') {
        this.startStatusCheck(id)
      }
    })
  }
}