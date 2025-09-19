import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["fileInput", "dropZone", "fileList", "files"]
  static values = { maxFiles: Number }
  
  connect() {
    this.selectedFiles = []
    
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
  
  filesSelected(event) {
    const files = Array.from(event.target.files)
    this.addFiles(files)
  }
  
  handleDragOver(event) {
    event.preventDefault()
    this.dropZoneTarget.parentElement.classList.add('border-indigo-500', 'bg-indigo-50')
  }
  
  handleDragLeave(event) {
    event.preventDefault()
    this.dropZoneTarget.parentElement.classList.remove('border-indigo-500', 'bg-indigo-50')
  }
  
  handleDrop(event) {
    event.preventDefault()
    this.dropZoneTarget.parentElement.classList.remove('border-indigo-500', 'bg-indigo-50')
    
    const files = Array.from(event.dataTransfer.files)
    this.addFiles(files)
  }
  
  addFiles(newFiles) {
    const acceptedTypes = ['application/pdf', 'image/jpeg', 'image/jpg', 'image/png']
    const maxSize = 10 * 1024 * 1024 // 10MB
    
    // 파일 검증 및 추가
    newFiles.forEach(file => {
      // 파일 타입 체크
      if (!acceptedTypes.includes(file.type)) {
        alert(`${file.name}: PDF, JPG, PNG 파일만 업로드 가능합니다.`)
        return
      }
      
      // 파일 크기 체크
      if (file.size > maxSize) {
        alert(`${file.name}: 파일 크기는 10MB 이하여야 합니다.`)
        return
      }
      
      // 최대 파일 개수 체크
      if (this.selectedFiles.length >= this.maxFilesValue) {
        alert(`최대 ${this.maxFilesValue}개까지만 첨부 가능합니다.`)
        return
      }
      
      // 중복 체크
      if (this.selectedFiles.some(f => f.name === file.name && f.size === file.size)) {
        return
      }
      
      this.selectedFiles.push(file)
    })
    
    this.updateFileList()
    this.updateFileInput()
  }
  
  updateFileList() {
    if (this.selectedFiles.length === 0) {
      this.fileListTarget.classList.add('hidden')
      return
    }
    
    this.fileListTarget.classList.remove('hidden')
    this.filesTarget.innerHTML = ''
    
    this.selectedFiles.forEach((file, index) => {
      const li = document.createElement('li')
      li.className = 'flex items-center justify-between p-2 bg-gray-50 rounded'
      
      const fileInfo = document.createElement('div')
      fileInfo.className = 'flex items-center'
      
      // 파일 아이콘
      const icon = document.createElement('div')
      icon.className = 'mr-3'
      if (file.type === 'application/pdf') {
        icon.innerHTML = `
          <svg class="h-8 w-8 text-red-500" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M4 4a2 2 0 012-2h4.586A2 2 0 0112 2.586L15.414 6A2 2 0 0116 7.414V16a2 2 0 01-2 2H6a2 2 0 01-2-2V4z" clip-rule="evenodd" />
          </svg>
        `
      } else {
        icon.innerHTML = `
          <svg class="h-8 w-8 text-blue-500" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M4 3a2 2 0 00-2 2v10a2 2 0 002 2h12a2 2 0 002-2V5a2 2 0 00-2-2H4zm12 12H4l4-8 3 6 2-4 3 6z" clip-rule="evenodd" />
          </svg>
        `
      }
      
      const fileDetails = document.createElement('div')
      fileDetails.innerHTML = `
        <p class="text-sm font-medium text-gray-900">${file.name}</p>
        <p class="text-xs text-gray-500">${this.formatFileSize(file.size)}</p>
      `
      
      fileInfo.appendChild(icon)
      fileInfo.appendChild(fileDetails)
      
      // 삭제 버튼
      const removeBtn = document.createElement('button')
      removeBtn.type = 'button'
      removeBtn.className = 'text-red-600 hover:text-red-800'
      removeBtn.innerHTML = `
        <svg class="h-5 w-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
        </svg>
      `
      removeBtn.addEventListener('click', () => this.removeFile(index))
      
      li.appendChild(fileInfo)
      li.appendChild(removeBtn)
      this.filesTarget.appendChild(li)
    })
  }
  
  removeFile(index) {
    this.selectedFiles.splice(index, 1)
    this.updateFileList()
    this.updateFileInput()
  }
  
  updateFileInput() {
    // DataTransfer를 사용하여 파일 입력 필드 업데이트
    const dataTransfer = new DataTransfer()
    this.selectedFiles.forEach(file => {
      dataTransfer.items.add(file)
    })
    this.fileInputTarget.files = dataTransfer.files
  }
  
  formatFileSize(bytes) {
    if (bytes === 0) return '0 Bytes'
    const k = 1024
    const sizes = ['Bytes', 'KB', 'MB', 'GB']
    const i = Math.floor(Math.log(bytes) / Math.log(k))
    return Math.round(bytes / Math.pow(k, i) * 100) / 100 + ' ' + sizes[i]
  }
}