import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["attachmentSection", "submitButton", "toggleIcon"]
  
  connect() {
    // 초기화 시 첨부서류 섹션 숨김
    if (this.hasAttachmentSectionTarget) {
      this.attachmentSectionTarget.classList.add("hidden")
    }
    // 토글 상태 플래그
    this.isOpen = false
  }
  
  toggleAttachmentSection(event) {
    event.preventDefault()
    
    if (this.hasAttachmentSectionTarget) {
      const section = this.attachmentSectionTarget
      
      if (section.classList.contains("hidden")) {
        // 섹션 표시
        section.classList.remove("hidden")
        this.isOpen = true
        
        // 부드러운 스크롤 효과로 섹션으로 이동
        section.scrollIntoView({ behavior: "smooth", block: "start" })
        
        // 토글 아이콘 회전 (아래 방향)
        if (this.hasToggleIconTarget) {
          this.toggleIconTarget.style.transform = "rotate(90deg)"
        }
      } else {
        // 섹션 숨기기
        this.hideAttachmentSection(event)
      }
    } else {
      console.error("Attachment section target not found")
    }
  }
  
  hideAttachmentSection(event) {
    if (event) event.preventDefault()
    
    if (this.hasAttachmentSectionTarget) {
      this.attachmentSectionTarget.classList.add("hidden")
      this.isOpen = false
      
      // 토글 아이콘 원위치
      if (this.hasToggleIconTarget) {
        this.toggleIconTarget.style.transform = "rotate(0deg)"
      }
    }
  }
  
  // 제출 완료 후 호출될 메서드
  onSubmitSuccess(event) {
    // 제출 성공 시 처리
    this.hideAttachmentSection()
  }
}