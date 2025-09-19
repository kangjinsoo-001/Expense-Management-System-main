import { Controller } from "@hotwired/stimulus"

let Choices

export default class extends Controller {
  static targets = ["field"]
  
  async connect() {
    console.log("Request form controller connected")
    
    // Choices.js 로드
    await this.loadChoicesJS()
    
    // select 필드에 Choices.js 초기화
    this.initializeChoices()
  }
  
  async loadChoicesJS() {
    if (window.Choices) {
      Choices = window.Choices
      return
    }
    
    return new Promise((resolve) => {
      const script = document.createElement('script')
      script.src = '/javascripts/choices.min.js'
      script.onload = () => {
        Choices = window.Choices
        resolve()
      }
      script.onerror = () => {
        console.error("Failed to load Choices.js")
        resolve()
      }
      if (!document.querySelector('script[src="/javascripts/choices.min.js"]')) {
        document.head.appendChild(script)
      } else {
        // 이미 로드되고 있다면 기다림
        const checkInterval = setInterval(() => {
          if (window.Choices) {
            Choices = window.Choices
            clearInterval(checkInterval)
            resolve()
          }
        }, 100)
      }
    })
  }
  
  initializeChoices() {
    // select[data-choices="true"]인 모든 select 요소에 Choices.js 적용
    const selectElements = this.element.querySelectorAll('select[data-choices="true"]:not([data-choices-initialized])')
    
    selectElements.forEach(selectElement => {
      selectElement.setAttribute('data-choices-initialized', 'true')
      
      const choicesInstance = new Choices(selectElement, {
        removeItemButton: false,
        searchEnabled: true,
        searchResultLimit: 10,
        placeholder: false,
        placeholderValue: '',
        noResultsText: '검색 결과가 없습니다',
        noChoicesText: '선택할 항목이 없습니다',
        itemSelectText: '선택하려면 클릭',
        shouldSort: false,
        searchFloor: 1,
        searchPlaceholderValue: '검색...',
        allowHTML: false
      })
      
      // Choice.js 인스턴스를 요소에 저장
      selectElement._choices = choicesInstance
    })
  }
  
  // 엔터키 제출 방지
  preventEnterSubmit(event) {
    if (event.key === 'Enter' && event.target.tagName !== 'TEXTAREA') {
      event.preventDefault()
    }
  }
  
  save(event) {
    // 폼이 제출되도록 preventDefault() 제거
    // 임시저장 알림
    this.showNotification("임시저장 중...")
  }
  
  submit(event) {
    // 필수 필드 검증
    const requiredFields = this.element.querySelectorAll('[required]')
    let allValid = true
    
    requiredFields.forEach(field => {
      if (!field.value || field.value.trim() === '') {
        field.classList.add('border-red-500')
        allValid = false
      } else {
        field.classList.remove('border-red-500')
      }
    })
    
    if (!allValid) {
      event.preventDefault()
      this.showNotification("필수 필드를 모두 입력해주세요.", "error")
      return false
    }
    
    this.showNotification("제출 중...")
  }
  
  showNotification(message, type = "info") {
    // 간단한 알림 표시 (실제로는 더 나은 UI 사용)
    const notification = document.createElement('div')
    notification.className = `fixed top-4 right-4 px-4 py-2 rounded shadow-lg text-white z-50 ${
      type === 'error' ? 'bg-red-500' : 'bg-blue-500'
    }`
    notification.textContent = message
    document.body.appendChild(notification)
    
    setTimeout(() => {
      notification.remove()
    }, 3000)
  }
  
  validateField(event) {
    const field = event.target
    
    if (field.hasAttribute('required') && (!field.value || field.value.trim() === '')) {
      field.classList.add('border-red-500')
    } else {
      field.classList.remove('border-red-500')
    }
  }
}