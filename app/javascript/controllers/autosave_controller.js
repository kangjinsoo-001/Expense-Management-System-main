import { Controller } from "@hotwired/stimulus"

// Turbo와 통합된 자동 저장 컨트롤러

export default class extends Controller {
  static targets = ["form", "status", "draftId"]
  static values = { 
    url: String,
    draftId: Number
  }
  
  connect() {
    console.log("Autosave controller connected")
    this.isDirty = false
    this.isSaving = false
    this.lastSavedData = this.getFormData()
    
    // 바인딩된 함수를 인스턴스 변수로 저장 (removeEventListener를 위해)
    this.boundMarkDirty = this.markDirty.bind(this)
    this.boundHandleFormSubmit = this.handleFormSubmit.bind(this)
    this.boundHandleBeforeUnload = this.handleBeforeUnload.bind(this)
    this.boundHandleTurboBeforeVisit = this.handleTurboBeforeVisit.bind(this)
    this.boundHandleBeforeRequest = this.handleBeforeRequest.bind(this)
    
    // 폼 변경 감지
    this.formTarget.addEventListener("input", this.boundMarkDirty)
    this.formTarget.addEventListener("change", this.boundMarkDirty)
    
    // 폼 제출 시 isDirty 초기화
    this.formTarget.addEventListener("submit", this.boundHandleFormSubmit)
    
    // 페이지 벗어날 때 경고
    window.addEventListener("beforeunload", this.boundHandleBeforeUnload)
    
    // Turbo 네비게이션 감지
    document.addEventListener("turbo:before-visit", this.boundHandleTurboBeforeVisit)
    
    // Turbo 폼 제출 이벤트
    document.addEventListener("turbo:before-fetch-request", this.boundHandleBeforeRequest)
  }
  
  disconnect() {
    // 동일한 참조로 이벤트 리스너 제거
    if (this.formTarget) {
      this.formTarget.removeEventListener("input", this.boundMarkDirty)
      this.formTarget.removeEventListener("change", this.boundMarkDirty)
      this.formTarget.removeEventListener("submit", this.boundHandleFormSubmit)
    }
    window.removeEventListener("beforeunload", this.boundHandleBeforeUnload)
    document.removeEventListener("turbo:before-visit", this.boundHandleTurboBeforeVisit)
    document.removeEventListener("turbo:before-fetch-request", this.boundHandleBeforeRequest)
    
    // isDirty 상태 초기화
    this.isDirty = false
  }
  
  markDirty() {
    const currentData = this.getFormData()
    this.isDirty = currentData !== this.lastSavedData
    
    if (this.isDirty && this.hasStatusTarget) {
      this.statusTarget.textContent = "변경사항 있음"
      this.statusTarget.classList.remove("text-green-600")
      this.statusTarget.classList.add("text-yellow-600")
    }
  }
  
  
  async saveDraft(event) {
    if (event) {
      event.preventDefault()
    }
    
    if (this.isSaving) return
    
    this.isSaving = true
    this.showSavingStatus()
    
    const formData = new FormData(this.formTarget)
    
    // draft_id가 있으면 추가
    if (this.draftIdValue) {
      formData.append("id", this.draftIdValue)
    }
    
    try {
      // draft_id가 있으면 PATCH, 없으면 POST
      const method = this.draftIdValue ? "PATCH" : "POST"
      const url = this.draftIdValue 
        ? this.urlValue.replace('save_draft', `${this.draftIdValue}/save_draft`)
        : this.urlValue
      
      const response = await fetch(url, {
        method: method,
        body: formData,
        headers: {
          "X-CSRF-Token": document.querySelector("[name='csrf-token']").content,
          "Accept": "application/json"
        }
      })
      
      const data = await response.json()
      
      if (response.ok && data.success) {
        this.lastSavedData = this.getFormData()
        this.isDirty = false
        this.draftIdValue = data.draft_id
        
        // 숨겨진 필드에 draft_id 저장
        if (this.hasDraftIdTarget) {
          this.draftIdTarget.value = data.draft_id
        }
        
        this.showSuccessStatus(data.saved_at)
      } else {
        const errorMessage = data.message || "임시 저장에 실패했습니다."
        this.showErrorStatus(errorMessage)
        console.error("임시 저장 실패:", errorMessage)
      }
    } catch (error) {
      console.error("Autosave error:", error)
      this.showErrorStatus("저장 중 오류가 발생했습니다.")
    } finally {
      this.isSaving = false
    }
  }
  
