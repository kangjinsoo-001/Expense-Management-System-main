import { Controller } from "@hotwired/stimulus"

// Chart.js는 UMD 형태로 vendor에서 로드
let Chart

export default class extends Controller {
  static targets = [ "orgButton", "expandIcon", "detailsContainer", "individualDetails", "codeChart", "orgChart", "pageTitle" ]
  static values = { expenseData: Object }
  
  async connect() {
    console.log("Organization chart controller connected")
    
    // 조직별 펼침/접힘 상태 저장
    this.expandedNodes = new Map()
    
    // Chart.js를 동적으로 로드
    await this.loadChartJS()
    
    // 데이터 값 변경 감지를 위한 초기화
    this.expenseDataValueChanged()
    
    // sessionStorage에서 저장된 펼침/접힘 상태 복원
    const savedExpandedState = sessionStorage.getItem('orgTreeExpandedState')
    if (savedExpandedState) {
      try {
        const savedState = JSON.parse(savedExpandedState)
        this.restoreTreeState(savedState)
      } catch (e) {
        console.error("Failed to restore tree state:", e)
        this.initializeTreeState()
      }
    } else {
      // 트리 초기 상태 설정 (모두 접기 상태에서 루트 직속만 펼치기)
      this.initializeTreeState()
    }
    
    // sessionStorage에서 이전 선택 조직 확인 (URL 파라미터보다 우선)
    const savedOrgId = sessionStorage.getItem('selectedOrgId')
    const urlParams = new URLSearchParams(window.location.search)
    const urlOrgId = urlParams.get('org_id')
    
    // sessionStorage가 없을 때만 URL 파라미터 사용
    const targetOrgId = savedOrgId || urlOrgId
    
    if (targetOrgId) {
      // 조직 선택 복원
      const targetButton = this.orgButtonTargets.find(btn => btn.dataset.orgId === targetOrgId)
      if (targetButton) {
        this.selectOrganizationButton(targetButton)
        this.selectedOrgId = targetOrgId
        sessionStorage.setItem('selectedOrgId', targetOrgId)
        this.updatePageTitle(targetButton)
        this.loadOrganizationDetails(targetOrgId)
        
        // 선택된 조직이 보이도록 부모 조직들을 펼침
        this.expandToShowOrganization(targetOrgId)
        return
      }
    }
    
    // 저장된 선택이 없으면 루트 조직을 기본 선택
    const rootButton = this.orgButtonTargets.find(btn => btn.classList.contains("bg-blue-600"))
    if (rootButton) {
      console.log("Root button found, loading org:", rootButton.dataset.orgId)
      this.selectedOrgId = rootButton.dataset.orgId
      this.updatePageTitle(rootButton)
      this.loadOrganizationDetails(rootButton.dataset.orgId)
    } else {
      this.selectedOrgId = "all"
      this.initializeCharts()
    }
  }
  
  // Stimulus 값 변경 콜백
  expenseDataValueChanged() {
    console.log("Expense data changed:", this.expenseDataValue)
    // window 객체에도 저장 (호환성 유지)
    window.organizationExpenseData = this.expenseDataValue
    
    // 차트가 이미 초기화되었다면 다시 렌더링
    if (this.codeChart || this.orgChart) {
      this.initializeCharts()
    }
  }
  
  async loadChartJS() {
    if (window.Chart) {
      Chart = window.Chart
      return
    }
    
    return new Promise((resolve) => {
      const script = document.createElement('script')
      script.src = '/javascripts/chart.umd.js'
      script.onload = () => {
        Chart = window.Chart
        console.log("Chart.js loaded successfully")
        resolve()
      }
      script.onerror = () => {
        console.error("Failed to load Chart.js")
        resolve()
      }
      document.head.appendChild(script)
    })
  }
  
  initializeTreeState() {
    // 모든 조직 노드를 찾아서 초기 상태 설정
    const allChildrenDivs = document.querySelectorAll('.org-children')
    
    allChildrenDivs.forEach(div => {
      const level = parseInt(div.dataset.orgLevel || '0')
      const parentOrgId = div.dataset.parentOrgId
      
      if (level === 0) {
        // 루트(레벨 0)의 직속 하위만 표시
        div.style.display = "block"
        this.expandedNodes.set(parentOrgId, true)
        
        // 해당 화살표를 아래로
        const button = document.querySelector(`button[data-org-id="${parentOrgId}"]`)
        if (button) {
          const icon = button.querySelector('svg')
          if (icon) {
            icon.classList.remove("rotate-0")
            icon.classList.add("rotate-90")
          }
        }
      } else {
        // 레벨 1 이상은 모두 숨김
        div.style.display = "none"
        this.expandedNodes.set(parentOrgId, false)
        
        // 해당 화살표를 오른쪽으로
        const button = document.querySelector(`button[data-org-id="${parentOrgId}"]`)
        if (button) {
          const icon = button.querySelector('svg')
          if (icon) {
            icon.classList.remove("rotate-90")
            icon.classList.add("rotate-0")
          }
        }
      }
    })
  }
  
  selectOrganization(event) {
    event.preventDefault()
    event.stopPropagation()
    
    const button = event.currentTarget
    const orgId = button.dataset.orgId
    
    this.selectOrganizationButton(button)
    this.selectedOrgId = orgId
    
    // 선택 조직 저장
    sessionStorage.setItem('selectedOrgId', orgId)
    
    // 페이지 타이틀 업데이트
    this.updatePageTitle(button)
    
    // 개별 조직 상세 로드
    this.loadOrganizationDetails(orgId)
  }
  
