import { Controller } from "@hotwired/stimulus"
import { Turbo } from "@hotwired/turbo-rails"

export default class extends Controller {
  static targets = ["cell", "tooltip"]
  static values = { 
    allRooms: Array,
    date: String
  }
  
  connect() {
    console.log("🚀 RoomCalendarController connected (Rails Way)")
    
    // 드래그 관련 상태 초기화
    this.isMoving = false
    this.movingReservation = null
    this.isCreating = false
    this.creatingReservation = null
    this.isResizing = false
    this.resizingReservation = null
    
    // 이벤트 핸들러 바인딩
    this.boundHandleMove = this.handleMove.bind(this)
    this.boundHandleMoveEnd = this.handleMoveEnd.bind(this)
    this.boundHandleCreateMove = this.handleCreateMove.bind(this)
    this.boundHandleCreateEnd = this.handleCreateEnd.bind(this)
    this.boundHandleResizeMove = this.handleResizeMove.bind(this)
    this.boundHandleResizeEnd = this.handleResizeEnd.bind(this)
    this.boundHandleEscapeKey = this.handleEscapeKey.bind(this)
    
    // 이벤트 위임으로 인터랙션 처리
    this.setupEventDelegation()
    
    // 툴팁 설정
    this.setupTooltips()
    
    // ESC 키 이벤트 리스너 설정
    this.setupKeyboardListeners()
    
    // Turbo Stream 업데이트 후 재연결
    document.addEventListener('turbo:before-stream-render', () => {
      console.log('📋 Turbo Stream 업데이트 감지')
    })
    
    // Turbo Stream이 렌더링된 후 이벤트 리스너 재설정
    document.addEventListener('turbo:after-stream-render', (event) => {
      console.log('📅 Turbo Stream 렌더링 완료')
      // calendar_grid가 교체되었는지 확인
      if (document.getElementById('calendar_grid')) {
        setTimeout(() => {
          this.setupEventDelegation()
          this.setupTooltips()
          console.log('✅ 이벤트 리스너 재설정 완료 (Turbo Stream)')
        }, 100)
      }
    })
    
    // MutationObserver로도 DOM 변경 감지 (fallback)
    const observer = new MutationObserver((mutations) => {
      mutations.forEach((mutation) => {
        if (mutation.target.id === 'calendar_grid' && mutation.type === 'childList') {
          console.log('📅 캘린더 그리드 DOM 변경 감지 (MutationObserver)')
          // 이벤트 리스너 재설정
          setTimeout(() => {
            this.setupEventDelegation()
            this.setupTooltips()
            console.log('✅ 이벤트 리스너 재설정 완료 (MutationObserver)')
          }, 100)
        }
      })
    })
    
    const calendarGrid = document.getElementById('calendar_grid')
    if (calendarGrid) {
      observer.observe(calendarGrid, { childList: true, subtree: true })
    }
  }
  
  disconnect() {
    // 이벤트 리스너 정리
    document.removeEventListener('mousemove', this.boundHandleMove)
    document.removeEventListener('mouseup', this.boundHandleMoveEnd)
    document.removeEventListener('mousemove', this.boundHandleCreateMove)
    document.removeEventListener('mouseup', this.boundHandleCreateEnd)
    document.removeEventListener('mousemove', this.boundHandleResizeMove)
    document.removeEventListener('mouseup', this.boundHandleResizeEnd)
    document.removeEventListener('keydown', this.boundHandleEscapeKey)
    
    // 테이블 이벤트 리스너 정리
    if (this.tableMouseDownHandler) {
      const calendarGrid = document.getElementById('calendar_grid')
      if (calendarGrid) {
        calendarGrid.removeEventListener('mousedown', this.tableMouseDownHandler)
      }
    }
  }
  
  // 이벤트 위임 설정
  setupEventDelegation() {
    // 이벤트를 Stimulus 컨트롤러가 있는 최상위 요소에 등록
    // tbody가 교체되어도 이벤트가 유지되도록 함
    const container = this.element  // Stimulus 컨트롤러가 연결된 최상위 div
    const calendarGrid = document.getElementById('calendar_grid')
    
    if (!container || !calendarGrid) return
    
    // 기존 리스너 제거
    if (this.mousedownHandler) {
      container.removeEventListener('mousedown', this.mousedownHandler)
    }
    if (this.clickHandler) {
      container.removeEventListener('click', this.clickHandler)
    }
    
    // mousedown 핸들러
    this.mousedownHandler = (e) => {
      // 캘린더 그리드 내부 이벤트만 처리
      if (!e.target.closest('#calendar_grid')) return
      
      // 수정/삭제 버튼 클릭 시 드래그 방지
      if (e.target.closest('.edit-btn') || e.target.closest('.delete-btn')) {
        return
      }
      
      const resizeHandle = e.target.closest('.resize-handle')
      const reservationOverlay = e.target.closest('.reservation-overlay')
      
      if (resizeHandle && reservationOverlay && reservationOverlay.dataset.isOwner === 'true') {
        // Resize 시작
        e.preventDefault()
        e.stopPropagation()
        this.startResizeReservation(e, reservationOverlay, resizeHandle.dataset.resizeDirection)
      } else if (reservationOverlay && reservationOverlay.dataset.isOwner === 'true') {
        // 예약 드래그 시작
        e.preventDefault()
        this.startMoveReservation(e, reservationOverlay)
      } else if (!reservationOverlay) {
        // 빈 셀 클릭 - 새 예약 생성
        const cell = e.target.closest('td[data-room-id][data-time-slot]')
        if (cell) {
          e.preventDefault()
          this.startCreateReservation(e, cell)
        }
      }
    }
    
    // click 핸들러
    this.clickHandler = (e) => {
      // 캘린더 그리드 내부 이벤트만 처리
      if (!e.target.closest('#calendar_grid')) return
      
      // SVG 내부 요소를 클릭해도 button을 찾을 수 있도록
      const editBtn = e.target.closest('.edit-btn')
      const deleteBtn = e.target.closest('.delete-btn')
      
      if (editBtn) {
        console.log('수정 버튼 클릭 감지')
        e.preventDefault()
        e.stopPropagation()
        this.openEditReservationModal(editBtn)
      } else if (deleteBtn) {
        console.log('삭제 버튼 클릭 감지')
        e.preventDefault()
        e.stopPropagation()
        this.deleteReservation(deleteBtn.dataset.reservationId)
      }
    }
    
    // 새로운 리스너 등록 - container에 등록하여 tbody 교체 후에도 유지
    container.addEventListener('mousedown', this.mousedownHandler)
    container.addEventListener('click', this.clickHandler)
  }
  