  getFormData() {
    const formData = new FormData(this.formTarget)
    const data = {}
    
    for (let [key, value] of formData.entries()) {
      try {
        // attachment_ids[]와 같은 단순 배열 처리
        if (key.endsWith('[]')) {
          const arrayKey = key.slice(0, -2)
          if (!data[arrayKey]) {
            data[arrayKey] = []
          }
          data[arrayKey].push(value)
          continue
        }
        
        // Rails 중첩 파라미터 파싱 (예: expense_item[custom_fields][participants][])
        const matches = key.match(/^([^\[]+)(.*)$/)
        if (matches) {
          const base = matches[1]
          const keys = matches[2].match(/\[([^\]]*)\]/g)
          
          if (keys && keys.length > 0) {
            let current = data
            
            // base 키 설정
            if (!current[base]) {
              current[base] = {}
            }
            current = current[base]
            
            // 중첩 키 처리
            for (let i = 0; i < keys.length; i++) {
              const cleanKey = keys[i].replace(/[\[\]]/g, '')
              
              if (cleanKey === '' && i === keys.length - 1) {
                // 배열 필드 (끝이 []로 끝나는 경우)
                if (i > 0 && keys[i-1]) {
                  const parentKey = keys[i-1].replace(/[\[\]]/g, '')
                  if (!Array.isArray(current[parentKey])) {
                    current[parentKey] = []
                  }
                  current[parentKey].push(value)
                }
              } else if (i === keys.length - 1) {
                // 마지막 키
                current[cleanKey] = value
              } else {
                // 중간 키
                if (!current[cleanKey]) {
                  current[cleanKey] = {}
                }
                current = current[cleanKey]
              }
            }
          } else {
            // 단순 키
            data[base] = value
          }
        } else {
          data[key] = value
        }
      } catch (e) {
        console.warn(`Error parsing form field ${key}:`, e)
        // 에러 발생 시 단순히 키-값으로 저장
        data[key] = value
      }
    }
    
    return JSON.stringify(data)
  }
  
  showSavingStatus() {
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = "저장 중..."
      this.statusTarget.classList.remove("text-green-600", "text-red-600", "text-yellow-600")
      this.statusTarget.classList.add("text-blue-600")
    }
  }
  
  showSuccessStatus(savedAt) {
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = `임시 저장됨 (${savedAt})`
      this.statusTarget.classList.remove("text-blue-600", "text-red-600", "text-yellow-600")
      this.statusTarget.classList.add("text-green-600")
    }
  }
  
  showErrorStatus(message) {
    if (this.hasStatusTarget) {
      this.statusTarget.textContent = message || "저장 실패"
      this.statusTarget.classList.remove("text-blue-600", "text-green-600", "text-yellow-600")
      this.statusTarget.classList.add("text-red-600")
    }
  }
  
  handleBeforeUnload(event) {
    if (this.isDirty) {
      const message = "저장되지 않은 변경사항이 있습니다. 페이지를 떠나시겠습니까?"
      event.returnValue = message
      return message
    }
  }
  
  // Turbo 네비게이션 시 경고 표시 (임시 해결책)
  handleTurboBeforeVisit(event) {
    if (this.isDirty) {
      const message = "저장되지 않은 변경사항이 있습니다. 페이지를 떠나시겠습니까?"
      if (!confirm(message)) {
        event.preventDefault()  // Turbo 네비게이션 취소
      }
    }
  }
  
  handleFormSubmit(event) {
    // 폼 제출 시 isDirty를 false로 설정하여 beforeunload 경고 방지
    this.isDirty = false
  }
  
  // Turbo 이벤트 핸들러
  cancelSave() {
    // 폼 제출 시 자동 저장 취소
    if (this.saveTimeout) {
      clearTimeout(this.saveTimeout)
    }
  }
  
  resetDirty() {
    // 폼 제출 완료 후 dirty 상태 리셋
    this.isDirty = false
    this.lastSavedData = this.getFormData()
  }
  
  handleBeforeRequest(event) {
    // Turbo 요청 전 처리
    if (this.isSaving) {
      event.preventDefault()
    }
  }
  
  // 수동 저장 버튼 클릭
  manualSave(event) {
    event.preventDefault()
    this.saveDraft()
  }
  
  // 임시 저장 버튼에서 호출되는 메서드
  saveAsDraft(event) {
    event.preventDefault()
    this.saveDraft()
  }
}