import { Application } from "@hotwired/stimulus"
import OrganizationChartController from "../../app/javascript/controllers/organization_chart_controller"

describe("OrganizationChartController", () => {
  let application
  let controller
  
  beforeEach(() => {
    document.body.innerHTML = `
      <div data-controller="organization-chart"
           data-organization-chart-data-value='[
             {"id": 1, "name": "개발팀", "amount": 5000000, "percentage": 45},
             {"id": 2, "name": "영업팀", "amount": 3000000, "percentage": 30},
             {"id": 3, "name": "인사팀", "amount": 2000000, "percentage": 20},
             {"id": 4, "name": "기타", "amount": 500000, "percentage": 5}
           ]'
           data-organization-chart-max-items-value="3">
        <canvas data-organization-chart-target="canvas" width="400" height="200"></canvas>
      </div>
    `
    
    application = Application.start()
    application.register("organization-chart", OrganizationChartController)
  })
  
  afterEach(() => {
    application.stop()
    document.body.innerHTML = ""
  })
  
  test("컨트롤러가 연결되면 차트가 생성됨", async () => {
    await nextFrame()
    
    const element = document.querySelector('[data-controller="organization-chart"]')
    controller = application.getControllerForElementAndIdentifier(element, "organization-chart")
    
    expect(controller.chart).toBeDefined()
    expect(controller.chart.config.type).toBe("bar")
  })
  
  test("상위 N개 항목만 표시하고 나머지는 기타로 그룹화", async () => {
    await nextFrame()
    
    const element = document.querySelector('[data-controller="organization-chart"]')
    controller = application.getControllerForElementAndIdentifier(element, "organization-chart")
    
    const chartData = controller.chart.data.labels
    expect(chartData.length).toBe(4) // 상위 3개 + 기타 1개
    expect(chartData[3]).toBe("기타 (1개)")
  })
  
  test("차트 클릭 이벤트 처리", async () => {
    await nextFrame()
    
    const element = document.querySelector('[data-controller="organization-chart"]')
    controller = application.getControllerForElementAndIdentifier(element, "organization-chart")
    
    // 클릭 이벤트 시뮬레이션
    const mockEvent = { native: true }
    const mockElements = [{ index: 0 }]
    
    const consoleSpy = jest.spyOn(console, 'log')
    controller.chart.options.onClick(mockEvent, mockElements)
    
    expect(consoleSpy).toHaveBeenCalledWith('Clicked:', expect.objectContaining({
      name: "개발팀"
    }))
  })
  
  test("데이터 업데이트 메서드", async () => {
    await nextFrame()
    
    const element = document.querySelector('[data-controller="organization-chart"]')
    controller = application.getControllerForElementAndIdentifier(element, "organization-chart")
    
    const newData = [
      {"id": 5, "name": "신규팀", "amount": 1000000, "percentage": 100}
    ]
    
    controller.updateData(newData)
    
    expect(controller.chart.data.labels[0]).toBe("신규팀")
  })
})

// 다음 프레임까지 대기하는 헬퍼 함수
function nextFrame() {
  return new Promise(resolve => {
    requestAnimationFrame(resolve)
  })
}