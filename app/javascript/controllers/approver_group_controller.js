import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["membersList", "addMemberForm", "flashContainer", "editForm", "editButton"]
  
  connect() {
    console.log("ApproverGroup controller connected")
    
    // Turbo Stream 응답 디버깅
    document.addEventListener("turbo:before-stream-render", (event) => {
      console.log("Turbo Stream render:", event.detail.newStream)
    })
  }

  // 멤버 추가 성공 시 호출
  memberAdded(event) {
    console.log("memberAdded event:", event)
    // Turbo의 submit-end 이벤트는 detail.success를 확인
    if (event.detail && event.detail.success) {
      // 폼 리셋
      if (this.hasAddMemberFormTarget) {
        const form = this.addMemberFormTarget.querySelector("form")
        if (form) form.reset()
      }
    }
  }
  
  // 멤버 삭제 성공 시 호출
  memberRemoved(event) {
    console.log("memberRemoved event:", event)
    // Turbo의 submit-end 이벤트는 detail.success를 확인
    if (event.detail && event.detail.success) {
      // 이미 서버에서 플래시 메시지를 보내므로 여기서는 추가 작업 불필요
    }
  }
  
  // 편집 모드 토글
  toggleEditMode() {
    if (this.hasEditFormTarget) {
      this.editFormTarget.classList.toggle('hidden')
      
      // 버튼 텍스트 변경
      if (this.hasEditButtonTarget) {
        const isHidden = this.editFormTarget.classList.contains('hidden')
        this.editButtonTarget.textContent = isHidden ? '멤버 수정' : '수정 취소'
      }
    }
  }
  
  // 편집 취소
  cancelEdit() {
    if (this.hasEditFormTarget) {
      this.editFormTarget.classList.add('hidden')
    }
    if (this.hasEditButtonTarget) {
      this.editButtonTarget.textContent = '멤버 수정'
    }
  }
  
  // 멤버 업데이트 성공 시
  membersUpdated(event) {
    console.log("membersUpdated event:", event)
    // Turbo의 submit-end 이벤트는 detail.success를 확인
    if (event.detail && event.detail.success) {
      // 편집 폼은 서버에서 이미 숨김 처리됨
      // 추가 작업 불필요
    }
  }
  
  // 플래시 메시지 표시
  showFlash(type, message) {
    const flashHTML = `
      <div class="flash-message flash-${type} bg-${type === 'notice' ? 'green' : 'red'}-50 border border-${type === 'notice' ? 'green' : 'red'}-400 text-${type === 'notice' ? 'green' : 'red'}-800 px-4 py-3 rounded relative mb-4" role="alert" data-turbo-temporary>
        <span class="block sm:inline">${message}</span>
        <button type="button" class="absolute top-0 bottom-0 right-0 px-4 py-3" onclick="this.parentElement.remove()">
          <svg class="fill-current h-6 w-6 text-${type === 'notice' ? 'green' : 'red'}-500" role="button" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20">
            <title>Close</title>
            <path d="M14.348 14.849a1.2 1.2 0 0 1-1.697 0L10 11.819l-2.651 3.029a1.2 1.2 0 1 1-1.697-1.697l2.758-3.15-2.759-3.152a1.2 1.2 0 1 1 1.697-1.697L10 8.183l2.651-3.031a1.2 1.2 0 1 1 1.697 1.697l-2.758 3.152 2.758 3.15a1.2 1.2 0 0 1 0 1.698z"/>
          </svg>
        </button>
      </div>
    `
    
    // flash_container가 있으면 거기에, 없으면 현재 컨트롤러의 최상단에 표시
    const container = document.getElementById("flash_container") || this.element
    container.insertAdjacentHTML("afterbegin", flashHTML)
    
    // 5초 후 자동 제거
    setTimeout(() => {
      const flash = container.querySelector(".flash-message")
      if (flash) flash.remove()
    }, 5000)
  }
}