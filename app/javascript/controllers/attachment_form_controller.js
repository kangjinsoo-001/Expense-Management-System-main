import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["fileInput", "dropZone", "selectedFile", "fileName", "fileSize", "submitButton"]
  
  connect() {
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
      this.displaySelectedFile(file)
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
      const file = files[0]
      // 파일 타입 검증
      const acceptedTypes = ['application/pdf', 'image/jpeg', 'image/jpg', 'image/png']
      if (acceptedTypes.includes(file.type)) {
        // DataTransfer를 사용하여 파일 입력 필드에 파일 설정
        const dataTransfer = new DataTransfer()
        dataTransfer.items.add(file)
        this.fileInputTarget.files = dataTransfer.files
        this.displaySelectedFile(file)
      } else {
        alert('PDF, JPG, PNG 파일만 업로드 가능합니다.')
      }
    }
  }
  
  displaySelectedFile(file) {
    // 파일 크기 체크
    if (file.size > 10 * 1024 * 1024) { // 10MB
      alert('파일 크기는 10MB 이하여야 합니다.')
      this.clearFile()
      return
    }
    
    // 선택된 파일 정보 표시
    this.fileNameTarget.textContent = file.name
    this.fileSizeTarget.textContent = this.formatFileSize(file.size)
    
    // UI 업데이트
    this.dropZoneTarget.classList.add('hidden')
    this.selectedFileTarget.classList.remove('hidden')
    this.submitButtonTarget.disabled = false
  }
  
  clearFile(event) {
    if (event) event.preventDefault()
    
    // 파일 입력 초기화
    this.fileInputTarget.value = ''
    
    // UI 초기화
    this.dropZoneTarget.classList.remove('hidden')
    this.selectedFileTarget.classList.add('hidden')
    this.submitButtonTarget.disabled = true
  }
  
  formatFileSize(bytes) {
    if (bytes === 0) return '0 Bytes'
    const k = 1024
    const sizes = ['Bytes', 'KB', 'MB', 'GB']
    const i = Math.floor(Math.log(bytes) / Math.log(k))
    return Math.round(bytes / Math.pow(k, i) * 100) / 100 + ' ' + sizes[i]
  }
  
  handleSubmit(event) {
    // 업로드 중 버튼 비활성화
    this.submitButtonTarget.disabled = true
    this.submitButtonTarget.textContent = '업로드중...'
  }
}