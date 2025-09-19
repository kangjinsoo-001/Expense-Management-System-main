import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["radio", "chip", "preview"]
  static values = { 
    selected: Number,
    templateId: Number
  }

  connect() {
    console.log("Request form approval controller connected")
    
    // 초기 선택된 결재선 표시
    if (this.selectedValue) {
      this.highlightSelectedChip(this.selectedValue)
    }
  }

  selectApprovalLine(event) {
    const approvalLineId = event.target.dataset.approvalLineId
    
    // 모든 칩 스타일 초기화
    this.chipTargets.forEach(chip => {
      chip.classList.remove('border-indigo-500', 'bg-indigo-50', 'text-indigo-700')
      chip.classList.add('border-gray-300', 'bg-white', 'text-gray-700', 'hover:border-gray-400')
    })
    
    // 선택된 칩 하이라이트
    const selectedChip = event.target.closest('label').querySelector('[data-request-form-approval-target="chip"]')
    if (selectedChip) {
      selectedChip.classList.remove('border-gray-300', 'bg-white', 'text-gray-700', 'hover:border-gray-400')
      selectedChip.classList.add('border-indigo-500', 'bg-indigo-50', 'text-indigo-700')
    }
    
    // 결재선 미리보기 업데이트
    if (approvalLineId && approvalLineId !== "") {
      this.loadApprovalLinePreview(approvalLineId)
    } else {
      // 결재 없음 선택 시 미리보기 숨김
      if (this.hasPreviewTarget) {
        this.previewTarget.classList.add('hidden')
      }
    }
    
    // 승인 규칙 검증 (서버 호출)
    this.validateApprovalLine(approvalLineId)
  }

  highlightSelectedChip(approvalLineId) {
    const selectedRadio = this.radioTargets.find(radio => 
      radio.dataset.approvalLineId === approvalLineId.toString()
    )
    
    if (selectedRadio) {
      const selectedChip = selectedRadio.closest('label').querySelector('[data-request-form-approval-target="chip"]')
      if (selectedChip) {
        // 모든 칩 스타일 초기화
        this.chipTargets.forEach(chip => {
          chip.classList.remove('border-indigo-500', 'bg-indigo-50', 'text-indigo-700')
          chip.classList.add('border-gray-300', 'bg-white', 'text-gray-700', 'hover:border-gray-400')
        })
        
        // 선택된 칩 하이라이트
        selectedChip.classList.remove('border-gray-300', 'bg-white', 'text-gray-700', 'hover:border-gray-400')
        selectedChip.classList.add('border-indigo-500', 'bg-indigo-50', 'text-indigo-700')
      }
    }
  }

  loadApprovalLinePreview(approvalLineId) {
    if (!this.hasPreviewTarget) return
    
    // 미리보기 컨테이너 표시
    this.previewTarget.classList.remove('hidden')
    
    // window.approvalLinesData에서 데이터 가져오기
    const approvalLinesData = window.approvalLinesData || {}
    const lineData = approvalLinesData[approvalLineId]
    
    if (!lineData || !lineData.steps) {
      // 데이터가 없으면 turbo-frame으로 서버에서 로드
      const frame = document.createElement('turbo-frame')
      frame.id = 'approval_line_preview_frame'
      frame.src = `/approval_lines/${approvalLineId}/preview`
      frame.loading = 'lazy'
      
      this.previewTarget.innerHTML = ''
      this.previewTarget.appendChild(frame)
      return
    }
    
    // 클라이언트에서 직접 HTML 생성
    const previewHTML = this.generatePreviewHTML(lineData)
    this.previewTarget.innerHTML = previewHTML
  }
  
  generatePreviewHTML(lineData) {
    let html = `
      <div class="mt-2 p-3 bg-gray-50 border border-gray-200 rounded-lg">
        <h4 class="text-sm font-medium text-gray-700 mb-2">승인 단계</h4>
        <div class="space-y-2">
    `
    
    lineData.steps.forEach(step => {
      html += `<div class="text-sm flex items-center">`
      html += `<span class="font-medium text-gray-600 mr-2">${step.order}.</span>`
      
      // 승인자 목록
      step.approvers.forEach((approver, index) => {
        if (index > 0) {
          html += `<span class="mx-1 text-gray-300">|</span>`
        }
        
        html += `<span class="text-gray-700">${approver.name}`
        
        // 그룹 정보 표시 - 서버에서 이미 최고 우선순위 그룹만 전송
        if (approver.groups && approver.groups.length > 0) {
          html += ` <span class="text-gray-500">(${approver.groups[0].name})</span>`
        }
        
        html += `</span>`
        
        // 역할 배지
        const roleClass = approver.role === 'approve' 
          ? 'bg-blue-100 text-blue-700' 
          : 'bg-gray-100 text-gray-600'
        const roleText = approver.role === 'approve' ? '승인' : '참조'
        html += ` <span class="ml-1 inline-flex items-center px-1.5 py-0.5 rounded text-xs font-medium ${roleClass}">${roleText}</span>`
      })
      
      html += `</div>`
    })
    
    html += `
        </div>
      </div>
    `
    
    return html
  }

  validateApprovalLine(approvalLineId) {
    // 경비 항목과 동일한 방식으로 Turbo를 사용한 검증
    const form = document.createElement('form')
    form.method = 'POST'
    form.action = `/request_templates/${this.templateIdValue}/validate_approval_line`
    form.style.display = 'none'
    
    // CSRF 토큰 추가
    const csrfToken = document.querySelector('[name="csrf-token"]').content
    const csrfInput = document.createElement('input')
    csrfInput.type = 'hidden'
    csrfInput.name = 'authenticity_token'
    csrfInput.value = csrfToken
    form.appendChild(csrfInput)
    
    // 데이터 추가
    const approvalLineInput = document.createElement('input')
    approvalLineInput.type = 'hidden'
    approvalLineInput.name = 'approval_line_id'
    approvalLineInput.value = approvalLineId
    form.appendChild(approvalLineInput)
    
    // 폼 제출
    document.body.appendChild(form)
    form.requestSubmit()
    form.remove()
  }
}