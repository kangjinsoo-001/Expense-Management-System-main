import { Application } from "@hotwired/stimulus"
import DashboardRealtimeController from "controllers/dashboard_realtime_controller"

describe("DashboardRealtimeController", () => {
  let application
  let controller
  
  beforeEach(() => {
    document.body.innerHTML = `
      <div data-controller="dashboard-realtime" 
           data-dashboard-realtime-refresh-interval-value="30000">
        <div data-dashboard-realtime-target="connectionStatus" class="text-green-500">
          <span data-dashboard-realtime-target="connectionIcon">●</span>
          <span>실시간 연결됨</span>
        </div>
        <span data-dashboard-realtime-target="lastUpdate">12:00:00</span>
        <input type="checkbox" 
               data-dashboard-realtime-target="autoRefresh"
               data-action="change->dashboard-realtime#toggleAutoRefresh"
               checked>
        <div data-stat="pending_approvals">5</div>
        <div data-stat="month_total">1000000</div>
      </div>
    `
    
    application = Application.start()
    application.register("dashboard-realtime", DashboardRealtimeController)
    
    controller = application.controllers[0]
  })
  
  afterEach(() => {
    application.stop()
  })
  
  test("컨트롤러가 정상적으로 연결된다", () => {
    expect(controller).toBeDefined()
    expect(controller.connectionStatusTarget).toBeDefined()
  })
  
  test("연결 상태가 올바르게 업데이트된다", () => {
    controller.updateConnectionStatus('connected')
    expect(controller.connectionStatusTarget.className).toContain('text-green-500')
    expect(controller.connectionIconTarget.textContent).toBe('●')
    
    controller.updateConnectionStatus('disconnected')
    expect(controller.connectionStatusTarget.className).toContain('text-red-500')
    expect(controller.connectionIconTarget.textContent).toBe('○')
    
    controller.updateConnectionStatus('connecting')
    expect(controller.connectionStatusTarget.className).toContain('text-yellow-500')
    expect(controller.connectionIconTarget.className).toContain('animate-spin')
  })
  
  test("통계 업데이트가 애니메이션과 함께 적용된다", () => {
    const pendingElement = document.querySelector('[data-stat="pending_approvals"]')
    const originalValue = pendingElement.textContent
    
    controller.updateStats({
      pending_approvals: 10,
      month_total: 2000000
    })
    
    expect(pendingElement.textContent).toBe('10')
    expect(pendingElement.className).toContain('text-yellow-600')
    
    // 애니메이션이 끝나면 클래스가 제거됨
    setTimeout(() => {
      expect(pendingElement.className).not.toContain('text-yellow-600')
    }, 2100)
  })
  
  test("자동 새로고침 토글이 작동한다", () => {
    const checkbox = controller.autoRefreshTarget
    
    // 초기 상태: 체크됨
    expect(checkbox.checked).toBe(true)
    expect(controller.refreshTimer).toBeDefined()
    
    // 체크 해제
    checkbox.checked = false
    controller.toggleAutoRefresh()
    expect(controller.refreshTimer).toBeNull()
    
    // 다시 체크
    checkbox.checked = true
    controller.toggleAutoRefresh()
    expect(controller.refreshTimer).toBeDefined()
  })
  
  test("업데이트 큐가 스로틀링된다", (done) => {
    controller.throttleDelayValue = 100
    
    // 여러 업데이트를 빠르게 추가
    controller.queueUpdate({ action: 'update_stats', stats: { pending_approvals: 1 } })
    controller.queueUpdate({ action: 'update_stats', stats: { pending_approvals: 2 } })
    controller.queueUpdate({ action: 'update_stats', stats: { pending_approvals: 3 } })
    
    expect(controller.updateQueue.length).toBe(3)
    
    // 첫 번째 업데이트 후 큐가 비어있어야 함
    setTimeout(() => {
      expect(controller.updateQueue.length).toBe(0)
      done()
    }, 150)
  })
  
  test("알림이 표시되고 자동으로 사라진다", (done) => {
    controller.showNotification('테스트 메시지', 'success')
    
    setTimeout(() => {
      const notification = document.querySelector('.bg-green-500')
      expect(notification).toBeDefined()
      expect(notification.textContent).toBe('테스트 메시지')
    }, 50)
    
    setTimeout(() => {
      const notification = document.querySelector('.bg-green-500')
      expect(notification).toBeNull()
      done()
    }, 3500)
  })
})