import { Controller } from "@hotwired/stimulus"

// 탭 컨트롤러 - Turbo Frame을 사용하므로 간단하게 유지
export default class extends Controller {
  static targets = ["tab", "content"]
  
  connect() {
    // Turbo Frame을 사용하므로 대부분의 로직이 불필요
    // 서버에서 렌더링된 상태를 그대로 사용
  }
  
  switchTab(event) {
    // 링크 클릭은 Turbo Frame이 처리하므로 기본 동작 허용
    // event.preventDefault() 제거
  }
}