  selectOrganizationButton(button) {
    // 모든 버튼의 선택 상태 해제
    this.orgButtonTargets.forEach(btn => {
      btn.classList.remove("bg-blue-600", "text-white")
      btn.classList.add("hover:bg-gray-100")
      
      // 텍스트와 아이콘 색상 복원
      const textSpan = btn.querySelector('span.text-sm')
      const icon = btn.querySelector('svg')
      
      if (textSpan) {
        textSpan.classList.remove("text-white")
        textSpan.classList.add("text-gray-900")
      }
      
      if (icon) {
        icon.classList.remove("text-white")
        icon.classList.add("text-gray-400")
      }
    })
    
    // 선택된 버튼 강조
    button.classList.add("bg-blue-600", "text-white")
    button.classList.remove("hover:bg-gray-100")
    
    // 선택된 버튼의 텍스트와 아이콘 색상 변경
    const selectedTextSpan = button.querySelector('span.text-sm')
    const selectedIcon = button.querySelector('svg')
    
    if (selectedTextSpan) {
      selectedTextSpan.classList.remove("text-gray-900")
      selectedTextSpan.classList.add("text-white")
    }
    
    if (selectedIcon) {
      selectedIcon.classList.remove("text-gray-400")
      selectedIcon.classList.add("text-white")
    }
  }
  
  toggleExpand(event) {
    event.preventDefault()
    event.stopPropagation()
    
    const button = event.currentTarget
    const orgId = button.dataset.orgId
    const icon = button.querySelector("svg")
    const childrenDiv = document.querySelector(`[data-parent-org-id="${orgId}"]`)
    
    if (childrenDiv) {
      // Map에서 현재 상태 확인 (없으면 false로 간주)
      const isExpanded = this.expandedNodes.get(orgId) || false
      
      if (isExpanded) {
        // 접기: 숨기고 화살표를 오른쪽으로
        childrenDiv.style.display = "none"
        icon.classList.remove("rotate-90")
        icon.classList.add("rotate-0")
        this.expandedNodes.set(orgId, false)
      } else {
        // 펼치기: 보이고 화살표를 아래로
        childrenDiv.style.display = "block"
        icon.classList.remove("rotate-0")
        icon.classList.add("rotate-90")
        this.expandedNodes.set(orgId, true)
      }
      
      // 상태를 sessionStorage에 저장
      this.saveTreeState()
    }
  }
  
  expandAll(event) {
    event.preventDefault()
    
    // 모든 하위 조직 div 펼치기
    const allChildrenDivs = document.querySelectorAll('.org-children')
    allChildrenDivs.forEach(div => {
      div.style.display = "block"
      const parentOrgId = div.dataset.parentOrgId
      if (parentOrgId) {
        this.expandedNodes.set(parentOrgId, true)
      }
    })
    
    // 모든 화살표 아이콘을 아래로
    const allIcons = document.querySelectorAll('[data-organization-chart-target="expandIcon"]')
    allIcons.forEach(icon => {
      icon.classList.remove("rotate-0")
      icon.classList.add("rotate-90")
    })
    
    // 상태 저장
    this.saveTreeState()
  }
  
  collapseAll(event) {
    event.preventDefault()
    
    // 모든 조직의 상태를 초기화
    this.expandedNodes.clear()
    
    // 모든 하위 조직 div 처리
    const allChildrenDivs = document.querySelectorAll('.org-children')
    allChildrenDivs.forEach(div => {
      const level = parseInt(div.dataset.orgLevel || '0')
      const parentOrgId = div.dataset.parentOrgId
      
      if (level === 0) {
        // 루트의 직속 하위만 표시
        div.style.display = "block"
        this.expandedNodes.set(parentOrgId, true)
      } else {
        // 나머지는 모두 숨김
        div.style.display = "none"
        this.expandedNodes.set(parentOrgId, false)
      }
    })
    
    // 화살표 아이콘 상태 업데이트
    document.querySelectorAll('button[data-org-id]').forEach(button => {
      const orgId = button.dataset.orgId
      const icon = button.querySelector('svg')
      if (icon) {
        const isExpanded = this.expandedNodes.get(orgId) || false
        if (isExpanded) {
          icon.classList.remove("rotate-0")
          icon.classList.add("rotate-90")
        } else {
          icon.classList.remove("rotate-90")
          icon.classList.add("rotate-0")
        }
      }
    })
    
    // 상태 저장
    this.saveTreeState()
  }
  
  // 트리 상태를 sessionStorage에 저장
  saveTreeState() {
    const state = Array.from(this.expandedNodes.entries())
    sessionStorage.setItem('orgTreeExpandedState', JSON.stringify(state))
  }
  
  // 저장된 트리 상태 복원
  restoreTreeState(savedState) {
    // Map 복원
    this.expandedNodes = new Map(savedState)
    
    // DOM에 상태 적용
    this.expandedNodes.forEach((isExpanded, orgId) => {
      const childrenDiv = document.querySelector(`[data-parent-org-id="${orgId}"]`)
      const button = document.querySelector(`button[data-org-id="${orgId}"]`)
      
      if (childrenDiv && button) {
        const icon = button.querySelector('svg')
        
        if (isExpanded) {
          childrenDiv.style.display = "block"
          if (icon) {
            icon.classList.remove("rotate-0")
            icon.classList.add("rotate-90")
          }
        } else {
          childrenDiv.style.display = "none"
          if (icon) {
            icon.classList.remove("rotate-90")
            icon.classList.add("rotate-0")
          }
        }
      }
    })
  }
  
  // 선택된 조직이 보이도록 부모 조직들을 펼침
  expandToShowOrganization(orgId) {
    const button = document.querySelector(`button[data-org-id="${orgId}"]`)
    if (!button) return
    
    // 부모 조직들을 찾아서 펼침
    let currentNode = button.closest('.org-tree-node')
    while (currentNode) {
      const parentDiv = currentNode.closest('.org-children')
      if (parentDiv) {
        const parentOrgId = parentDiv.dataset.parentOrgId
        if (parentOrgId && !this.expandedNodes.get(parentOrgId)) {
          // 부모 조직 펼치기
          const parentButton = document.querySelector(`button[data-org-id="${parentOrgId}"]`)
          if (parentButton) {
            const icon = parentButton.querySelector('svg')
            parentDiv.style.display = "block"
            if (icon) {
              icon.classList.remove("rotate-0")
              icon.classList.add("rotate-90")
            }
            this.expandedNodes.set(parentOrgId, true)
          }
        }
        currentNode = parentDiv.parentElement
      } else {
        break
      }
    }
    
    // 상태 저장
    this.saveTreeState()
  }
  
