import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "fileInput", "dropZone", "selectedFile", "fileName", "fileSize",
    "uploadStep", "processingStep", "confirmStep",
    "processingStatus", "extractedText",
    "confirmButton"
  ]
  static values = { expenseItemId: Number }
  
  connect() {
    this.selectedFile = null
    this.attachmentId = null
    
    // 드래그 앤 드롭 이벤트 설정
    if (this.hasDropZoneTarget) {
      this.dropZoneTarget.addEventListener('dragover', this.handleDragOver.bind(this))
      this.dropZoneTarget.addEventListener('drop', this.handleDrop.bind(this))
      this.dropZoneTarget.addEventListener('dragleave', this.handleDragLeave.bind(this))
    }
  }
  
  disconnect() {
    if (this.hasDropZoneTarget) {
      this.dropZoneTarget.removeEventListener('dragover', this.handleDragOver)
      this.dropZoneTarget.removeEventListener('drop', this.handleDrop)
      this.dropZoneTarget.removeEventListener('dragleave', this.handleDragLeave)
    }
  }
  
  triggerFileSelect(event) {
    event.preventDefault()
    this.fileInputTarget.click()
  }
  
  fileSelected(event) {
    const file = event.target.files[0]
    if (file) {
      this.handleFile(file)
      // 파일 선택 시 즉시 업로드 시작
      this.uploadFile(new Event('auto'))
    }
  }
  
  handleDragOver(event) {
    event.preventDefault()
    this.dropZoneTarget.classList.add('border-indigo-500', 'bg-indigo-50')
  }
  
  handleDragLeave(event) {
    event.preventDefault()
    this.dropZoneTarget.classList.remove('border-indigo-500', 'bg-indigo-50')
  }
  
  handleDrop(event) {
    event.preventDefault()
    this.dropZoneTarget.classList.remove('border-indigo-500', 'bg-indigo-50')
    
    const files = event.dataTransfer.files
    if (files.length > 0) {
      this.handleFile(files[0])
      // 드래그 앤 드롭 시에도 즉시 업로드 시작
      this.uploadFile(new Event('auto'))
    }
  }
  
  handleFile(file) {
    // 파일 타입 검증
    const acceptedTypes = ['application/pdf', 'image/jpeg', 'image/jpg', 'image/png']
    if (!acceptedTypes.includes(file.type)) {
      alert('PDF, JPG, PNG 파일만 업로드 가능합니다.')
      return
    }
    
    // 파일 크기 검증
    if (file.size > 10 * 1024 * 1024) { // 10MB
      alert('파일 크기는 10MB 이하여야 합니다.')
      return
    }
    
    this.selectedFile = file
    this.displaySelectedFile(file)
  }
  
  displaySelectedFile(file) {
    if (this.hasFileNameTarget) {
      this.fileNameTarget.textContent = file.name
    }
    if (this.hasFileSizeTarget) {
      this.fileSizeTarget.textContent = this.formatFileSize(file.size)
    }
    
    // 파일 선택 시 바로 처리 단계로 이동하므로 선택된 파일 표시 단계는 건너뜀
  }
  
  clearFile(event) {
    if (event) event.preventDefault()
    
    this.selectedFile = null
    if (this.hasFileInputTarget) {
      this.fileInputTarget.value = ''
    }
    
    if (this.hasDropZoneTarget) {
      this.dropZoneTarget.classList.remove('hidden')
    }
    if (this.hasSelectedFileTarget) {
      this.selectedFileTarget.classList.add('hidden')
    }
  }
  
  async uploadFile(event) {
    event.preventDefault()
    
    if (!this.selectedFile) return
    
    // Step 2로 전환
    this.uploadStepTarget.classList.add('hidden')
    this.processingStepTarget.classList.remove('hidden')
    
    try {
      // FormData 생성
      const formData = new FormData()
      formData.append('attachment[file]', this.selectedFile)
      
      // CSRF 토큰 추가
      const csrfToken = document.querySelector('[name="csrf-token"]').content
      
      // 파일 업로드
      this.processingStatusTarget.textContent = '파일 업로드 중...'
      
      const uploadResponse = await fetch('/expense_attachments/upload_and_extract', {
        method: 'POST',
        headers: {
          'X-CSRF-Token': csrfToken,
          'Accept': 'application/json'
        },
        body: formData
      })
      
      if (!uploadResponse.ok) {
        throw new Error('파일 업로드 실패')
      }
      
      const data = await uploadResponse.json()
      this.attachmentId = data.id
      
      // 텍스트 추출 대기
      this.processingStatusTarget.textContent = '텍스트 추출 중...'
      await this.waitForExtraction(data.id)
      
    } catch (error) {
      console.error('Upload error:', error)
      alert('파일 처리 중 오류가 발생했습니다.')
      this.reset()
    }
  }
  
  async waitForExtraction(attachmentId) {
    let attempts = 0
    const maxAttempts = 30 // 최대 30초 대기
    
    const checkStatus = async () => {
      const response = await fetch(`/expense_attachments/${attachmentId}/status`, {
        headers: {
          'Accept': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
        }
      })
      
      if (response.ok) {
        const data = await response.json()
        
        if (data.status === 'completed') {
          // 추출 완료
          this.displayExtractedData(data)
        } else if (data.status === 'failed') {
          throw new Error('텍스트 추출 실패')
        } else if (attempts < maxAttempts) {
          // 계속 대기
          attempts++
          this.processingStatusTarget.textContent = `분석 중... (${attempts}초)`
          setTimeout(checkStatus, 1000)
        } else {
          throw new Error('처리 시간 초과')
        }
      }
    }
    
    await checkStatus()
  }
  
  displayExtractedData(data) {
    // Step 3로 전환
    this.processingStepTarget.classList.add('hidden')
    this.confirmStepTarget.classList.remove('hidden')
    this.confirmButtonTarget.classList.remove('hidden')
    
    // 추출된 텍스트 표시
    this.extractedTextTarget.textContent = data.extracted_text || '텍스트를 추출할 수 없습니다.'
  }
  
  confirmData(event) {
    event.preventDefault()
    
    // 첨부파일 ID만 저장하고 모달 닫기
    // 추출된 텍스트는 이미 서버에 저장되어 있음
    const expenseItemForm = document.querySelector('[data-controller="expense-item-form"]')
    if (expenseItemForm) {
      const controller = this.application.getControllerForElementAndIdentifier(expenseItemForm, 'expense-item-form')
      
      if (controller && typeof controller.applyExtractedData === 'function') {
        controller.applyExtractedData({
          attachmentId: this.attachmentId,
          extractedText: this.extractedTextTarget.textContent
        })
      }
    }
    
    // 모달 닫기
    this.close()
  }
  
  close(event) {
    if (event) event.preventDefault()
    
    // Turbo Frame 초기화
    const modalFrame = document.getElementById('attachment_upload_modal')
    if (modalFrame) {
      modalFrame.innerHTML = ''
    }
  }
  
  reset() {
    if (this.hasUploadStepTarget) {
      this.uploadStepTarget.classList.remove('hidden')
    }
    if (this.hasProcessingStepTarget) {
      this.processingStepTarget.classList.add('hidden')
    }
    if (this.hasConfirmStepTarget) {
      this.confirmStepTarget.classList.add('hidden')
    }
    if (this.hasConfirmButtonTarget) {
      this.confirmButtonTarget.classList.add('hidden')
    }
    
    this.clearFile()
  }
  
  formatFileSize(bytes) {
    if (bytes === 0) return '0 Bytes'
    const k = 1024
    const sizes = ['Bytes', 'KB', 'MB', 'GB']
    const i = Math.floor(Math.log(bytes) / Math.log(k))
    return Math.round(bytes / Math.pow(k, i) * 100) / 100 + ' ' + sizes[i]
  }
}