  // 툴팁 설정
  setupTooltips() {
    const calendarGrid = document.getElementById('calendar_grid')
    if (!calendarGrid) return
    
    let tooltip = document.getElementById('reservation-tooltip')
    if (!tooltip) {
      tooltip = document.createElement('div')
      tooltip.id = 'reservation-tooltip'
      tooltip.className = 'hidden absolute z-50 bg-gray-900 text-white p-2 rounded-lg text-xs max-w-xs whitespace-pre-line'
      document.body.appendChild(tooltip)
    }
    this.tooltip = tooltip
    
    // 예약 호버 시 툴팁 표시
    calendarGrid.addEventListener('mouseenter', (e) => {
      const reservationOverlay = e.target.closest('.reservation-overlay')
      if (reservationOverlay) {
        const startTime = reservationOverlay.dataset.startTime
        const endTime = reservationOverlay.dataset.endTime
        const userName = reservationOverlay.querySelector('.font-semibold')?.textContent
        const purpose = reservationOverlay.querySelector('.reservation-purpose')?.textContent
        
        let content = `${userName}\n${startTime} - ${endTime}`
        if (purpose) content += `\n${purpose}`
        
        tooltip.textContent = content
        tooltip.classList.remove('hidden')
        
        const rect = reservationOverlay.getBoundingClientRect()
        const scrollY = window.pageYOffset || document.documentElement.scrollTop
        tooltip.style.left = `${rect.left + rect.width / 2}px`
        tooltip.style.top = `${rect.top + scrollY - 5}px`
        tooltip.style.transform = 'translate(-50%, -100%)'
      }
    }, true)
    
    calendarGrid.addEventListener('mouseleave', (e) => {
      const reservationOverlay = e.target.closest('.reservation-overlay')
      if (reservationOverlay) {
        tooltip.classList.add('hidden')
      }
    }, true)
  }
  
  // 키보드 이벤트 리스너 설정
  setupKeyboardListeners() {
    document.addEventListener('keydown', this.boundHandleEscapeKey)
  }
  
  // ESC 키 처리
  handleEscapeKey(event) {
    if (event.key === 'Escape' || event.keyCode === 27) {
      // 새 예약 모달 닫기
      const newReservationModal = document.getElementById('newReservationModal')
      if (newReservationModal && !newReservationModal.classList.contains('hidden')) {
        event.preventDefault()
        this.closeAndResetModal()
        console.log('🔑 ESC 키로 새 예약 모달 닫음')
      }
      
      // 수정 모달 닫기
      const editReservationModal = document.getElementById('editReservationModal')
      if (editReservationModal && !editReservationModal.classList.contains('hidden')) {
        event.preventDefault()
        this.closeEditModal()
        console.log('🔑 ESC 키로 수정 모달 닫음')
      }
      
      // 드래그 중이면 취소
      if (this.isMoving) {
        event.preventDefault()
        // 원본 예약 다시 표시
        if (this.movingReservation && this.movingReservation.element) {
          this.movingReservation.element.style.display = ''
          this.movingReservation.element.classList.remove('dragging')
        }
        // 미리보기 제거
        this.hideMovePreview()
        // 상태 초기화
        this.isMoving = false
        this.movingReservation = null
        // 이벤트 리스너 제거
        document.removeEventListener('mousemove', this.boundHandleMove)
        document.removeEventListener('mouseup', this.boundHandleMoveEnd)
        console.log('🔑 ESC 키로 드래그 취소')
      }
      
      // 리사이징 중이면 취소
      if (this.isResizing) {
        event.preventDefault()
        // 미리보기 제거
        if (this.resizePreview) {
          this.resizePreview.remove()
          this.resizePreview = null
        }
        // 원본 예약 다시 표시
        if (this.resizingReservation && this.resizingReservation.element) {
          this.resizingReservation.element.style.display = ''
        }
        // 상태 초기화
        this.isResizing = false
        this.resizingReservation = null
        // 이벤트 리스너 제거
        document.removeEventListener('mousemove', this.boundHandleResizeMove)
        document.removeEventListener('mouseup', this.boundHandleResizeEnd)
        console.log('🔑 ESC 키로 리사이징 취소')
      }
      
      // 새 예약 생성 드래그 중이면 취소
      if (this.isCreating) {
        event.preventDefault()
        // 미리보기 제거
        this.hideCreatePreview()
        // 상태 초기화
        this.isCreating = false
        this.creatingReservation = null
        // 이벤트 리스너 제거
        document.removeEventListener('mousemove', this.boundHandleCreateMove)
        document.removeEventListener('mouseup', this.boundHandleCreateEnd)
        console.log('🔑 ESC 키로 새 예약 드래그 취소')
      }
    }
  }
  
  // 툴팁 표시
  showTooltip(x, y, text) {
    if (!this.tooltip) {
      this.tooltip = document.getElementById('reservation-tooltip')
      if (!this.tooltip) {
        this.tooltip = document.createElement('div')
        this.tooltip.id = 'reservation-tooltip'
        this.tooltip.className = 'absolute z-50 bg-gray-900 text-white p-2 rounded-lg text-xs max-w-xs whitespace-pre-line'
        document.body.appendChild(this.tooltip)
      }
    }
    
    this.tooltip.textContent = text
    this.tooltip.classList.remove('hidden')
    this.tooltip.style.left = `${x}px`
    this.tooltip.style.top = `${y + 10}px`
    this.tooltip.style.transform = 'translate(-50%, 0)'
  }
  
  // 툴팁 숨기기
  hideTooltip() {
    if (this.tooltip) {
      this.tooltip.classList.add('hidden')
    }
  }
  
  // 예약 드래그 시작
  startMoveReservation(event, reservationOverlay) {
    console.log('🚀 예약 드래그 시작')
    
    // 예약의 시작 시간과 현재 셀 위치로 오프셋 계산
    const rect = reservationOverlay.getBoundingClientRect()
    const parentRect = reservationOverlay.parentElement.getBoundingClientRect()
    
    // 마우스가 클릭한 위치와 예약 카드 시작점의 차이 (픽셀)
    const clickOffsetY = event.clientY - rect.top
    
    // 픽셀을 분으로 변환 (각 15분 슬롯은 24px)
    const offsetMinutes = Math.round((clickOffsetY / 24) * 15)
    
    console.log(`📏 드래그 오프셋: ${offsetMinutes}분 (클릭 위치: ${clickOffsetY}px)`)
    
    this.isMoving = true
    this.movingReservation = {
      id: reservationOverlay.dataset.reservationId,
      element: reservationOverlay,
      originalParent: reservationOverlay.parentElement,
      startX: event.clientX,
      startY: event.clientY,
      offsetMinutes: offsetMinutes  // 오프셋 저장
    }
    
    // 드래그 중 스타일
    reservationOverlay.classList.add('dragging')
    
    // 전역 이벤트 리스너 추가
    document.addEventListener('mousemove', this.boundHandleMove)
    document.addEventListener('mouseup', this.boundHandleMoveEnd)
  }
  