  updatePageTitle(button) {
    if (!this.hasPageTitleTarget) return
    
    // 조직명 가져오기
    const orgName = button.querySelector('span.text-sm')?.textContent?.trim() || ''
    const year = this.expenseDataValue?.year || new Date().getFullYear()
    const month = this.expenseDataValue?.month || new Date().getMonth() + 1
    
    // 현재 URL에서 view_mode 파라미터 가져오기
    const urlParams = new URLSearchParams(window.location.search)
    const viewMode = urlParams.get('view_mode') || 'monthly'
    
    // view_mode에 따라 타이틀 업데이트
    if (viewMode === 'yearly') {
      // 연도별 모드
      if (orgName) {
        this.pageTitleTarget.textContent = `${year}년 ${orgName}`
      } else {
        this.pageTitleTarget.textContent = `${year}년 경비 통계`
      }
    } else if (viewMode === 'trend') {
      // 추이 모드 - 날짜 범위 표시
      const endDate = new Date(year, month - 1, 1)
      const startDate = new Date(endDate.getFullYear(), endDate.getMonth() - 11, 1)
      const startYear = startDate.getFullYear()
      const startMonth = startDate.getMonth() + 1
      const endYear = endDate.getFullYear()
      const endMonth = endDate.getMonth() + 1
      
      if (orgName) {
        this.pageTitleTarget.textContent = `${startYear}년 ${startMonth}월 ~ ${endYear}년 ${endMonth}월 ${orgName} 추이`
      } else {
        this.pageTitleTarget.textContent = `${startYear}년 ${startMonth}월 ~ ${endYear}년 ${endMonth}월 추이`
      }
    } else {
      // 월별 모드
      if (orgName) {
        this.pageTitleTarget.textContent = `${year}년 ${month}월 ${orgName}`
      } else {
        this.pageTitleTarget.textContent = `${year}년 ${month}월 경비 통계`
      }
    }
  }
  
  async loadOrganizationDetails(orgId) {
    const year = this.expenseDataValue?.year || window.organizationExpenseData?.year || new Date().getFullYear()
    const month = this.expenseDataValue?.month || window.organizationExpenseData?.month || new Date().getMonth() + 1
    
    // 현재 URL에서 view_mode 파라미터 가져오기
    const urlParams = new URLSearchParams(window.location.search)
    const viewMode = urlParams.get('view_mode') || 'monthly'
    
    // 로딩 인디케이터 표시
    const allDetails = document.getElementById("org-details-all")
    if (allDetails) allDetails.classList.add("hidden")
    this.individualDetailsTarget.classList.remove("hidden")
    this.individualDetailsTarget.innerHTML = `
      <div class="flex items-center justify-center py-12">
        <div class="text-center">
          <svg class="animate-spin h-8 w-8 text-blue-600 mx-auto mb-3" xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24">
            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
          </svg>
          <p class="text-gray-600">조직 데이터를 불러오는 중...</p>
        </div>
      </div>
    `
    
    try {
      // view_mode에 따라 파라미터 구성
      let queryParams = `view_mode=${viewMode}&year=${year}`
      if (viewMode === 'monthly' || viewMode === 'trend') {
        queryParams += `&month=${month}`
      }
      
      const response = await fetch(`/organization_expenses/${orgId}?${queryParams}`, {
        headers: {
          'Accept': 'text/html',
          'X-Requested-With': 'XMLHttpRequest'
        }
      })
      
      if (response.ok) {
        const html = await response.text()
        this.individualDetailsTarget.innerHTML = html
        
        // 데이터를 가진 요소 찾기
        const dataElement = this.individualDetailsTarget.querySelector('[data-org-expenses]')
        let detailsData = {}
        
        if (dataElement && dataElement.dataset.orgExpenses) {
          try {
            detailsData = JSON.parse(dataElement.dataset.orgExpenses)
          } catch (e) {
            console.error("Failed to parse org expenses data:", e)
          }
        }
        
        console.log("Rendering charts with data:", detailsData)
        
        // data-render-charts 속성 확인 후 차트 렌더링
        if (dataElement && dataElement.dataset.renderCharts === 'true') {
          // Chart.js 로드 대기 후 렌더링
          if (Chart) {
            this.renderCharts(detailsData)
          } else {
            // Chart.js가 아직 로드되지 않은 경우 대기
            setTimeout(() => {
              if (window.Chart) {
                Chart = window.Chart
                this.renderCharts(detailsData)
              }
            }, 500)
          }
        }
      } else if (response.status === 403) {
        this.individualDetailsTarget.innerHTML = `
          <div class="bg-red-50 border border-red-200 rounded-lg p-4 text-red-700">
            <p class="font-semibold">권한이 없습니다</p>
            <p class="text-sm mt-1">해당 조직의 데이터를 볼 수 있는 권한이 없습니다.</p>
          </div>
        `
      } else {
        this.individualDetailsTarget.innerHTML = `
          <div class="bg-yellow-50 border border-yellow-200 rounded-lg p-4 text-yellow-700">
            <p class="font-semibold">데이터 로드 실패</p>
            <p class="text-sm mt-1">조직 데이터를 불러올 수 없습니다. 잠시 후 다시 시도해주세요.</p>
          </div>
        `
      }
    } catch (error) {
      console.error("Error loading organization details:", error)
      this.individualDetailsTarget.innerHTML = `
        <div class="bg-red-50 border border-red-200 rounded-lg p-4 text-red-700">
          <p class="font-semibold">오류 발생</p>
          <p class="text-sm mt-1">네트워크 오류가 발생했습니다. 잠시 후 다시 시도해주세요.</p>
        </div>
      `
    }
  }
  
