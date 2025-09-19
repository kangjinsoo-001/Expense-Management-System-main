import { Controller } from "@hotwired/stimulus"

// 승인 상세 페이지 컨트롤러
export default class extends Controller {
  connect() {
    // 페이지가 로드될 때 콘텐츠가 있는지 확인
    this.checkContent();
  }
  
  checkContent() {
    // 메인 콘텐츠가 비어있는지 확인
    const mainContent = this.element.querySelector('.grid');
    if (!mainContent || mainContent.children.length === 0) {
      // 콘텐츠가 없으면 페이지 새로고침
      window.location.reload();
    }
  }
}