  // 예약 드래그 중
  handleMove(event) {
    if (!this.isMoving) return
    
    // 마우스 위치의 셀 찾기
    const cell = this.getCellFromPoint(event.clientX, event.clientY)
    
    if (cell && cell.dataset.roomId && cell.dataset.timeSlot) {
      // 드래그 미리보기 표시 (시각적 피드백)
      this.showMovePreview(cell, event)
    }
  }
  
  // 예약 드래그 종료
  handleMoveEnd(event) {
    if (!this.isMoving) return
    
    console.log('🎯 예약 드래그 종료')
    
    // 이벤트 리스너 제거
    document.removeEventListener('mousemove', this.boundHandleMove)
    document.removeEventListener('mouseup', this.boundHandleMoveEnd)
    
    // 드래그 스타일 제거
    this.movingReservation.element.classList.remove('dragging')
    
    // 기존 예약의 시작 시간과 회의실 정보
    const originalReservation = this.movingReservation.element
    const originalStartTime = originalReservation.dataset.startTime
    const originalRoomId = originalReservation.dataset.roomId
    const [origStartHour, origStartMin] = originalStartTime.split(':').map(Number)
    
    // 원본 예약 숨기기 (미리보기를 유지하기 위해)
    originalReservation.style.display = 'none'
    
    // 드롭 위치의 셀 찾기
    const cell = this.getCellFromPoint(event.clientX, event.clientY)
    
    // 캘린더 안에서 드롭한 경우
    if (cell && cell.dataset.roomId && cell.dataset.timeSlot) {
      // 기존 예약의 종료 시간도 가져오기
      const originalEndTime = originalReservation.dataset.endTime
      const [origEndHour, origEndMin] = originalEndTime.split(':').map(Number)
      const originalDurationMinutes = (origEndHour * 60 + origEndMin) - (origStartHour * 60 + origStartMin)
      
      // 마우스 위치의 셀 시간
      let cellHour = parseInt(cell.dataset.hour)
      let cellMinute = parseInt(cell.dataset.minute)
      
      // 오프셋을 적용하여 실제 시작 시간 계산
      const offsetMinutes = this.movingReservation.offsetMinutes || 0
      let startMinutes = (cellHour * 60 + cellMinute) - offsetMinutes
      
      // 15분 단위로 반올림
      startMinutes = Math.round(startMinutes / 15) * 15
      
      // 시작 시간을 시/분으로 변환
      let newStartHour = Math.floor(startMinutes / 60)
      let newStartMinute = startMinutes % 60
      
      // 09:00 이전 처리 - duration 조정
      let adjustedDurationMinutes = originalDurationMinutes
      if (newStartHour < 9 || (newStartHour === 9 && newStartMinute < 0)) {
        const minutesBefore9AM = (9 * 60) - (newStartHour * 60 + newStartMinute)
        adjustedDurationMinutes = Math.max(15, originalDurationMinutes - minutesBefore9AM)
        newStartHour = 9
        newStartMinute = 0
      }
      
      // 음수 분 처리
      if (newStartMinute < 0) {
        newStartHour -= 1
        newStartMinute += 60
      }
      
      // 새로운 종료 시간 계산
      let newEndMinutes = newStartHour * 60 + newStartMinute + adjustedDurationMinutes
      if (newEndMinutes > 18 * 60) {
        newEndMinutes = 18 * 60
        adjustedDurationMinutes = newEndMinutes - (newStartHour * 60 + newStartMinute)
      }
      const newEndHour = Math.floor(newEndMinutes / 60)
      const newEndMinute = newEndMinutes % 60
      
      // 실제로 변경되었는지 확인 (시작 시간, 종료 시간, 회의실 모두 확인)
      const roomChanged = cell.dataset.roomId !== originalRoomId
      const timeChanged = newStartHour !== origStartHour || newStartMinute !== origStartMin || 
                         newEndHour !== origEndHour || newEndMinute !== origEndMin
      
      console.log('🔍 이동 확인:', {
        원래: `${originalStartTime}~${originalEndTime} / 회의실 ${originalRoomId}`,
        새위치: `${String(newStartHour).padStart(2, '0')}:${String(newStartMinute).padStart(2, '0')}~${String(newEndHour).padStart(2, '0')}:${String(newEndMinute).padStart(2, '0')} / 회의실 ${cell.dataset.roomId}`,
        변경여부: roomChanged || timeChanged
      })
      
      if (roomChanged || timeChanged) {
        console.log(`✅ 예약 업데이트: ${String(newStartHour).padStart(2, '0')}:${String(newStartMinute).padStart(2, '0')}~${String(newEndHour).padStart(2, '0')}:${String(newEndMinute).padStart(2, '0')}`)
        
        // 서버에 업데이트 요청 - 종료 시간도 전달
        const reservationId = this.movingReservation.element.dataset.reservationId
        const newStartTime = `${String(newStartHour).padStart(2, '0')}:${String(newStartMinute).padStart(2, '0')}`
        const newEndTime = `${String(newEndHour).padStart(2, '0')}:${String(newEndMinute).padStart(2, '0')}`
        
        // 미리보기는 유지하고 원본은 숨긴 상태로 서버 요청
        this.updateReservationTime(
          reservationId,
          cell.dataset.roomId,
          newStartTime,
          newEndTime
        )
      } else {
        console.log('📍 같은 위치로 이동 - 업데이트 건너뜀')
        // 원본 예약 다시 표시
        this.movingReservation.element.style.display = ''
        // 미리보기 제거
        this.hideMovePreview()
      }
    } else if (this.lastValidPreview) {
      // 캘린더 밖에서 드롭한 경우 - 마지막 미리보기 위치 사용
      console.log('📌 캘린더 밖 드롭 - 마지막 미리보기 위치 사용:', this.lastValidPreview)
      
      // 기존 예약의 종료 시간도 가져오기
      const originalEndTime = originalReservation.dataset.endTime
      const [origEndHour, origEndMin] = originalEndTime.split(':').map(Number)
      
      const { roomId, startHour, startMinute, endHour, endMinute } = this.lastValidPreview
      
      // 실제로 변경되었는지 확인 (시작 시간, 종료 시간, 회의실 모두 확인)
      const roomChanged = roomId !== originalRoomId
      const timeChanged = startHour !== origStartHour || startMinute !== origStartMin || 
                         endHour !== origEndHour || endMinute !== origEndMin
      
      console.log('🔍 이동 확인:', {
        원래: `${originalStartTime}~${originalEndTime} / 회의실 ${originalRoomId}`,
        새위치: `${String(startHour).padStart(2, '0')}:${String(startMinute).padStart(2, '0')}~${String(endHour).padStart(2, '0')}:${String(endMinute).padStart(2, '0')} / 회의실 ${roomId}`,
        변경여부: roomChanged || timeChanged
      })
      
      if (roomChanged || timeChanged) {
        console.log(`✅ 예약 업데이트: ${String(startHour).padStart(2, '0')}:${String(startMinute).padStart(2, '0')}~${String(endHour).padStart(2, '0')}:${String(endMinute).padStart(2, '0')}`)
        
        // 서버에 업데이트 요청
        const reservationId = this.movingReservation.element.dataset.reservationId
        const newStartTime = `${String(startHour).padStart(2, '0')}:${String(startMinute).padStart(2, '0')}`
        const newEndTime = `${String(endHour).padStart(2, '0')}:${String(endMinute).padStart(2, '0')}`
        
        // 미리보기는 유지하고 원본은 숨긴 상태로 서버 요청
        this.updateReservationTime(
          reservationId,
          roomId,
          newStartTime,
          newEndTime
        )
      } else {
        console.log('📍 같은 위치로 이동 - 업데이트 건너뜀')
        // 원본 예약 다시 표시
        this.movingReservation.element.style.display = ''
        // 미리보기 제거
        this.hideMovePreview()
      }
    } else {
      console.log('⚠️ 유효하지 않은 드롭 위치 - 원래 위치로 복원')
      // 원본 예약 다시 표시
      this.movingReservation.element.style.display = ''
      // 미리보기 제거
      this.hideMovePreview()
    }
    
    this.isMoving = false
    this.movingReservation = null
    this.lastValidPreview = null  // 미리보기 위치 초기화
  }
  