  initializeCharts() {
    const data = this.expenseDataValue || window.organizationExpenseData
    if (data && Chart) {
      this.renderCharts(data)
    }
  }
  
  renderCharts(data) {
    console.log("renderCharts called with:", data)
    console.log("Chart available:", !!Chart)
    
    if (!data || !Chart) {
      console.error("Cannot render charts - data or Chart.js missing")
      return
    }
    
    // 추이 모드인 경우
    if (data.viewMode === 'trend' && data.trendData) {
      const trendCanvas = document.getElementById('org-trend-chart')
      if (trendCanvas && data.trendData.months) {
        console.log("Rendering trend chart with data:", data.trendData)
        const trendCtx = trendCanvas.getContext('2d')
        this.renderTrendChart(data.trendData, trendCtx)
      }
      return
    }
    
    // 기존 차트 렌더링
    const codeCanvas = document.getElementById('org-code-chart')
    const orgCanvas = document.getElementById('org-children-chart')
    
    console.log("Code canvas found:", !!codeCanvas)
    console.log("Org canvas found:", !!orgCanvas)
    
    // 경비 코드별 차트
    if (codeCanvas && data.totalByCode) {
      console.log("Rendering code chart with data:", data.totalByCode)
      const codeCtx = codeCanvas.getContext('2d')
      this.renderCodeChart(data.totalByCode, codeCtx)
    }
    
    // 조직별 차트  
    if (orgCanvas && data.organizationExpenses) {
      console.log("Rendering org chart with data:", data.organizationExpenses)
      const orgCtx = orgCanvas.getContext('2d')
      this.renderOrgChart(data.organizationExpenses, orgCtx)
    }
  }
  
