import { Controller } from "@hotwired/stimulus"

// 재사용 가능한 조직 선택 컨트롤러
export default class extends Controller {
  static targets = ["expandIcon", "orgLink", "includeDescendants"]
  
  connect() {
    // 초기 상태 설정
    this.setupInitialState()
  }
  
  setupInitialState() {
    // 1차 하위 조직까지 기본적으로 펼치기
    this.expandFirstLevel()
    
    // 선택된 조직이 있으면 해당 조직까지의 경로를 펼침
    const selectedLink = this.orgLinkTargets.find(link => 
      link.classList.contains('bg-blue-600')
    )
    
    if (selectedLink) {
      this.expandToSelectedOrganization(selectedLink)
    }
  }
  
  expandFirstLevel() {
    // level=0인 조직의 직계 자식들만 표시
    const firstLevelContainers = this.element.querySelectorAll('[data-org-level="0"]')
    firstLevelContainers.forEach(container => {
      if (container.classList.contains('org-children')) {
        container.style.display = 'block'
        // 부모 아이콘 회전
        const parentOrgId = container.dataset.parentOrgId
        const icon = this.element.querySelector(`button[data-org-id="${parentOrgId}"] svg`)
        if (icon) {
          icon.classList.add('rotate-90')
        }
      }
    })
  }
  
  expandToSelectedOrganization(selectedLink) {
    const orgId = selectedLink.dataset.orgId
    const node = this.element.querySelector(`[data-org-id="${orgId}"]`)
    
    if (node) {
      // 부모 노드들을 찾아서 모두 펼침
      let parent = node.parentElement
      while (parent && parent !== this.element) {
        if (parent.classList.contains('org-children')) {
          parent.style.display = 'block'
          // 해당 아이콘 회전
          const parentOrgId = parent.dataset.parentOrgId
          const icon = this.element.querySelector(`button[data-org-id="${parentOrgId}"] svg`)
          if (icon) {
            icon.classList.add('rotate-90')
          }
        }
        parent = parent.parentElement
      }
    }
  }
  
  toggleExpand(event) {
    event.preventDefault()
    event.stopPropagation()
    
    const button = event.currentTarget
    const orgId = button.dataset.orgId
    const icon = button.querySelector('svg')
    const childrenContainer = this.element.querySelector(`[data-parent-org-id="${orgId}"]`)
    
    if (childrenContainer) {
      if (childrenContainer.style.display === 'none' || !childrenContainer.style.display) {
        childrenContainer.style.display = 'block'
        icon.classList.add('rotate-90')
      } else {
        childrenContainer.style.display = 'none'
        icon.classList.remove('rotate-90')
        // 하위 조직들도 모두 접기
        this.collapseChildren(childrenContainer)
      }
    }
  }
  
  collapseChildren(container) {
    const childContainers = container.querySelectorAll('.org-children')
    childContainers.forEach(child => {
      child.style.display = 'none'
      const parentOrgId = child.dataset.parentOrgId
      const icon = this.element.querySelector(`button[data-org-id="${parentOrgId}"] svg`)
      if (icon) {
        icon.classList.remove('rotate-90')
      }
    })
  }
  
  expandAll(event) {
    event.preventDefault()
    
    const allChildContainers = this.element.querySelectorAll('.org-children')
    allChildContainers.forEach(container => {
      container.style.display = 'block'
    })
    
    const allIcons = this.expandIconTargets
    allIcons.forEach(icon => {
      icon.classList.add('rotate-90')
    })
  }
  
  collapseAll(event) {
    event.preventDefault()
    
    // 모든 하위 조직 접기 (1차 하위는 유지)
    const allChildContainers = this.element.querySelectorAll('.org-children')
    allChildContainers.forEach(container => {
      const level = parseInt(container.dataset.orgLevel)
      // level 0 (1차 하위)는 열어두고, 그 이하는 모두 접기
      if (level > 0) {
        container.style.display = 'none'
        // 해당 아이콘도 원래대로
        const parentOrgId = container.dataset.parentOrgId
        const icon = this.element.querySelector(`button[data-org-id="${parentOrgId}"] svg`)
        if (icon) {
          icon.classList.remove('rotate-90')
        }
      } else {
        // 1차 하위는 열어둠
        container.style.display = 'block'
        const parentOrgId = container.dataset.parentOrgId
        const icon = this.element.querySelector(`button[data-org-id="${parentOrgId}"] svg`)
        if (icon) {
          icon.classList.add('rotate-90')
        }
      }
    })
  }
  
  toggleIncludeDescendants(event) {
    const checkbox = event.currentTarget
    const isChecked = checkbox.checked
    
    // 현재 URL에서 파라미터 가져오기
    const url = new URL(window.location.href)
    
    // include_descendants 파라미터 업데이트
    if (isChecked) {
      url.searchParams.set('include_descendants', 'true')
    } else {
      url.searchParams.set('include_descendants', 'false')
    }
    
    // Turbo를 사용하여 페이지 리로드
    Turbo.visit(url.toString(), { frame: "closing_dashboard" })
  }
}