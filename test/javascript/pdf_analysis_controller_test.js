import { Application } from "@hotwired/stimulus"
import PdfAnalysisController from "../../app/javascript/controllers/pdf_analysis_controller"

describe("PdfAnalysisController", () => {
  let application
  
  beforeEach(() => {
    document.body.innerHTML = `
      <div data-controller="pdf-analysis">
        <button data-action="click->pdf-analysis#toggleAll">
          <span data-pdf-analysis-target="toggleText">모두 펼치기</span>
        </button>
        
        <div data-pdf-analysis-target="resultItem">
          <div data-action="click->pdf-analysis#toggle" data-index="0">
            <svg data-pdf-analysis-target="chevron" class="transform"></svg>
          </div>
          <div data-pdf-analysis-target="details" class="hidden">
            상세 내용 1
          </div>
        </div>
        
        <div data-pdf-analysis-target="resultItem">
          <div data-action="click->pdf-analysis#toggle" data-index="1">
            <svg data-pdf-analysis-target="chevron" class="transform"></svg>
          </div>
          <div data-pdf-analysis-target="details" class="hidden">
            상세 내용 2
          </div>
        </div>
      </div>
    `
    
    application = Application.start()
    application.register("pdf-analysis", PdfAnalysisController)
  })
  
  afterEach(() => {
    application.stop()
  })
  
  test("개별 항목 토글", async () => {
    const controller = application.controllers[0]
    const firstToggle = document.querySelector('[data-index="0"]')
    const firstDetails = controller.resultItemTargets[0].querySelector('[data-pdf-analysis-target="details"]')
    const firstChevron = controller.resultItemTargets[0].querySelector('[data-pdf-analysis-target="chevron"]')
    
    // 초기 상태는 접혀있음
    expect(firstDetails.classList.contains('hidden')).toBe(true)
    expect(firstChevron.classList.contains('rotate-90')).toBe(false)
    
    // 클릭하면 펼쳐짐
    firstToggle.click()
    expect(firstDetails.classList.contains('hidden')).toBe(false)
    expect(firstChevron.classList.contains('rotate-90')).toBe(true)
    
    // 다시 클릭하면 접힘
    firstToggle.click()
    expect(firstDetails.classList.contains('hidden')).toBe(true)
    expect(firstChevron.classList.contains('rotate-90')).toBe(false)
  })
  
  test("모두 펼치기/접기", async () => {
    const controller = application.controllers[0]
    const toggleAllButton = document.querySelector('[data-action="click->pdf-analysis#toggleAll"]')
    const toggleText = controller.toggleTextTarget
    const allDetails = controller.element.querySelectorAll('[data-pdf-analysis-target="details"]')
    const allChevrons = controller.element.querySelectorAll('[data-pdf-analysis-target="chevron"]')
    
    // 초기 상태는 모두 접혀있음
    allDetails.forEach(detail => {
      expect(detail.classList.contains('hidden')).toBe(true)
    })
    expect(toggleText.textContent).toBe('모두 펼치기')
    
    // 모두 펼치기
    toggleAllButton.click()
    allDetails.forEach(detail => {
      expect(detail.classList.contains('hidden')).toBe(false)
    })
    allChevrons.forEach(chevron => {
      expect(chevron.classList.contains('rotate-90')).toBe(true)
    })
    expect(toggleText.textContent).toBe('모두 접기')
    
    // 모두 접기
    toggleAllButton.click()
    allDetails.forEach(detail => {
      expect(detail.classList.contains('hidden')).toBe(true)
    })
    allChevrons.forEach(chevron => {
      expect(chevron.classList.contains('rotate-90')).toBe(false)
    })
    expect(toggleText.textContent).toBe('모두 펼치기')
  })
  
  test("expanded 상태 추적", async () => {
    const controller = application.controllers[0]
    const toggleAllButton = document.querySelector('[data-action="click->pdf-analysis#toggleAll"]')
    
    expect(controller.expanded).toBe(false)
    
    toggleAllButton.click()
    expect(controller.expanded).toBe(true)
    
    toggleAllButton.click()
    expect(controller.expanded).toBe(false)
  })
})