  // 빈 셀 드래그 시작 (새 예약 생성)
  startCreateReservation(event, cell) {
    if (!cell.dataset.roomId || !cell.dataset.timeSlot) return
    
    console.log('🎨 새 예약 드래그 시작')
    
    this.isCreating = true
    this.creatingReservation = {
      startRoomId: cell.dataset.roomId,
      startTimeSlot: parseInt(cell.dataset.timeSlot),
      currentTimeSlot: parseInt(cell.dataset.timeSlot),
      roomId: cell.dataset.roomId
    }
    
    // 드래그 미리보기 표시
    this.showCreatePreview(cell)
    
    // 전역 이벤트 리스너 추가
    document.addEventListener('mousemove', this.boundHandleCreateMove)
    document.addEventListener('mouseup', this.boundHandleCreateEnd)
  }
  
  // 빈 셀 드래그 중
  handleCreateMove(event) {
    if (!this.isCreating) return
    
    const cell = this.getCellFromPoint(event.clientX, event.clientY)
    
    if (cell && cell.dataset.roomId && cell.dataset.timeSlot) {
      const roomId = cell.dataset.roomId
      const timeSlot = parseInt(cell.dataset.timeSlot)
      
      // 같은 회의실에서만 드래그 가능
      if (roomId !== this.creatingReservation.startRoomId) return
      
      this.creatingReservation.currentTimeSlot = timeSlot
      this.updateCreatePreview(timeSlot)
    }
  }
  
  // 빈 셀 드래그 종료
  handleCreateEnd(event) {
    if (!this.isCreating) return
    
    console.log('🎨 새 예약 드래그 종료')
    
    // 이벤트 리스너 제거
    document.removeEventListener('mousemove', this.boundHandleCreateMove)
    document.removeEventListener('mouseup', this.boundHandleCreateEnd)
    
    // 미리보기 제거
    this.hideCreatePreview()
    
    // 새 예약 모달 열기
    if (this.creatingReservation) {
      const { startRoomId, startTimeSlot, currentTimeSlot } = this.creatingReservation
      
      // 시작과 끝 시간 계산
      const minSlot = Math.min(startTimeSlot, currentTimeSlot)
      const maxSlot = Math.max(startTimeSlot, currentTimeSlot)
      
      const startHour = Math.floor(minSlot / 4) + 9
      const startMinute = (minSlot % 4) * 15
      const endHour = Math.floor((maxSlot + 1) / 4) + 9
      const endMinute = ((maxSlot + 1) % 4) * 15
      
      // 모달 열기
      this.openNewReservationModal(startRoomId, startHour, startMinute, endHour, endMinute)
    }
    
    this.isCreating = false
    this.creatingReservation = null
  }
  
  // 마우스 위치에서 셀 찾기
  getCellFromPoint(x, y) {
    // 모든 요소를 가져오기
    const elements = document.elementsFromPoint(x, y)
    // td[data-room-id]를 찾기 (예약 오버레이를 건너뛰고)
    for (const element of elements) {
      if (element.matches('td[data-room-id]')) {
        return element
      }
    }
    return null
  }
  
  // Resize 시작
  startResizeReservation(event, reservationElement, direction) {
    console.log('🔧 Resize 시작:', direction)
    
    this.isResizing = true
    this.resizingReservation = {
      element: reservationElement,
      direction: direction,
      id: reservationElement.dataset.reservationId,
      roomId: reservationElement.dataset.roomId,
      originalStartTime: reservationElement.dataset.startTime,
      originalEndTime: reservationElement.dataset.endTime,
      initialY: event.clientY,
      parentCell: reservationElement.closest('td'),
      // 초기 위치와 크기 저장
      initialTop: parseInt(reservationElement.style.top),
      initialHeight: parseInt(reservationElement.style.height)
    }
    
    // 원본 예약 숨기기
    reservationElement.style.display = 'none'
    
    // 미리보기 생성
    this.createResizePreview(reservationElement)
    
    // 전역 이벤트 리스너 추가
    document.addEventListener('mousemove', this.boundHandleResizeMove)
    document.addEventListener('mouseup', this.boundHandleResizeEnd)
  }
  
  // Resize 미리보기 생성
  createResizePreview(reservationElement) {
    const preview = document.createElement('div')
    preview.id = 'resize-preview'
    preview.className = 'drag-preview'
    preview.style.position = 'absolute'
    preview.style.left = '2px'
    preview.style.right = '2px'
    
    // 원본 예약의 스타일에서 위치와 크기 가져오기
    preview.style.top = reservationElement.style.top
    preview.style.height = reservationElement.style.height
    
    // 시간 표시 추가
    const roomName = this.resizingReservation.parentCell.dataset.roomIndex ? 
      this.allRoomsValue[this.resizingReservation.parentCell.dataset.roomIndex]?.name : ''
    const timeDisplay = document.createElement('div')
    timeDisplay.className = 'text-xs font-semibold p-1'
    timeDisplay.style.color = 'rgb(99, 102, 241)'
    timeDisplay.innerHTML = `
      <div>${roomName}</div>
      <div class="time-display">${this.resizingReservation.originalStartTime} - ${this.resizingReservation.originalEndTime}</div>
      <div class="resize-info">크기 조절 중...</div>
    `
    preview.appendChild(timeDisplay)
    
    this.resizingReservation.parentCell.appendChild(preview)
    this.resizePreview = preview
  }
  
