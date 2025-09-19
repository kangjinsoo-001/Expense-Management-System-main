import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static values = { 
    deleteUrl: String 
  }
  
  connect() {
    console.log("Draft restore notification controller connected")
  }
  
  async cancelAndDelete(event) {
    event.preventDefault()
    
    // 사용자 확인
    if (!confirm('임시 저장된 내용을 삭제하고 새로 작성하시겠습니까?')) {
      return
    }
    
    // 비동기로 서버에 삭제 요청
    try {
      const response = await fetch(this.deleteUrlValue, {
        method: 'DELETE',
        headers: {
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content,
          'Accept': 'application/json'
        }
      })
      
      if (response.ok) {
        // 삭제 성공 시 페이지 새로고침 (새 작성 화면으로)
        window.location.reload()
      } else {
        console.error('Failed to delete draft')
        alert('임시 저장 삭제에 실패했습니다.')
      }
    } catch (error) {
      console.error('Error deleting draft:', error)
      alert('임시 저장 삭제 중 오류가 발생했습니다.')
    }
  }
}