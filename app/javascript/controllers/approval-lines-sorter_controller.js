import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

export default class extends Controller {
  static targets = ["list"]
  static values = { url: String }

  connect() {
    console.log('ApprovalLinesSorter controller connected')
    this.initializeSortable()
  }

  disconnect() {
    if (this.sortable) {
      this.sortable.destroy()
    }
  }

  initializeSortable() {
    // tbody나 div가 타겟인지 확인
    const isTbody = this.listTarget.tagName.toLowerCase() === 'tbody'
    console.log('Initializing sortable for:', this.listTarget.tagName, 'isTbody:', isTbody)
    
    // 드래그 가능한 요소들 확인
    const draggableItems = this.listTarget.querySelectorAll(isTbody ? 'tr.sortable-item' : '.sortable-item')
    console.log('Found draggable items:', draggableItems.length)
    
    // 드래그 핸들 확인
    const handles = this.listTarget.querySelectorAll('.drag-handle')
    console.log('Found drag handles:', handles.length)
    
    this.sortable = Sortable.create(this.listTarget, {
      animation: 150,
      handle: '.drag-handle',
      draggable: isTbody ? 'tr.sortable-item' : '.sortable-item',
      ghostClass: 'opacity-50',
      dragClass: 'bg-blue-50',
      chosenClass: 'bg-gray-100',
      forceFallback: false, // 네이티브 드래그 먼저 시도
      preventOnFilter: false,
      swapThreshold: 0.65,
      onStart: (event) => {
        console.log('Drag started:', event.item)
        // 드래그 시작 시 텍스트 선택 방지
        document.body.style.userSelect = 'none'
        document.body.style.webkitUserSelect = 'none'
        document.body.classList.add('dragging')
      },
      onMove: (event) => {
        console.log('Drag moving')
        return true // 드래그 허용
      },
      onEnd: (event) => {
        console.log('Drag ended:', event.oldIndex, '->', event.newIndex)
        // 드래그 종료 시 텍스트 선택 복원
        document.body.style.userSelect = ''
        document.body.style.webkitUserSelect = ''
        document.body.classList.remove('dragging')
        
        if (event.oldIndex !== event.newIndex) {
          this.updateOrder()
        }
      }
    })
    
    console.log('Sortable initialized:', this.sortable)
  }

  updateOrder() {
    const items = this.listTarget.querySelectorAll('.sortable-item')
    const ids = Array.from(items).map(item => {
      return item.dataset.approvalLineId
    })

    // 서버에 새로운 순서 전송
    fetch(this.urlValue, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content
      },
      body: JSON.stringify({
        approval_line_ids: ids
      })
    })
    .then(response => {
      if (!response.ok) {
        throw new Error('순서 변경에 실패했습니다.')
      }
      return response.json()
    })
    .catch(error => {
      console.error('Error:', error)
      // 실패 시 원래 순서로 복원하려면 페이지 새로고침
      // location.reload()
    })
  }
}