  // Resize 중
  handleResizeMove(event) {
    if (!this.isResizing || !this.resizePreview) return
    
    const deltaY = event.clientY - this.resizingReservation.initialY
    const slotHeight = 24 // 각 15분 슬롯의 높이
    const slotsDelta = Math.round(deltaY / slotHeight)
    
    // 현재 시간 계산
    const [startHour, startMin] = this.resizingReservation.originalStartTime.split(':').map(Number)
    const [endHour, endMin] = this.resizingReservation.originalEndTime.split(':').map(Number)
    
    let newStartTime, newEndTime
    let newTopOffset, newHeight
    let isLimited = false
    
    // 초기 저장된 위치 사용
    const originalTop = this.resizingReservation.initialTop
    const originalHeight = this.resizingReservation.initialHeight
    
    if (this.resizingReservation.direction === 'top') {
      // 시작 시간 조정
      let newStartMinutes = (startHour * 60 + startMin) + (slotsDelta * 15)
      let newStartHour = Math.floor(newStartMinutes / 60)
      let newStartMin = newStartMinutes % 60
      
      // 09:00 제한
      if (newStartHour < 9) {
        newStartHour = 9
        newStartMin = 0
        newStartMinutes = 9 * 60
        isLimited = true
      }
      
      // 종료시간-15분보다 늦으면 리턴
      if (newStartMinutes >= (endHour * 60 + endMin - 15)) return
      
      newStartTime = `${String(newStartHour).padStart(2, '0')}:${String(newStartMin).padStart(2, '0')}`
      newEndTime = this.resizingReservation.originalEndTime
      
      // 위치 및 크기 계산
      const actualSlotsDelta = Math.floor((newStartMinutes - (startHour * 60 + startMin)) / 15)
      newTopOffset = originalTop + (actualSlotsDelta * slotHeight)
      newHeight = originalHeight - (actualSlotsDelta * slotHeight)
    } else {
      // 종료 시간 조정
      let newEndMinutes = (endHour * 60 + endMin) + (slotsDelta * 15)
      let newEndHour = Math.floor(newEndMinutes / 60)
      let newEndMin = newEndMinutes % 60
      
      // 18:00 제한
      if (newEndMinutes > 18 * 60) {
        newEndHour = 18
        newEndMin = 0
        newEndMinutes = 18 * 60
        isLimited = true
      }
      
      // 시작시간+15분보다 이르면 리턴
      if (newEndMinutes <= (startHour * 60 + startMin + 15)) return
      
      newStartTime = this.resizingReservation.originalStartTime
      newEndTime = `${String(newEndHour).padStart(2, '0')}:${String(newEndMin).padStart(2, '0')}`
      
      // 위치 및 크기 계산
      const actualSlotsDelta = Math.floor((newEndMinutes - (endHour * 60 + endMin)) / 15)
      newTopOffset = originalTop
      newHeight = originalHeight + (actualSlotsDelta * slotHeight)
    }
    
    // 미리보기 업데이트
    this.resizePreview.style.top = `${newTopOffset}px`
    this.resizePreview.style.height = `${newHeight}px`
    
    // 시간 표시 업데이트
    const timeDisplay = this.resizePreview.querySelector('.time-display')
    if (timeDisplay) {
      timeDisplay.textContent = `${newStartTime} - ${newEndTime}`
    }
    
    // 크기 조절 정보 업데이트
    const resizeInfo = this.resizePreview.querySelector('.resize-info')
    if (resizeInfo) {
      const duration = this.calculateDuration(newStartTime, newEndTime)
      resizeInfo.textContent = `${duration}분 예약`
    }
  }
  
  // 예약 시간 계산
  calculateDuration(startTime, endTime) {
    const [startHour, startMin] = startTime.split(':').map(Number)
    const [endHour, endMin] = endTime.split(':').map(Number)
    return (endHour * 60 + endMin) - (startHour * 60 + startMin)
  }
  
  // Resize 종료
  handleResizeEnd(event) {
    if (!this.isResizing) return
    
    console.log('🔧 Resize 종료')
    
    // 이벤트 리스너 제거
    document.removeEventListener('mousemove', this.boundHandleResizeMove)
    document.removeEventListener('mouseup', this.boundHandleResizeEnd)
    
    // 최종 시간 계산
    const deltaY = event.clientY - this.resizingReservation.initialY
    const slotHeight = 24
    const slotsDelta = Math.round(deltaY / slotHeight)
    
    if (slotsDelta !== 0) {
      const [startHour, startMin] = this.resizingReservation.originalStartTime.split(':').map(Number)
      const [endHour, endMin] = this.resizingReservation.originalEndTime.split(':').map(Number)
      
      let newStartTime, newEndTime
      
      if (this.resizingReservation.direction === 'top') {
        const newStartMinutes = (startHour * 60 + startMin) + (slotsDelta * 15)
        const newStartHour = Math.floor(newStartMinutes / 60)
        const newStartMin = newStartMinutes % 60
        
        if (newStartHour >= 9 && newStartMinutes < (endHour * 60 + endMin - 15)) {
          newStartTime = `${String(newStartHour).padStart(2, '0')}:${String(newStartMin).padStart(2, '0')}`
          newEndTime = this.resizingReservation.originalEndTime
          
          // 미리보기는 유지하고 원본은 숨긴 상태로 서버 요청
          this.updateReservationTime(
            this.resizingReservation.id,
            this.resizingReservation.roomId,
            newStartTime,
            newEndTime
          )
        } else {
          // 변경 없음 - 원본 예약 표시 복원
          this.resizingReservation.element.style.display = ''
          // 미리보기 제거
          if (this.resizePreview) {
            this.resizePreview.remove()
            this.resizePreview = null
          }
        }
      } else {
        const newEndMinutes = (endHour * 60 + endMin) + (slotsDelta * 15)
        const newEndHour = Math.floor(newEndMinutes / 60)
        const newEndMin = newEndMinutes % 60
        
        if (newEndHour <= 18 && newEndMinutes > (startHour * 60 + startMin + 15)) {
          newStartTime = this.resizingReservation.originalStartTime
          newEndTime = `${String(newEndHour).padStart(2, '0')}:${String(newEndMin).padStart(2, '0')}`
          
          // 미리보기는 유지하고 원본은 숨긴 상태로 서버 요청
          this.updateReservationTime(
            this.resizingReservation.id,
            this.resizingReservation.roomId,
            newStartTime,
            newEndTime
          )
        } else {
          // 변경 없음 - 원본 예약 표시 복원
          this.resizingReservation.element.style.display = ''
          // 미리보기 제거
          if (this.resizePreview) {
            this.resizePreview.remove()
            this.resizePreview = null
          }
        }
      }
    } else {
      // 변경 없음 - 원본 예약 표시 복원
      this.resizingReservation.element.style.display = ''
      // 미리보기 제거
      if (this.resizePreview) {
        this.resizePreview.remove()
        this.resizePreview = null
      }
    }
    
    this.isResizing = false
    this.resizingReservation = null
  }
  