  renderCodeChart(totalByCode, ctx = null) {
    if (!ctx) {
      ctx = this.codeChartTarget.getContext('2d')
    }
    
    // 기존 차트 제거
    if (this.codeChart) {
      this.codeChart.destroy()
    }
    
    // 데이터가 없으면 리턴
    if (!totalByCode || (Array.isArray(totalByCode) && totalByCode.length === 0)) {
      return
    }
    
    // 데이터 준비 (상위 10개만)
    const sortedData = Array.isArray(totalByCode) 
      ? totalByCode.filter(item => item && item[1] > 0).sort((a, b) => b[1] - a[1]).slice(0, 10)
      : Object.entries(totalByCode).filter(([_, amount]) => amount > 0).sort((a, b) => b[1] - a[1]).slice(0, 10)
    
    if (sortedData.length === 0) return
    
    // 전체 합계 계산
    const total = sortedData.reduce((sum, item) => sum + Number(item[1]), 0)
    
    // 라벨과 데이터 준비
    const labels = sortedData.map(item => {
      if (Array.isArray(item[0])) {
        const [code, name] = item[0]
        return `${code} ${name}`
      } else {
        return item[0]
      }
    })
    
    const values = sortedData.map(item => Number(item[1]))
    
    // D3.js의 Category10 색상 팔레트를 참고한 구분이 명확한 색상
    const backgroundColors = [
      'rgba(31, 119, 180, 0.85)',   // 파랑
      'rgba(255, 127, 14, 0.85)',   // 주황
      'rgba(44, 160, 44, 0.85)',    // 초록
      'rgba(214, 39, 40, 0.85)',    // 빨강
      'rgba(148, 103, 189, 0.85)',  // 보라
      'rgba(140, 86, 75, 0.85)',    // 갈색
      'rgba(227, 119, 194, 0.85)',  // 분홍
      'rgba(127, 127, 127, 0.85)',  // 회색
      'rgba(188, 189, 34, 0.85)',   // 올리브
      'rgba(23, 190, 207, 0.85)',   // 청록
    ]
    
    const borderColors = backgroundColors.map(color => color.replace('0.85', '1'))
    
    // 차트 생성 (도넛 차트)
    const self = this
    
    // 마우스 호버 상태 추적 (차트 인스턴스에 저장)
    if (!this._chartState) {
      this._chartState = {
        hoveredLabelIndex: -1,
        labelBounds: [],
        mouseOverTime: 0
      }
    }
    
    const chartState = this._chartState
    
    // Canvas 요소에 마우스 이벤트 추가 (기존 리스너 제거 후 추가)
    const canvas = ctx.canvas
    
    // 기존 이벤트 리스너 제거를 위한 핸들러 함수
    if (canvas._mouseMoveHandler) {
      canvas.removeEventListener('mousemove', canvas._mouseMoveHandler)
    }
    
    canvas._mouseMoveHandler = (event) => {
      const rect = canvas.getBoundingClientRect()
      const x = event.clientX - rect.left
      const y = event.clientY - rect.top
      
      // 외부 라벨 영역 체크 - 호버된 라벨부터 확인
      let foundLabel = false
      let candidateIndex = -1
      
      // 디버깅: 마우스 위치와 라벨 영역 확인
      // console.log('Mouse position:', x, y)
      // console.log('Label bounds:', labelBounds)
      
      // 현재 호버된 라벨이 있으면 그것부터 확인
      if (chartState.hoveredLabelIndex !== -1) {
        for (let i = 0; i < chartState.labelBounds.length; i++) {
          const bounds = chartState.labelBounds[i]
          if (bounds.index === chartState.hoveredLabelIndex &&
              x >= bounds.x && x <= bounds.x + bounds.width &&
              y >= bounds.y && y <= bounds.y + bounds.height) {
            // 여전히 같은 라벨 위에 있음
            foundLabel = true
            canvas.style.cursor = 'pointer'
            break
          }
        }
      }
      
      // 현재 호버된 라벨 위에 없으면 다른 라벨 체크
      if (!foundLabel) {
        // 맨 위에 있는(마지막에 그려진) 라벨부터 역순으로 체크
        for (let i = chartState.labelBounds.length - 1; i >= 0; i--) {
          const bounds = chartState.labelBounds[i]
          if (x >= bounds.x && x <= bounds.x + bounds.width &&
              y >= bounds.y && y <= bounds.y + bounds.height) {
            candidateIndex = bounds.index
            foundLabel = true
            canvas.style.cursor = 'pointer'
            break
          }
        }
        
        if (foundLabel && candidateIndex !== chartState.hoveredLabelIndex) {
          // 새로운 라벨로 호버 변경 (약간의 지연을 주어 안정화)
          const now = Date.now()
          if (now - chartState.mouseOverTime > 50) { // 50ms 지연
            chartState.hoveredLabelIndex = candidateIndex
            chartState.mouseOverTime = now
            self.codeChart.render()
          }
        }
      }
      
      if (!foundLabel && chartState.hoveredLabelIndex !== -1) {
        // 도넛 섹션 호버가 아니면 리셋
        const activeElements = self.codeChart.getElementsAtEventForMode(event, 'nearest', { intersect: true }, false)
        if (activeElements.length === 0) {
          chartState.hoveredLabelIndex = -1
          self.codeChart.render()
          canvas.style.cursor = 'default'
        }
      }
    }
    
    // 이벤트 리스너 등록
    canvas.addEventListener('mousemove', canvas._mouseMoveHandler)
    
    this.codeChart = new Chart(ctx, {
      type: 'doughnut',
      data: {
        labels: labels,
        datasets: [{
          label: '경비',
          data: values,
          backgroundColor: backgroundColors,
          borderColor: borderColors,
          borderWidth: 2
        }]
      },
      plugins: [{
        id: 'doughnutLabel',
        afterDatasetsDraw: function(chart) {
          const ctx = chart.ctx
          const chartArea = chart.chartArea
          const centerX = (chartArea.left + chartArea.right) / 2
          const centerY = (chartArea.top + chartArea.bottom) / 2
          
          // 외부 라벨 위치 추적
          const externalLabels = []
          const allLabels = [] // 모든 라벨 정보 저장
          chartState.labelBounds = [] // 라벨 영역 초기화
          
          chart.data.datasets.forEach((dataset, datasetIndex) => {
            const meta = chart.getDatasetMeta(datasetIndex)
            
            // 먼저 모든 라벨 정보를 수집
            meta.data.forEach((arc, index) => {
              const value = dataset.data[index]
              const percentage = (value / total) * 100
              
              const model = arc
              const midAngle = (model.startAngle + model.endAngle) / 2
              
              // 값과 퍼센트 계산
              const formattedAmount = new Intl.NumberFormat('ko-KR').format(value)
              const percentageText = percentage.toFixed(1)
              
              // 라벨 텍스트 준비
              const labelText = labels[index]
              const valueText = `₩${formattedAmount}`
              const percentText = `${percentageText}%`
              
              // 5% 미만이거나 섹션이 매우 좁은 경우 외부에 표시
              const angleSize = model.endAngle - model.startAngle
              const isNarrow = percentage < 5 || angleSize < 0.25 // 약 14.3도 미만
              
              const labelInfo = {
                index: index,
                isNarrow: isNarrow,
                model: model,
                midAngle: midAngle,
                value: value,
                percentage: percentage,
                formattedAmount: formattedAmount,
                percentageText: percentageText,
                labelText: labelText,
                valueText: valueText,
                percentText: percentText
              }
              
              allLabels.push(labelInfo)
            })
            
            // 호버되지 않은 라벨 먼저 그리기
            allLabels.forEach((labelInfo) => {
              if (labelInfo.index === chartState.hoveredLabelIndex) return // 호버된 것은 나중에
              
              const { index, isNarrow, model, midAngle, labelText, valueText, percentText } = labelInfo
              
              if (isNarrow) {
                // 외부에 라벨 표시
                const outerRadius = model.outerRadius
                const labelRadius = outerRadius + 60  // 적당한 거리에 배치
                
                let x = centerX + Math.cos(midAngle) * labelRadius
                let y = centerY + Math.sin(midAngle) * labelRadius
                
                // 이전 외부 라벨들과 충돌 체크
                externalLabels.forEach(prevLabel => {
                  const distance = Math.sqrt(Math.pow(x - prevLabel.x, 2) + Math.pow(y - prevLabel.y, 2))
                  if (distance < 35) {  // 충돌 간격을 늘림
                    // 충돌 시 위치 조정
                    const adjustment = 35 - distance
                    if (y > centerY) {
                      y += adjustment
                    } else {
                      y -= adjustment
                    }
                    // x 방향으로도 약간 조정
                    if (x > centerX) {
                      x += adjustment * 0.3
                    } else {
                      x -= adjustment * 0.3
                    }
                  }
                })
                
                externalLabels.push({ x, y })
                
                // 선 그리기
                const innerX = centerX + Math.cos(midAngle) * outerRadius
                const innerY = centerY + Math.sin(midAngle) * outerRadius
                const midX = centerX + Math.cos(midAngle) * (outerRadius + 30)
                const midY = centerY + Math.sin(midAngle) * (outerRadius + 30)
                
                ctx.save()
                ctx.beginPath()
                ctx.moveTo(innerX, innerY)
                ctx.lineTo(midX, midY)
                ctx.lineTo(x, y)
                ctx.strokeStyle = '#9ca3af'
                ctx.lineWidth = 1
                ctx.stroke()
                
                // 점 그리기
                ctx.beginPath()
                ctx.arc(x, y, 2, 0, 2 * Math.PI)
                ctx.fillStyle = '#6b7280'
                ctx.fill()
                
                // 호버된 라벨은 건너뛰고 나중에 그리기
                const isHovered = index === chartState.hoveredLabelIndex
                if (isHovered) {
                  externalLabels.push({ x, y, index })
                  return
                }
                
                // 두 줄로 텍스트 준비
                const line1 = labelText
                const line2 = `${valueText} (${percentText})`
                
                // 배경 박스 (두 줄용)
                const padding = 6
                ctx.font = 'bold 12px sans-serif'
                const line1Width = ctx.measureText(line1).width
                const line2Width = ctx.measureText(line2).width
                const textWidth = Math.max(line1Width, line2Width)
                
                const textAlign = x > centerX ? 'left' : 'right'
                const boxX = textAlign === 'left' ? x + 5 : x - textWidth - padding * 2 - 5
                const boxHeight = 36 // 두 줄을 위한 높이
                const boxY = y - boxHeight / 2
                
                // 라벨 영역 저장 (마우스 이벤트용) - 호버되지 않은 라벨만
                if (index !== chartState.hoveredLabelIndex) {
                  chartState.labelBounds.push({
                    index: index,
                    x: boxX - padding,
                    y: boxY,
                    width: textWidth + padding * 2,
                    height: boxHeight
                  })
                }
                
                // 배경 그리기
                ctx.fillStyle = 'rgba(255, 255, 255, 0.98)'
                ctx.strokeStyle = '#d1d5db'
                ctx.lineWidth = 1
                ctx.fillRect(boxX - padding, boxY, textWidth + padding * 2, boxHeight)
                ctx.strokeRect(boxX - padding, boxY, textWidth + padding * 2, boxHeight)
                
                // 텍스트 그리기 (두 줄로)
                ctx.fillStyle = '#1f2937'
                ctx.font = 'bold 12px sans-serif'
                ctx.textAlign = textAlign
                ctx.textBaseline = 'middle'
                
                const textX = textAlign === 'left' ? boxX : boxX + textWidth
                // 첫 번째 줄
                ctx.fillText(line1, textX, y - 8)
                // 두 번째 줄
                ctx.fillText(line2, textX, y + 8)
                
                ctx.restore()
              } else {
                // 내부에 라벨 표시 (두 줄로 변경)
                const innerRadius = model.innerRadius
                const outerRadius = model.outerRadius
                const labelRadius = (innerRadius + outerRadius) / 2
                
                const x = centerX + Math.cos(midAngle) * labelRadius
                const y = centerY + Math.sin(midAngle) * labelRadius
                
                ctx.save()
                
                // 텍스트 그리기
                ctx.fillStyle = '#ffffff'
                ctx.strokeStyle = 'rgba(0, 0, 0, 0.5)'
                ctx.lineWidth = 3
                ctx.textAlign = 'center'
                ctx.textBaseline = 'middle'
                
                // 첫 번째 줄: 코드와 설명 (흰색 텍스트에 검은 테두리)
                ctx.font = 'bold 13px sans-serif'
                ctx.strokeText(labelText, x, y - 8)
                ctx.fillText(labelText, x, y - 8)
                
                // 두 번째 줄: 금액과 퍼센트 (괄호 추가)
                const secondLine = `${valueText} (${percentText})`
                ctx.font = 'bold 12px sans-serif'
                ctx.strokeText(secondLine, x, y + 8)
                ctx.fillText(secondLine, x, y + 8)
                
                ctx.restore()
              }
            })
            
            // 호버된 외부 라벨을 마지막에 다시 그리기 (맨 위에 표시)
            const hoveredLabel = allLabels.find(l => l.index === chartState.hoveredLabelIndex && l.isNarrow)
            if (hoveredLabel) {
              const { index, isNarrow, model, midAngle, labelText, valueText, percentText } = hoveredLabel
              
              if (isNarrow) {
                // 외부에 라벨 표시 (호버 시 강조)
                const outerRadius = model.outerRadius
                const labelRadius = outerRadius + 60
                
                let x = centerX + Math.cos(midAngle) * labelRadius
                let y = centerY + Math.sin(midAngle) * labelRadius
                
                // 이전 외부 라벨들과 충돌 체크
                externalLabels.forEach(prevLabel => {
                  const distance = Math.sqrt(Math.pow(x - prevLabel.x, 2) + Math.pow(y - prevLabel.y, 2))
                  if (distance < 35) {
                    const adjustment = 35 - distance
                    if (y > centerY) {
                      y += adjustment
                    } else {
                      y -= adjustment
                    }
                    if (x > centerX) {
                      x += adjustment * 0.3
                    } else {
                      x -= adjustment * 0.3
                    }
                  }
                })
                
                // 선 그리기 (더 굵게)
                const innerX = centerX + Math.cos(midAngle) * outerRadius
                const innerY = centerY + Math.sin(midAngle) * outerRadius
                const midX = centerX + Math.cos(midAngle) * (outerRadius + 30)
                const midY = centerY + Math.sin(midAngle) * (outerRadius + 30)
                
                ctx.save()
                ctx.beginPath()
                ctx.moveTo(innerX, innerY)
                ctx.lineTo(midX, midY)
                ctx.lineTo(x, y)
                ctx.strokeStyle = '#4b5563'
                ctx.lineWidth = 2
                ctx.stroke()
                
                // 점 그리기 (더 크게)
                ctx.beginPath()
                ctx.arc(x, y, 3, 0, 2 * Math.PI)
                ctx.fillStyle = '#374151'
                ctx.fill()
                
                // 두 줄로 텍스트 준비
                const line1 = labelText
                const line2 = `${valueText} (${percentText})`
                
                // 배경 박스 (두 줄용, 그림자 추가)
                const padding = 6
                ctx.font = 'bold 12px sans-serif'
                const line1Width = ctx.measureText(line1).width
                const line2Width = ctx.measureText(line2).width
                const textWidth = Math.max(line1Width, line2Width)
                
                const textAlign = x > centerX ? 'left' : 'right'
                const boxX = textAlign === 'left' ? x + 5 : x - textWidth - padding * 2 - 5
                const boxHeight = 36 // 두 줄을 위한 높이
                const boxY = y - boxHeight / 2
                
                // 호버된 라벨의 영역은 나중에 추가 (맨 위에 그려지므로)
                
                // 배경 그리기 (그림자 추가로 강조)
                ctx.shadowColor = 'rgba(0, 0, 0, 0.3)'
                ctx.shadowBlur = 5
                ctx.shadowOffsetX = 2
                ctx.shadowOffsetY = 2
                ctx.fillStyle = 'rgba(255, 255, 255, 1)'
                ctx.strokeStyle = '#374151'
                ctx.lineWidth = 2
                ctx.fillRect(boxX - padding, boxY, textWidth + padding * 2, boxHeight)
                ctx.strokeRect(boxX - padding, boxY, textWidth + padding * 2, boxHeight)
                
                // 호버된 라벨의 영역 정보를 맨 마지막에 추가 (맨 위에 있으므로)
                chartState.labelBounds.push({
                  index: index,
                  x: boxX - padding,
                  y: boxY,
                  width: textWidth + padding * 2,
                  height: boxHeight,
                  isHovered: true
                })
                
                // 그림자 제거
                ctx.shadowColor = 'transparent'
                ctx.shadowBlur = 0
                ctx.shadowOffsetX = 0
                ctx.shadowOffsetY = 0
                
                // 텍스트 그리기 (두 줄로)
                ctx.fillStyle = '#111827'
                ctx.font = 'bold 12px sans-serif'
                ctx.textAlign = textAlign
                ctx.textBaseline = 'middle'
                
                const textX = textAlign === 'left' ? boxX : boxX + textWidth
                // 첫 번째 줄
                ctx.fillText(line1, textX, y - 8)
                // 두 번째 줄
                ctx.fillText(line2, textX, y + 8)
                
                ctx.restore()
              }
            }
          })
        }
      }],
      options: {
        responsive: true,
        maintainAspectRatio: false,
        cutout: '40%', // 도넛 가운데 구멍 크기를 작게
        layout: {
          padding: 100 // 외부 라벨을 위한 여백
        },
        plugins: {
          legend: {
            display: false // 범례 숨김
          },
          tooltip: {
            enabled: true,
            callbacks: {
              label: function(context) {
                const value = context.raw
                const formattedAmount = new Intl.NumberFormat('ko-KR').format(value)
                const percentage = ((value / total) * 100).toFixed(1)
                return `₩${formattedAmount} (${percentage}%)`
              }
            }
          }
        },
        animation: false,
        onHover: (event, activeElements) => {
          // 호버된 섹션 추적
          if (activeElements.length > 0) {
            chartState.hoveredLabelIndex = activeElements[0].index
          } else {
            // 도넛 섹션 호버가 없을 때는 외부 라벨 호버 상태 유지
            // chartState.hoveredLabelIndex = -1
          }
          // 차트 다시 그리기
          this.codeChart.render()
        }
      }
    })
  }
  
