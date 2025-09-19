import { Controller } from "@hotwired/stimulus"

// 폼의 입력 필드가 변경될 때 자동으로 제출하는 컨트롤러
export default class extends Controller {
  static targets = ["form"]
  static values = { delay: Number }
  
  connect() {
    // 기본 지연 시간 설정 (300ms)
    if (!this.hasDelayValue) {
      this.delayValue = 300
    }
    
    // 디바운스 타이머 초기화
    this.debounceTimer = null
  }
  
  disconnect() {
    // 컨트롤러가 해제될 때 타이머 정리
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer)
    }
  }
  
  // 입력 필드 변경 시 호출
  submit(event) {
    // 이전 타이머가 있으면 취소
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer)
    }
    
    // 새 타이머 설정
    this.debounceTimer = setTimeout(() => {
      this.performSubmit()
    }, this.delayValue)
  }
  
  // 실제 폼 제출 수행
  performSubmit() {
    // Turbo를 통한 폼 제출
    if (this.element.requestSubmit) {
      this.element.requestSubmit()
    } else {
      // requestSubmit이 지원되지 않는 경우 폴백
      this.element.submit()
    }
  }
  
  // 즉시 제출 (디바운스 없이)
  submitNow(event) {
    if (this.debounceTimer) {
      clearTimeout(this.debounceTimer)
    }
    this.performSubmit()
  }
}