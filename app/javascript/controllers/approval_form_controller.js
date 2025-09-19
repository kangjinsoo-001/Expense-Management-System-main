import { Controller } from "@hotwired/stimulus"

// Connects to data-controller="approval-form"
export default class extends Controller {
  static targets = [ "comment", "approveForm", "rejectForm" ]
  
  connect() {
    console.log("Approval form controller connected")
    console.log("Targets found:", {
      comment: this.hasCommentTarget,
      approveForm: this.hasApproveFormTarget,
      rejectForm: this.hasRejectFormTarget
    })
  }
  
  submitApproval(event) {
    console.log("submitApproval called")
    
    // 기존 hidden input 제거
    const existingInput = this.approveFormTarget.querySelector('input[name="comment"]')
    if (existingInput) {
      existingInput.remove()
    }
    
    // 새로운 hidden input 추가
    const comment = this.hasCommentTarget ? this.commentTarget.value : ''
    console.log("Approval comment:", comment)
    
    const input = document.createElement('input')
    input.type = 'hidden'
    input.name = 'comment'
    input.value = comment
    this.approveFormTarget.appendChild(input)
  }
  
  submitRejection(event) {
    console.log("submitRejection called")
    const comment = this.hasCommentTarget ? this.commentTarget.value : ''
    console.log("Rejection comment:", comment)
    console.log("Event:", event)
    
    // 코멘트가 없으면 폼 제출 중단
    if (!comment.trim()) {
      event.preventDefault()
      event.stopPropagation()
      alert('반려 사유를 입력해주세요.')
      if (this.hasCommentTarget) {
        this.commentTarget.focus()
      }
      return false
    }
    
    // 기존 hidden input 제거
    const existingInput = this.rejectFormTarget.querySelector('input[name="comment"]')
    if (existingInput) {
      console.log("Removing existing input with value:", existingInput.value)
      existingInput.remove()
    }
    
    // 새로운 hidden input 추가
    const input = document.createElement('input')
    input.type = 'hidden'
    input.name = 'comment'
    input.value = comment
    this.rejectFormTarget.appendChild(input)
    console.log("Added hidden input with value:", comment)
  }
}