  renderTrendChart(trendData, ctx) {
    // 기존 차트 제거
    if (this.trendChart) {
      this.trendChart.destroy()
    }
    
    // 데이터가 없으면 리턴
    if (!trendData || !trendData.months || trendData.months.length === 0) {
      console.log("No trend data available")
      return
    }
    
    const { months, data, topCodes } = trendData
    console.log("Trend data:", { months, data, topCodes })
    
    // 데이터셋 준비 - 상위 10개 경비 코드별로
    const datasets = []
    const colorPalette = [
      'rgba(31, 119, 180, 0.85)',   // 파랑
      'rgba(255, 127, 14, 0.85)',   // 주황
      'rgba(44, 160, 44, 0.85)',    // 초록
      'rgba(214, 39, 40, 0.85)',    // 빨강
      'rgba(148, 103, 189, 0.85)',  // 보라
      'rgba(140, 86, 75, 0.85)',    // 갈색
      'rgba(227, 119, 194, 0.85)',  // 분홍
      'rgba(127, 127, 127, 0.85)',  // 회색
      'rgba(188, 189, 34, 0.85)',   // 올리브
      'rgba(23, 190, 207, 0.85)',   // 청록
    ]
    
    // 각 경비 코드별로 데이터셋 생성
    topCodes.forEach((codeInfo, index) => {
      const [code, name] = codeInfo
      const monthlyData = []
      
      // 각 월별 데이터 수집
      months.forEach(month => {
        const monthData = data[month]
        if (monthData && monthData.by_code) {
          // 해당 코드의 금액 찾기
          let amount = 0
          
          // Ruby에서 전달된 데이터는 [code, name] 배열이 문자열 키로 변환됨
          // 예: "["EC001", "식비"]" 형태로 저장됨
          for (const [key, value] of Object.entries(monthData.by_code)) {
            // 문자열 키를 파싱해서 비교
            try {
              if (key.startsWith('[')) {
                const parsed = JSON.parse(key)
                if (Array.isArray(parsed) && parsed[0] === code && parsed[1] === name) {
                  amount = value
                  break
                }
              }
            } catch (e) {
              // 파싱 실패 시 직접 비교
              if (key === `["${code}","${name}"]` || key === `["${code}", "${name}"]`) {
                amount = value
                break
              }
            }
          }
          monthlyData.push(amount)
        } else {
          monthlyData.push(0)
        }
      })
      
      datasets.push({
        label: `${code} ${name}`,
        data: monthlyData,
        backgroundColor: colorPalette[index % colorPalette.length],
        borderColor: colorPalette[index % colorPalette.length].replace('0.85', '1'),
        borderWidth: 1
      })
    })
    
    // 월 라벨 포맷팅 (YYYY-MM -> MM월)
    const monthLabels = months.map(month => {
      const [year, monthNum] = month.split('-')
      return `${parseInt(monthNum)}월`
    })
    
    // 차트 생성
    this.trendChart = new Chart(ctx, {
      type: 'bar',
      data: {
        labels: monthLabels,
        datasets: datasets
      },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        scales: {
          x: {
            stacked: true,
            grid: {
              display: false
            },
            ticks: {
              font: {
                size: 12
              }
            }
          },
          y: {
            stacked: true,
            beginAtZero: true,
            ticks: {
              callback: function(value) {
                return new Intl.NumberFormat('ko-KR', {
                  notation: 'compact',
                  maximumFractionDigits: 0
                }).format(value)
              },
              font: {
                size: 12
              }
            },
            grid: {
              color: 'rgba(0, 0, 0, 0.05)'
            }
          }
        },
        plugins: {
          legend: {
            display: true,
            position: 'top',
            labels: {
              boxWidth: 12,
              padding: 10,
              font: {
                size: 11
              }
            }
          },
          tooltip: {
            callbacks: {
              title: function(context) {
                const monthIndex = context[0].dataIndex
                const fullMonth = months[monthIndex]
                const [year, month] = fullMonth.split('-')
                return `${year}년 ${parseInt(month)}월`
              },
              label: function(context) {
                const value = context.raw
                const formattedAmount = new Intl.NumberFormat('ko-KR').format(value)
                return `${context.dataset.label}: ₩${formattedAmount}`
              },
              footer: function(tooltipItems) {
                // 해당 월의 총액 계산
                let total = 0
                tooltipItems.forEach(item => {
                  total += item.raw
                })
                const formattedTotal = new Intl.NumberFormat('ko-KR').format(total)
                return `총액: ₩${formattedTotal}`
              }
            },
            backgroundColor: 'rgba(0, 0, 0, 0.8)',
            padding: 12,
            titleFont: {
              size: 13,
              weight: 'bold'
            },
            bodyFont: {
              size: 12
            },
            footerFont: {
              size: 12,
              weight: 'bold'
            },
            displayColors: true,
            borderColor: 'rgba(0, 0, 0, 0.8)',
            borderWidth: 1
          }
        },
        interaction: {
          mode: 'index',
          intersect: false
        },
        animation: {
          duration: 500
        }
      }
    })
  }
  
  renderOrgChart(organizationExpenses, ctx = null) {
    if (!ctx) {
      ctx = this.orgChartTarget.getContext('2d')
    }
    
    // 기존 차트 제거
    if (this.orgChart) {
      this.orgChart.destroy()
    }
    
    // 데이터가 없으면 리턴
    if (!organizationExpenses) {
      return
    }
    
    // 데이터 준비 (금액이 있는 조직만, 상위 10개)
    const orgData = Object.entries(organizationExpenses)
      .filter(([_, data]) => data && (data.total_amount > 0 || data.total_with_descendants > 0))
      .map(([orgId, data]) => ({
        name: data.name || `조직 ${orgId}`,
        amount: data.total_amount || data.total_with_descendants || 0
      }))
      .sort((a, b) => b.amount - a.amount)
      .slice(0, 10)
    
    if (orgData.length === 0) return
    
    // 전체 합계 계산
    const total = orgData.reduce((sum, item) => sum + item.amount, 0)
    
    // 라벨과 데이터 준비
    const labels = orgData.map(item => item.name)
    const values = orgData.map(d => d.amount)
    
    // 데이터 라벨 준비 (바 끝에 표시할 텍스트)
    const dataLabels = values.map(value => {
      const percentage = ((value / total) * 100).toFixed(1)
      const formattedAmount = new Intl.NumberFormat('ko-KR').format(value)
      return `₩${formattedAmount} (${percentage}%)`
    })
    
    // 차트 생성 (수평 바 차트)
    this.orgChart = new Chart(ctx, {
      type: 'bar',
      data: {
        labels: labels,
        datasets: [{
          label: '경비',
          data: values,
          backgroundColor: 'rgba(70, 130, 180, 0.8)', // 스틸블루 계열
          borderColor: 'rgb(70, 130, 180)',
          borderWidth: 1,
          barThickness: 20, // 바 두께를 20px로 고정
          maxBarThickness: 25 // 최대 두께 제한
        }]
      },
      plugins: [{
        afterDatasetsDraw: function(chart) {
          const ctx = chart.ctx
          ctx.font = 'bold 12px sans-serif'
          ctx.fillStyle = '#1f2937'  // 왼쪽 영역과 동일한 진한 회색
          ctx.textAlign = 'left'
          ctx.textBaseline = 'middle'
          
          chart.data.datasets.forEach((dataset, i) => {
            const meta = chart.getDatasetMeta(i)
            meta.data.forEach((bar, index) => {
              const label = dataLabels[index]
              const x = bar.x + 5
              const y = bar.y
              ctx.fillText(label, x, y)
            })
          })
        }
      }],
      options: {
        responsive: true,
        maintainAspectRatio: false,
        indexAxis: 'y', // 수평 바 차트
        layout: {
          padding: {
            right: 150 // 오른쪽 여백 추가 (라벨 공간)
          }
        },
        plugins: {
          legend: {
            display: false
          },
          tooltip: {
            callbacks: {
              label: function(context) {
                return dataLabels[context.dataIndex]
              }
            }
          }
        },
        animation: false,
        scales: {
          x: {
            beginAtZero: true,
            ticks: {
              callback: function(value) {
                return new Intl.NumberFormat('ko-KR', {
                  notation: 'compact',
                  maximumFractionDigits: 0
                }).format(value)
              }
            }
          },
          y: {
            ticks: {
              font: {
                size: 12,
                weight: 'bold'
              },
              color: '#374151'  // 진한 회색으로 변경
            }
          }
        }
      }
    })
  }
}