import { Controller } from "@hotwired/stimulus"
import Sortable from "sortablejs"

export default class extends Controller {
  static targets = ["list", "sortButton"]
  static values = { 
    sheetId: Number,
    sortUrl: String,
    bulkSortUrl: String
  }

  connect() {
    console.log('ExpenseItemsSorter controller connected')
    this.initializeSortable()
  }

  disconnect() {
    if (this.sortable) {
      this.sortable.destroy()
    }
  }

  initializeSortable() {
    if (!this.hasListTarget) {
      console.error('List target not found')
      return
    }

    // tbody인지 div인지 확인
    const isTbody = this.listTarget.tagName.toLowerCase() === 'tbody'
    
    this.sortable = Sortable.create(this.listTarget, {
      animation: 150,
      handle: '.drag-handle',
      draggable: isTbody ? 'tr[data-item-id]' : '.expense-item-card',
      ghostClass: 'opacity-50',
      dragClass: 'bg-blue-50',
      chosenClass: 'bg-gray-100',
      forceFallback: true,  // 네이티브 드래그 대신 fallback 사용
      filter: '.no-drag',    // no-drag 클래스는 드래그 불가
      preventOnFilter: true, // filter된 요소 클릭 시 이벤트 방지
      onEnd: (event) => {
        this.handleDragEnd(event)
      }
    })
  }

  handleDragEnd(event) {
    // 모든 아이템의 ID를 순서대로 수집
    const itemIds = []
    const items = this.listTarget.querySelectorAll('[data-item-id]')
    
    items.forEach(item => {
      const itemId = item.dataset.itemId
      if (itemId) {
        itemIds.push(itemId)
      }
    })

    // 서버에 새로운 순서 전송
    this.updatePositions(itemIds)
  }

  async updatePositions(itemIds) {
    try {
      const response = await fetch(this.sortUrlValue, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content,
          'Accept': 'application/json'
        },
        body: JSON.stringify({ item_ids: itemIds })
      })

      if (!response.ok) {
        throw new Error('정렬 저장 실패')
      }

      const data = await response.json()
      if (data.success) {
        console.log('순서가 저장되었습니다')
      }
    } catch (error) {
      console.error('Error updating positions:', error)
      alert('순서 저장 중 오류가 발생했습니다.')
    }
  }

  // 정렬 버튼 클릭 핸들러
  sortByDate(event) {
    event.preventDefault()
    this.performBulkSort('date')
  }

  sortByDateDesc(event) {
    event.preventDefault()
    this.performBulkSort('date_desc')
  }

  sortByAmount(event) {
    event.preventDefault()
    this.performBulkSort('amount')
  }

  sortByAmountDesc(event) {
    event.preventDefault()
    this.performBulkSort('amount_desc')
  }

  sortByCreation(event) {
    event.preventDefault()
    this.performBulkSort('creation')
  }

  sortByCreationDesc(event) {
    event.preventDefault()
    this.performBulkSort('creation_desc')
  }

  sortByExpenseCode(event) {
    event.preventDefault()
    this.performBulkSort('expense_code')
  }

  async performBulkSort(sortBy) {
    try {
      // 버튼 비활성화
      if (this.hasSortButtonTarget) {
        this.sortButtonTargets.forEach(btn => {
          btn.disabled = true
          btn.classList.add('opacity-50', 'cursor-not-allowed')
        })
      }

      const response = await fetch(this.bulkSortUrlValue, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content,
          'Accept': 'application/json'
        },
        body: JSON.stringify({ sort_by: sortBy })
      })

      if (response.ok) {
        // Turbo를 사용하여 페이지 새로고침
        window.location.reload()
      } else {
        throw new Error('정렬 실패')
      }
    } catch (error) {
      console.error('Error sorting:', error)
      alert('정렬 중 오류가 발생했습니다.')
      
      // 버튼 다시 활성화
      if (this.hasSortButtonTarget) {
        this.sortButtonTargets.forEach(btn => {
          btn.disabled = false
          btn.classList.remove('opacity-50', 'cursor-not-allowed')
        })
      }
    }
  }
}