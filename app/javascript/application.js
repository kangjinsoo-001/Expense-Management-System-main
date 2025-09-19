// Configure your import map in config/importmap.rb. Read more: https://github.com/rails/importmap-rails
import "@hotwired/turbo-rails"
import "controllers"
import "channels"

// Turbo navigation 시 열려있는 date picker 강제 닫기
// 브라우저 네이티브 캘린더가 DOM 업데이트 후에도 유지되는 문제 해결
document.addEventListener('turbo:before-visit', () => {
  // 현재 포커스된 요소가 date input인 경우 blur 처리
  const activeElement = document.activeElement
  if (activeElement && activeElement.type === 'date') {
    activeElement.blur()
  }
})

// Turbo 페이지 렌더링 직후 date input 초기화
document.addEventListener('turbo:load', () => {
  // 열려있을 수 있는 date picker 닫기
  const dateInputs = document.querySelectorAll('input[type="date"]')
  dateInputs.forEach(input => {
    // 포커스 제거로 캘린더 닫기
    if (document.activeElement === input) {
      input.blur()
    }
  })
})
