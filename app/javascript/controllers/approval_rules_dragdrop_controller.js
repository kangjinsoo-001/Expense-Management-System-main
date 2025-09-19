import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["rule", "list"]
  
  connect() {
    console.log("ApprovalRulesDragdrop controller connected")
    this.draggedElement = null
    this.setupDragAndDrop()
  }
  
  setupDragAndDrop() {
    if (!this.hasListTarget) return
    
    // 모든 규칙 행에 드래그 이벤트 설정
    this.ruleTargets.forEach(rule => {
      this.setupRuleDragEvents(rule)
    })
  }
  
  setupRuleDragEvents(rule) {
    rule.draggable = true
    rule.classList.add('cursor-move', 'hover:bg-gray-50', 'transition-colors')
    
    // 드래그 핸들 추가 (첫 번째 셀에)
    const firstCell = rule.querySelector('td:first-child')
    if (firstCell && !firstCell.querySelector('.drag-handle')) {
      const handle = document.createElement('span')
      handle.className = 'drag-handle inline-block mr-2 text-gray-400 hover:text-gray-600 cursor-move'
      handle.innerHTML = `
        <svg class="h-5 w-5 inline" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M4 8h16M4 16h16" />
        </svg>
      `
      firstCell.prepend(handle)
    }
    
    // 데스크톱 드래그 이벤트
    rule.addEventListener('dragstart', this.handleDragStart.bind(this))
    rule.addEventListener('dragend', this.handleDragEnd.bind(this))
    rule.addEventListener('dragover', this.handleDragOver.bind(this))
    rule.addEventListener('drop', this.handleDrop.bind(this))
    rule.addEventListener('dragenter', this.handleDragEnter.bind(this))
    rule.addEventListener('dragleave', this.handleDragLeave.bind(this))
    
    // 터치 이벤트 지원
    rule.addEventListener('touchstart', this.handleTouchStart.bind(this), { passive: false })
    rule.addEventListener('touchmove', this.handleTouchMove.bind(this), { passive: false })
    rule.addEventListener('touchend', this.handleTouchEnd.bind(this))
  }
  
  handleDragStart(event) {
    const rule = event.target.closest('[data-approval-rules-dragdrop-target="rule"]')
    if (!rule) return
    
    this.draggedElement = rule
    rule.classList.add('opacity-50')
    
    event.dataTransfer.effectAllowed = 'move'
    event.dataTransfer.setData('text/html', rule.innerHTML)
  }
  
  handleDragEnd(event) {
    const rule = event.target.closest('[data-approval-rules-dragdrop-target="rule"]')
    if (!rule) return
    
    rule.classList.remove('opacity-50')
    
    // 드롭 인디케이터 제거
    this.ruleTargets.forEach(r => {
      r.classList.remove('border-t-4', 'border-indigo-500')
    })
    
    this.draggedElement = null
  }
  
  handleDragOver(event) {
    if (event.preventDefault) {
      event.preventDefault()
    }
    event.dataTransfer.dropEffect = 'move'
    return false
  }
  
  handleDragEnter(event) {
    const rule = event.target.closest('[data-approval-rules-dragdrop-target="rule"]')
    if (!rule || rule === this.draggedElement) return
    
    rule.classList.add('border-t-4', 'border-indigo-500')
  }
  
  handleDragLeave(event) {
    const rule = event.target.closest('[data-approval-rules-dragdrop-target="rule"]')
    if (!rule) return
    
    // 마우스가 자식 요소로 이동한 경우는 무시
    if (rule.contains(event.relatedTarget)) return
    
    rule.classList.remove('border-t-4', 'border-indigo-500')
  }
  
  handleDrop(event) {
    if (event.stopPropagation) {
      event.stopPropagation()
    }
    event.preventDefault()
    
    const dropTarget = event.target.closest('[data-approval-rules-dragdrop-target="rule"]')
    if (!dropTarget || !this.draggedElement || dropTarget === this.draggedElement) return
    
    // 드롭 위치 계산
    const rect = dropTarget.getBoundingClientRect()
    const y = event.clientY - rect.top
    const height = rect.height
    
    // tbody 찾기
    const tbody = this.listTarget.querySelector('tbody')
    if (!tbody) return
    
    if (y < height / 2) {
      // 위쪽에 드롭
      tbody.insertBefore(this.draggedElement, dropTarget)
    } else {
      // 아래쪽에 드롭
      tbody.insertBefore(this.draggedElement, dropTarget.nextSibling)
    }
    
    // 순서 업데이트
    this.updateOrder()
    
    return false
  }
  
  // 터치 이벤트 핸들러들
  handleTouchStart(event) {
    const rule = event.target.closest('[data-approval-rules-dragdrop-target="rule"]')
    if (!rule) return
    
    // 터치 시작 위치 저장
    this.touchStartY = event.touches[0].clientY
    this.touchedElement = rule
    this.touchedElement.style.opacity = '0.5'
    this.touchedElement.style.zIndex = '1000'
    
    // 스크롤 방지
    event.preventDefault()
  }
  
  handleTouchMove(event) {
    if (!this.touchedElement) return
    
    event.preventDefault()
    
    const touch = event.touches[0]
    const currentY = touch.clientY
    const deltaY = currentY - this.touchStartY
    
    // 이동 중인 요소 표시
    this.touchedElement.style.transform = `translateY(${deltaY}px)`
    
    // 드롭 위치 하이라이트
    const elementBelow = document.elementFromPoint(touch.clientX, touch.clientY)
    const ruleBelow = elementBelow?.closest('[data-approval-rules-dragdrop-target="rule"]')
    
    if (ruleBelow && ruleBelow !== this.touchedElement) {
      // 기존 하이라이트 제거
      this.ruleTargets.forEach(r => r.classList.remove('border-t-4', 'border-indigo-500'))
      
      // 새 하이라이트 추가
      ruleBelow.classList.add('border-t-4', 'border-indigo-500')
    }
  }
  
  handleTouchEnd(event) {
    if (!this.touchedElement) return
    
    const touch = event.changedTouches[0]
    const elementBelow = document.elementFromPoint(touch.clientX, touch.clientY)
    const ruleBelow = elementBelow?.closest('[data-approval-rules-dragdrop-target="rule"]')
    
    // 스타일 초기화
    this.touchedElement.style.opacity = ''
    this.touchedElement.style.zIndex = ''
    this.touchedElement.style.transform = ''
    
    // 하이라이트 제거
    this.ruleTargets.forEach(r => r.classList.remove('border-t-4', 'border-indigo-500'))
    
    // 드롭 처리
    if (ruleBelow && ruleBelow !== this.touchedElement) {
      const tbody = this.listTarget.querySelector('tbody')
      if (!tbody) return
      
      const rect = ruleBelow.getBoundingClientRect()
      const y = touch.clientY - rect.top
      const height = rect.height
      
      if (y < height / 2) {
        tbody.insertBefore(this.touchedElement, ruleBelow)
      } else {
        tbody.insertBefore(this.touchedElement, ruleBelow.nextSibling)
      }
      
      this.updateOrder()
    }
    
    this.touchedElement = null
    this.touchStartY = null
  }
  
  updateOrder() {
    // 모든 규칙의 순서를 업데이트하고 서버에 전송
    const rules = this.ruleTargets
    const updates = []
    
    rules.forEach((rule, index) => {
      const ruleId = rule.id.replace('approval_rule_', '')
      const newOrder = index + 1
      
      // 순서 표시 업데이트
      const orderCell = rule.querySelector('td:first-child')
      if (orderCell) {
        const textNode = Array.from(orderCell.childNodes).find(node => node.nodeType === Node.TEXT_NODE)
        if (textNode) {
          textNode.textContent = newOrder
        } else {
          // 텍스트 노드가 없으면 추가
          orderCell.appendChild(document.createTextNode(newOrder))
        }
      }
      
      updates.push({ id: ruleId, order: newOrder })
    })
    
    // 서버에 순서 업데이트 요청
    this.sendOrderUpdate(updates)
  }
  
  async sendOrderUpdate(updates) {
    // 경비 코드 또는 템플릿 ID 가져오기
    const expenseCodeId = this.data.get('expenseCodeId')
    const requestTemplateId = this.data.get('requestTemplateId')
    
    let url
    if (expenseCodeId) {
      console.log('Sending order update for expense code:', expenseCodeId, 'Updates:', updates)
      url = `/admin/expense_codes/${expenseCodeId}/update_approval_rules_order`
    } else if (requestTemplateId) {
      console.log('Sending order update for request template:', requestTemplateId, 'Updates:', updates)
      url = `/admin/request_templates/${requestTemplateId}/reorder_approval_rules`
    } else {
      console.error('Neither expense code ID nor request template ID found')
      return
    }
    
    try {
      const response = await fetch(url, {
        method: 'PATCH',
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('[name="csrf-token"]').content,
          'Accept': 'application/json'
        },
        body: JSON.stringify({ rules: updates })
      })
      
      console.log('Response status:', response.status)
      
      if (response.ok) {
        console.log('Order updated successfully')
        this.showNotification('승인 규칙 순서가 변경되었습니다.', 'success')
      } else {
        console.error('Failed to update order, status:', response.status)
        this.showNotification('순서 변경에 실패했습니다.', 'error')
      }
    } catch (error) {
      console.error('Error updating order:', error)
      this.showNotification('순서 변경 중 오류가 발생했습니다.', 'error')
    }
  }
  
  showNotification(message, type = 'info') {
    console.log('Showing notification:', message, 'Type:', type)
    
    // dragdrop_flash_container 먼저 찾기 (드래그앤드롭 전용)
    let flashContainer = document.getElementById('dragdrop_flash_container')
    console.log('Dragdrop flash container:', flashContainer)
    
    // 없으면 일반 flash_container 찾기
    if (!flashContainer) {
      flashContainer = this.element.querySelector('#flash_container')
      console.log('Flash container in element:', flashContainer)
    }
    
    // 그래도 없으면 전체 문서에서 찾기
    if (!flashContainer) {
      flashContainer = document.getElementById('flash_container')
      console.log('Flash container in document:', flashContainer)
    }
    
    if (!flashContainer) {
      console.error('Flash container not found, using floating notification')
      // 대안: body에 직접 추가
      this.showFloatingNotification(message, type)
      return
    }
    
    // 기존 알림 제거
    flashContainer.innerHTML = ''
    
    // 새 알림 생성
    const notification = document.createElement('div')
    const bgColor = type === 'success' ? 'bg-green-100' : type === 'error' ? 'bg-red-100' : 'bg-blue-100'
    const textColor = type === 'success' ? 'text-green-800' : type === 'error' ? 'text-red-800' : 'text-blue-800'
    
    notification.className = `inline-flex items-center px-3 py-1 rounded-full text-sm ${bgColor} ${textColor}`
    notification.setAttribute('data-turbo-temporary', 'true')
    
    notification.innerHTML = `
      <span>${message}</span>
      <button type="button" class="ml-2 text-${type === 'success' ? 'green' : type === 'error' ? 'red' : 'blue'}-600 hover:text-${type === 'success' ? 'green' : type === 'error' ? 'red' : 'blue'}-800" onclick="this.parentElement.remove()">
        <svg class="w-4 h-4" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M4.293 4.293a1 1 0 011.414 0L10 8.586l4.293-4.293a1 1 0 111.414 1.414L11.414 10l4.293 4.293a1 1 0 01-1.414 1.414L10 11.414l-4.293 4.293a1 1 0 01-1.414-1.414L8.586 10 4.293 5.707a1 1 0 010-1.414z" clip-rule="evenodd"/>
        </svg>
      </button>
    `
    
    flashContainer.appendChild(notification)
    
    // 3초 후 제거
    setTimeout(() => {
      notification.style.opacity = '0'
      setTimeout(() => notification.remove(), 300)
    }, 3000)
  }
  
  showFloatingNotification(message, type = 'info') {
    // 대안: 기존 방식의 플로팅 알림 (우측 하단)
    const existingNotification = document.querySelector('.dragdrop-notification')
    if (existingNotification) {
      existingNotification.remove()
    }
    
    const notification = document.createElement('div')
    notification.className = `dragdrop-notification fixed bottom-4 right-4 px-6 py-3 rounded-lg shadow-lg transition-opacity duration-300 z-50 ${
      type === 'success' ? 'bg-green-500 text-white' : 
      type === 'error' ? 'bg-red-500 text-white' : 
      'bg-blue-500 text-white'
    }`
    notification.textContent = message
    
    document.body.appendChild(notification)
    
    // 3초 후 제거
    setTimeout(() => {
      notification.style.opacity = '0'
      setTimeout(() => notification.remove(), 300)
    }, 3000)
  }
}