  // 예약 시간 업데이트 (서버 요청)
  updateReservationTime(reservationId, roomId, startTime, endTime) {
    console.log('📡 예약 시간 업데이트:', {
      id: reservationId,
      roomId: roomId,
      startTime: startTime,
      endTime: endTime
    })
    
    // CSRF 토큰 가져오기
    const token = document.querySelector('[name="csrf-token"]')?.content
    
    // 서버에 AJAX 요청
    fetch(`/room_reservations/${reservationId}`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': token,
        'Accept': 'text/vnd.turbo-stream.html'
      },
      body: JSON.stringify({
        room_reservation: {
          room_id: roomId,
          start_time: startTime,
          end_time: endTime
        }
      })
    })
    .then(response => {
      if (response.ok) {
        return response.text()
      } else {
        // 에러 응답을 JSON으로 파싱하여 상세 정보 가져오기
        return response.json().then(data => {
          throw new Error(data.error || data.errors?.join(', ') || '업데이트 실패')
        })
      }
    })
    .then(html => {
      // Turbo Stream 업데이트 처리
      Turbo.renderStreamMessage(html)
    })
    .catch(error => {
      console.error('❌ 예약 업데이트 오류:', error)
      
      // 에러 발생 시 UI 복원
      // 1. 미리보기 제거
      this.hideMovePreview()
      if (this.resizePreview) {
        this.resizePreview.remove()
        this.resizePreview = null
      }
      
      // 2. 원본 예약 다시 표시
      if (this.movingReservation && this.movingReservation.element) {
        this.movingReservation.element.style.display = ''
      }
      if (this.resizingReservation && this.resizingReservation.element) {
        this.resizingReservation.element.style.display = ''
      }
      
      // 3. 상태 초기화
      this.isMoving = false
      this.movingReservation = null
      this.isResizing = false
      this.resizingReservation = null
      
      // 4. 에러 메시지 표시 후 페이지 새로고침
      alert(`예약 업데이트에 실패했습니다.\n\n${error.message}`)
      
      // 5. Turbo를 통해 캘린더 새로고침 (원본 상태로 완전 복원)
      Turbo.visit(window.location.href, { action: 'replace' })
    })
  }
  
  // 예약 업데이트 (서버 요청)
  updateReservation(reservationId, roomId, hour, minute) {
    // 기존 예약의 시작/종료 시간 가져오기
    const originalReservation = this.movingReservation.element
    const originalStartTime = originalReservation.dataset.startTime
    const originalEndTime = originalReservation.dataset.endTime
    
    // 기존 duration 계산
    const [origStartHour, origStartMin] = originalStartTime.split(':').map(Number)
    const [origEndHour, origEndMin] = originalEndTime.split(':').map(Number)
    const durationMinutes = (origEndHour * 60 + origEndMin) - (origStartHour * 60 + origStartMin)
    
    // 새로운 시작 시간과 duration 조정
    let adjustedHour = parseInt(hour)
    let adjustedMinute = parseInt(minute)
    let adjustedDurationMinutes = durationMinutes
    
    // 09:00 이전이면 시작 시간은 09:00으로, duration은 줄어든 만큼 감소
    if (adjustedHour < 9) {
      const minutesBefore9AM = (9 * 60) - (adjustedHour * 60 + adjustedMinute)
      adjustedDurationMinutes = Math.max(15, durationMinutes - minutesBefore9AM) // 최소 15분 유지
      adjustedHour = 9
      adjustedMinute = 0
    }
    
    const newStartTime = `${String(adjustedHour).padStart(2, '0')}:${String(adjustedMinute).padStart(2, '0')}`
    
    // 새로운 종료 시간 (조정된 duration 사용, 18:00 초과 시에만 18:00으로 제한)
    const newEndMinutes = adjustedHour * 60 + adjustedMinute + adjustedDurationMinutes
    let finalEndHour, finalEndMin
    
    if (newEndMinutes > 18 * 60) {
      // 18:00을 초과하는 경우에만 제한
      finalEndHour = 18
      finalEndMin = 0
    } else {
      // 18:00 이하인 경우 조정된 duration 유지
      finalEndHour = Math.floor(newEndMinutes / 60)
      finalEndMin = newEndMinutes % 60
    }
    
    const newEndTime = `${String(finalEndHour).padStart(2, '0')}:${String(finalEndMin).padStart(2, '0')}`
    
    console.log('📋 예약 이동:', {
      original: `${originalStartTime} - ${originalEndTime}`,
      new: `${newStartTime} - ${newEndTime}`,
      duration: `${durationMinutes}분`
    })
    
    // CSRF 토큰 가져오기
    const token = document.querySelector('[name="csrf-token"]')?.content
    
    fetch(`/room_reservations/${reservationId}`, {
      method: 'PATCH',
      headers: {
        'Content-Type': 'application/json',
        'X-CSRF-Token': token,
        'Accept': 'text/vnd.turbo-stream.html, application/json'
      },
      body: JSON.stringify({
        room_reservation: {
          room_id: roomId,
          start_time: newStartTime,
          end_time: newEndTime
        }
      })
    })
    .then(response => {
      if (!response.ok) {
        // 에러 응답을 JSON으로 파싱하여 상세 정보 가져오기
        return response.json().then(data => {
          throw new Error(data.error || data.errors?.join(', ') || '업데이트 실패')
        })
      }
      
      // Turbo Stream 응답 처리
      const contentType = response.headers.get('Content-Type')
      if (contentType && contentType.includes('text/vnd.turbo-stream.html')) {
        return response.text().then(html => {
          console.log('📝 Turbo Stream 응답 받음, 렌더링 시작')
          // Turbo가 직접 렌더링하도록 함
          Turbo.renderStreamMessage(html)
          console.log('✅ 예약 업데이트 및 렌더링 성공')
        })
      } else {
        console.log('✅ 예약 업데이트 성공')
      }
    })
    .catch(error => {
      console.error('❌ 예약 업데이트 실패:', error)
      alert(`예약 변경에 실패했습니다.\n\n${error.message}`)
      
      // 실패 시 페이지 새로고침
      Turbo.visit(window.location.href, { action: 'replace' })
    })
  }
  
  // 드래그 미리보기 표시
  showMovePreview(cell, event) {
    this.hideMovePreview()
    
    // 기존 예약의 duration 가져오기
    const originalReservation = this.movingReservation.element
    const originalStartTime = originalReservation.dataset.startTime
    const originalEndTime = originalReservation.dataset.endTime
    
    const [origStartHour, origStartMin] = originalStartTime.split(':').map(Number)
    const [origEndHour, origEndMin] = originalEndTime.split(':').map(Number)
    const durationMinutes = (origEndHour * 60 + origEndMin) - (origStartHour * 60 + origStartMin)
    
    // 마우스 위치의 셀 시간
    let cellHour = parseInt(cell.dataset.hour)
    let cellMinute = parseInt(cell.dataset.minute)
    
    // 오프셋을 적용하여 실제 시작 시간 계산
    const offsetMinutes = this.movingReservation.offsetMinutes || 0
    let startMinutes = (cellHour * 60 + cellMinute) - offsetMinutes
    
    // 15분 단위로 반올림
    startMinutes = Math.round(startMinutes / 15) * 15
    
    // 시작 시간을 시/분으로 변환
    let hour = Math.floor(startMinutes / 60)
    let minute = startMinutes % 60
    
    // 09:00 이전 처리 - 시작 시간과 종료 시간 모두 조정
    let adjustedDurationMinutes = durationMinutes
    if (hour < 9 || (hour === 9 && minute < 0)) {
      // 09:00 이전으로 가려는 만큼 duration 감소
      const minutesBefore9AM = (9 * 60) - (hour * 60 + minute)
      adjustedDurationMinutes = Math.max(15, durationMinutes - minutesBefore9AM) // 최소 15분 유지
      hour = 9
      minute = 0
    }
    
    // 음수 분 처리
    if (minute < 0) {
      hour -= 1
      minute += 60
    }
    
    console.log(`🎯 드래그 중: ${String(hour).padStart(2, '0')}:${String(minute).padStart(2, '0')} (오프셋: ${offsetMinutes}분, duration: ${adjustedDurationMinutes}분)`)
    
    // 종료 시간 계산
    let newEndMinutes = hour * 60 + minute + adjustedDurationMinutes
    let actualDurationMinutes = adjustedDurationMinutes
    
    // 18:00을 초과하는 경우만 종료시간을 18:00으로 제한
    if (newEndMinutes > 18 * 60) {
      newEndMinutes = 18 * 60
      actualDurationMinutes = newEndMinutes - (hour * 60 + minute)
    }
    
    const newEndHour = Math.floor(newEndMinutes / 60)
    const newEndMin = newEndMinutes % 60
    const slotCount = Math.ceil(actualDurationMinutes / 15)
    
    // 회의실 이름
    const roomName = this.getRoomName(cell.dataset.roomId)
    
    // 실제 시작 시간에 해당하는 셀 찾기
    const actualStartSlot = Math.floor(((hour - 9) * 60 + minute) / 15)
    const targetCell = document.querySelector(
      `td[data-room-id="${cell.dataset.roomId}"][data-time-slot="${actualStartSlot}"]`
    )
    
    if (!targetCell) {
      console.warn('대상 셀을 찾을 수 없음')
      return
    }
    
    const preview = document.createElement('div')
    preview.className = 'drag-preview'
    preview.id = 'move-preview'
    preview.style.position = 'absolute'
    preview.style.top = '2px'
    preview.style.height = `${slotCount * 24 - 4}px`  // 실제 크기에 맞게 조정
    preview.style.zIndex = '20'
    
    // 미리보기에 표시될 시간 (드래그한 위치 그대로, 종료시간만 18:00 제한)
    const previewStartTime = `${String(hour).padStart(2, '0')}:${String(minute).padStart(2, '0')}`
    const previewEndTime = `${String(newEndHour).padStart(2, '0')}:${String(newEndMin).padStart(2, '0')}`
    
    console.log(`📦 미리보기 표시: ${previewStartTime}~${previewEndTime} (원래 duration: ${durationMinutes}분, 조정된 duration: ${actualDurationMinutes}분)`)
    
    // 정보 표시
    preview.innerHTML = `
      <div class="text-xs text-indigo-900 p-1 font-bold">
        ${roomName}<br>
        ${previewStartTime}~${previewEndTime}
      </div>
    `
    
    // 실제 시작 시간에 해당하는 셀에 미리보기 추가
    targetCell.appendChild(preview)
    
    // 마지막 유효한 미리보기 위치 저장 (캘린더 밖 드롭 시 사용)
    this.lastValidPreview = {
      roomId: cell.dataset.roomId,
      startHour: hour,
      startMinute: minute,
      endHour: newEndHour,
      endMinute: newEndMin,
      originalDuration: durationMinutes,
      adjustedDuration: actualDurationMinutes
    }
    console.log('💾 미리보기 위치 저장:', this.lastValidPreview)
  }
  
  // 드래그 미리보기 숨기기
  hideMovePreview() {
    const preview = document.getElementById('move-preview')
    if (preview) {
      preview.remove()
    }
  }
  
  // 생성 미리보기 표시
  showCreatePreview(cell) {
    this.hideCreatePreview()
    
    const roomId = cell.dataset.roomId
    const timeSlot = parseInt(cell.dataset.timeSlot)
    const hour = Math.floor(timeSlot / 4) + 9
    const minute = (timeSlot % 4) * 15
    
    // 회의실 이름 찾기
    const roomName = this.getRoomName(roomId)
    
    const preview = document.createElement('div')
    preview.className = 'drag-preview'
    preview.id = 'create-preview'
    preview.style.position = 'absolute'
    preview.style.top = '2px'
    preview.style.height = '20px'
    preview.style.zIndex = '20'
    
    // 정보 표시 추가
    preview.innerHTML = `
      <div class="text-xs text-indigo-900 p-1 font-bold">
        ${roomName}<br>
        ${String(hour).padStart(2, '0')}:${String(minute).padStart(2, '0')}~
      </div>
    `
    
    cell.appendChild(preview)
  }
  
  // 회의실 이름 가져오기
  getRoomName(roomId) {
    const room = this.allRoomsValue.find(r => r.id == roomId)
    if (!room) {
      // allRoomsValue가 없으면 테이블 헤더에서 찾기
      const roomIndex = Array.from(document.querySelectorAll('td[data-room-id]'))
        .find(td => td.dataset.roomId == roomId)?.dataset.roomIndex
      
      if (roomIndex) {
        const headerCell = document.querySelectorAll('thead th')[parseInt(roomIndex) + 1]
        return headerCell?.querySelector('.truncate')?.textContent || '회의실'
      }
    }
    return room?.name || '회의실'
  }
  
  // 생성 미리보기 업데이트
  updateCreatePreview(currentSlot) {
    const preview = document.getElementById('create-preview')
    if (!preview) return
    
    const startSlot = this.creatingReservation.startTimeSlot
    const minSlot = Math.min(startSlot, currentSlot)
    const maxSlot = Math.max(startSlot, currentSlot)
    
    // 시간 계산
    const startHour = Math.floor(minSlot / 4) + 9
    const startMinute = (minSlot % 4) * 15
    const endHour = Math.floor((maxSlot + 1) / 4) + 9
    const endMinute = ((maxSlot + 1) % 4) * 15
    
    // 회의실 이름
    const roomName = this.getRoomName(this.creatingReservation.roomId)
    
    // 미리보기 크기 조정
    const height = (maxSlot - minSlot + 1) * 24 - 4
    preview.style.height = `${height}px`
    
    // 정보 업데이트
    preview.innerHTML = `
      <div class="text-xs text-indigo-900 p-1 font-bold">
        ${roomName}<br>
        ${String(startHour).padStart(2, '0')}:${String(startMinute).padStart(2, '0')}~${String(endHour).padStart(2, '0')}:${String(endMinute).padStart(2, '0')}
      </div>
    `
    
    // 위치 조정 (상위 슬롯으로 이동 필요한 경우)
    if (currentSlot < startSlot) {
      const diff = startSlot - currentSlot
      preview.style.top = `${2 - diff * 24}px`
    } else {
      preview.style.top = '2px'
    }
  }
  
  // 생성 미리보기 숨기기
  hideCreatePreview() {
    const preview = document.getElementById('create-preview')
    if (preview) {
      preview.remove()
    }
  }
  
  // 새 예약 모달 열기
  openNewReservationModal(roomId, startHour, startMinute, endHour, endMinute) {
    const modal = document.getElementById('newReservationModal')
    if (modal) {
      // 모달 내용 초기화 (로딩 상태로)
      const frame = modal.querySelector('turbo-frame')
      if (frame) {
        frame.innerHTML = `
          <div class="text-center py-4">
            <div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-indigo-600"></div>
            <p class="mt-2 text-sm text-gray-500">로딩 중...</p>
          </div>
        `
      }
      
      // 모달 표시
      modal.classList.remove('hidden')
      
      // 드래그에서 선택한 시간/회의실 정보로 폼 로드
      if (frame) {
        const startTime = `${String(startHour).padStart(2, '0')}:${String(startMinute).padStart(2, '0')}`
        const endTime = `${String(endHour).padStart(2, '0')}:${String(endMinute).padStart(2, '0')}`
        const date = this.dateValue || new Date().toISOString().split('T')[0]
        
        // 드래그에서 선택한 정보로 새 폼 로드
        frame.src = `/room_reservations/new?modal=true&room_id=${roomId}&date=${date}&start_time=${startTime}&end_time=${endTime}&from_drag=true`
      }
    }
  }
  
  // 새 예약 모달 표시 (버튼 클릭용)
  showNewReservationModal(event) {
    event.preventDefault()
    const modal = document.getElementById('newReservationModal')
    if (modal) {
      // 모달 내용 초기화 (로딩 상태로)
      const frame = modal.querySelector('turbo-frame')
      if (frame) {
        frame.innerHTML = `
          <div class="text-center py-4">
            <div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-indigo-600"></div>
            <p class="mt-2 text-sm text-gray-500">로딩 중...</p>
          </div>
        `
      }
      
      // 모달 표시
      modal.classList.remove('hidden')
      
      // 기본 폼 로드 (파라미터 없이)
      if (frame) {
        const date = this.dateValue || new Date().toISOString().split('T')[0]
        frame.src = `/room_reservations/new?modal=true&date=${date}`
      }
    }
  }
  
  // 모달 닫기와 초기화
  closeAndResetModal(event) {
    if (event) event.preventDefault()
    
    const modal = document.getElementById('newReservationModal')
    if (modal) {
      modal.classList.add('hidden')
      
      // 프레임 내용 초기화 및 src 제거
      const frame = modal.querySelector('turbo-frame')
      if (frame) {
        // src를 제거하여 다음에 열 때 새로 로드하도록 함
        frame.removeAttribute('src')
        frame.innerHTML = `
          <div class="text-center py-4">
            <div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-indigo-600"></div>
            <p class="mt-2 text-sm text-gray-500">로딩 중...</p>
          </div>
        `
      }
    }
  }
  
  // 모달 닫기
  closeModal(event) {
    if (event) event.preventDefault()
    
    // 모든 모달 숨기고 초기화
    const modals = ['newReservationModal', 'editReservationModal']
    modals.forEach(modalId => {
      const modal = document.getElementById(modalId)
      if (modal) {
        modal.classList.add('hidden')
        
        // 프레임 초기화
        const frame = modal.querySelector('turbo-frame')
        if (frame) {
          frame.removeAttribute('src')
          frame.innerHTML = `
            <div class="text-center py-4">
              <div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-indigo-600"></div>
              <p class="mt-2 text-sm text-gray-500">로딩 중...</p>
            </div>
          `
        }
      }
    })
  }
  
  // 수정 모달 닫기
  closeEditModal(event) {
    if (event) event.preventDefault()
    
    const modal = document.getElementById('editReservationModal')
    if (modal) {
      modal.classList.add('hidden')
      
      // 프레임 초기화
      const frame = modal.querySelector('turbo-frame')
      if (frame) {
        frame.removeAttribute('src')
        frame.innerHTML = `
          <div class="text-center py-4">
            <div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-indigo-600"></div>
            <p class="mt-2 text-sm text-gray-500">로딩 중...</p>
          </div>
        `
      }
    }
  }
  
  // 수정 모달 열기
  openEditReservationModal(button) {
    const reservationId = button.dataset.reservationId
    const roomId = button.dataset.roomId
    const date = button.dataset.date
    const startTime = button.dataset.startTime
    const endTime = button.dataset.endTime
    const purpose = button.dataset.purpose
    
    console.log('📝 수정 모달 열기:', { reservationId, roomId, date, startTime, endTime })
    
    const modal = document.getElementById('editReservationModal')
    if (modal) {
      // 모달 내용 초기화 (로딩 상태로)
      const frame = modal.querySelector('turbo-frame')
      if (frame) {
        frame.innerHTML = `
          <div class="text-center py-4">
            <div class="inline-block animate-spin rounded-full h-8 w-8 border-b-2 border-indigo-600"></div>
            <p class="mt-2 text-sm text-gray-500">로딩 중...</p>
          </div>
        `
      }
      
      // 모달 표시
      modal.classList.remove('hidden')
      
      // 수정 폼 로드
      if (frame) {
        frame.src = `/room_reservations/${reservationId}/edit?modal=true`
      }
    }
  }
  
  // 예약 삭제
  deleteReservation(reservationId) {
    if (!confirm('정말로 이 예약을 취소하시겠습니까?')) return
    
    console.log('🗑️ 예약 삭제:', reservationId)
    
    // CSRF 토큰 가져오기
    const token = document.querySelector('[name="csrf-token"]')?.content
    
    fetch(`${window.location.origin}/room_reservations/${reservationId}`, {
      method: 'DELETE',
      headers: {
        'X-CSRF-Token': token,
        'Accept': 'text/vnd.turbo-stream.html'
      }
    })
    .then(response => {
      if (response.ok) {
        return response.text()
      } else {
        throw new Error('삭제 실패')
      }
    })
    .then(html => {
      // Turbo Stream 업데이트 처리
      if (html) {
        Turbo.renderStreamMessage(html)
      }
    })
    .catch(error => {
      console.error('❌ 예약 삭제 실패:', error)
      alert('예약 취소에 실패했습니다.')
    })
  }
}