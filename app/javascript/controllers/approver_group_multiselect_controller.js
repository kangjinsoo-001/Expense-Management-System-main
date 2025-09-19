import { Controller } from "@hotwired/stimulus"

let Choices

export default class extends Controller {
  static targets = ["userSelect"]
  
  async connect() {
    await this.loadChoicesJS()
    this.initializeMultiSelect()
  }
  
  async loadChoicesJS() {
    if (window.Choices) {
      Choices = window.Choices
      return
    }
    
    return new Promise((resolve) => {
      const script = document.createElement('script')
      script.src = '/javascripts/choices.min.js'
      script.onload = () => {
        Choices = window.Choices
        resolve()
      }
      script.onerror = () => {
        console.error("Failed to load Choices.js")
        resolve()
      }
      if (!document.querySelector('script[src="/javascripts/choices.min.js"]')) {
        document.head.appendChild(script)
      } else {
        resolve()
      }
    })
  }
  
  initializeMultiSelect() {
    if (!this.hasUserSelectTarget) return
    
    const selectElement = this.userSelectTarget
    
    // 이미 초기화되었으면 스킵
    if (selectElement.hasAttribute('data-choices-initialized')) {
      return
    }
    
    selectElement.setAttribute('data-choices-initialized', 'true')
    
    // 기존 선택된 값들 가져오기
    const selectedValues = []
    if (selectElement.dataset.selectedValues) {
      const ids = JSON.parse(selectElement.dataset.selectedValues)
      // option의 value와 매칭
      ids.forEach(id => {
        const option = selectElement.querySelector(`option[value="${id}"]`)
        if (option) {
          selectedValues.push(id.toString())
        }
      })
    }
    
    // Choice.js 초기화
    this.choices = new Choices(selectElement, {
      removeItemButton: true,
      searchEnabled: true,
      searchResultLimit: 10,
      placeholder: true,
      placeholderValue: '사용자를 검색하여 선택하세요',
      noResultsText: '검색 결과가 없습니다',
      noChoicesText: '선택할 사용자가 없습니다',
      itemSelectText: '선택하려면 클릭',
      shouldSort: false,
      searchFloor: 1,
      searchPlaceholderValue: '이름 또는 부서로 검색...',
      maxItemCount: -1,  // 무제한
      renderChoiceLimit: -1,
      classNames: {
        containerOuter: 'choices',
        containerInner: 'choices__inner',
        input: 'choices__input',
        inputCloned: 'choices__input--cloned',
        list: 'choices__list',
        listItems: 'choices__list--multiple',
        listSingle: 'choices__list--single',
        listDropdown: 'choices__list--dropdown',
        item: 'choices__item',
        itemSelectable: 'choices__item--selectable',
        itemDisabled: 'choices__item--disabled',
        itemChoice: 'choices__item--choice',
        placeholder: 'choices__placeholder',
        group: 'choices__group',
        groupHeading: 'choices__heading',
        button: 'choices__button',
        activeState: 'is-active',
        focusState: 'is-focused',
        openState: 'is-open',
        disabledState: 'is-disabled',
        highlightedState: 'is-highlighted',
        selectedState: 'is-selected',
        flippedState: 'is-flipped',
        loadingState: 'is-loading',
        noResults: 'has-no-results',
        noChoices: 'has-no-choices'
      }
    })
    
    // 선택된 아이템 스타일 적용
    selectElement.addEventListener('addItem', () => {
      setTimeout(() => this.applyChoicesStyles(), 50)
    })
    
    selectElement.addEventListener('removeItem', () => {
      setTimeout(() => this.applyChoicesStyles(), 50)
    })
    
    // 초기 선택값 설정
    if (selectedValues.length > 0) {
      selectedValues.forEach(value => {
        this.choices.setChoiceByValue(value)
      })
      setTimeout(() => this.applyChoicesStyles(), 100)
    }
  }
  
  // Choices.js 스타일 적용 (회색으로 변경)
  applyChoicesStyles() {
    const container = this.userSelectTarget.closest('.choices')
    if (!container) return
    
    // 모든 선택된 아이템에 스타일 적용
    const items = container.querySelectorAll('.choices__item')
    items.forEach(item => {
      // 기본 청록색을 회색으로 변경
      item.style.backgroundColor = '#e5e7eb'
      item.style.borderColor = '#e5e7eb'
      item.style.color = '#374151'
    })
  }
  
  disconnect() {
    // Choices 인스턴스 정리
    if (this.choices) {
      this.choices.destroy()
    }
  }
}