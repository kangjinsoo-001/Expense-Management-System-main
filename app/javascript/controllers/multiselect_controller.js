import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["input", "dropdown", "selected", "searchInput"]
  static values = { 
    type: String,
    selectedItems: Array
  }

  connect() {
    console.log('Multiselect controller connected')
    this.selectedItemsValue = this.selectedItemsValue || []
    this.loadInitialValues()
    this.hideDropdown()
    
    // 외부 클릭 감지를 위한 이벤트 리스너
    this.handleClickOutsideBound = this.handleClickOutside.bind(this)
    document.addEventListener('click', this.handleClickOutsideBound)
  }

  disconnect() {
    document.removeEventListener('click', this.handleClickOutsideBound)
  }

  loadInitialValues() {
    // 기존 값이 있으면 로드 (콤마로 구분된 문자열)
    const initialValue = this.inputTarget.value
    if (initialValue) {
      const items = initialValue.split(',').map(item => item.trim())
      this.selectedItemsValue = items
      this.updateDisplay()
    }
  }

  async search(event) {
    const query = event.target.value
    console.log('Search triggered with query:', query, 'Type:', this.typeValue)
    
    if (query.length < 2) {
      this.hideDropdown()
      return
    }

    try {
      let response
      if (this.typeValue === 'participants') {
        console.log('Searching users...')
        response = await fetch(`/api/users/search?q=${query}`)
      } else if (this.typeValue === 'organization') {
        console.log('Searching organizations...')
        response = await fetch(`/api/organizations/search?q=${query}`)
      }

      console.log('Response status:', response.status)
      if (response.ok) {
        const data = await response.json()
        console.log('Search results:', data)
        this.showResults(data)
      } else {
        console.error('Response not ok:', response.status, response.statusText)
      }
    } catch (error) {
      console.error('검색 실패:', error)
    }
  }

  showResults(results) {
    this.dropdownTarget.innerHTML = results.map(item => {
      const isSelected = this.isItemSelected(item)
      return `
        <div class="px-4 py-2 hover:bg-gray-100 cursor-pointer flex justify-between items-center ${isSelected ? 'bg-gray-50' : ''}"
             data-action="click->multiselect#selectItem"
             data-id="${item.id}"
             data-name="${item.name}"
             data-email="${item.email || ''}">
          <div>
            <div class="font-medium">${item.name}</div>
            ${item.email ? `<div class="text-sm text-gray-500">${item.email}</div>` : ''}
            ${item.department ? `<div class="text-sm text-gray-500">${item.department}</div>` : ''}
          </div>
          ${isSelected ? '<svg class="w-5 h-5 text-green-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M5 13l4 4L19 7"></path></svg>' : ''}
        </div>
      `
    }).join('')

    this.showDropdown()
  }

  selectItem(event) {
    event.preventDefault()
    const item = event.currentTarget
    const id = item.dataset.id
    const name = item.dataset.name
    
    const itemData = { id, name }
    
    if (this.isItemSelected(itemData)) {
      // 이미 선택된 경우 제거
      this.removeItem(itemData)
    } else {
      // 새로 추가
      this.selectedItemsValue = [...this.selectedItemsValue, name]
    }
    
    this.updateDisplay()
    this.updateInput()
    this.searchInputTarget.value = ''
    this.hideDropdown()
  }

  removeItem(item) {
    this.selectedItemsValue = this.selectedItemsValue.filter(selected => selected !== item.name)
  }

  removeSelectedItem(event) {
    const name = event.currentTarget.dataset.name
    this.selectedItemsValue = this.selectedItemsValue.filter(item => item !== name)
    this.updateDisplay()
    this.updateInput()
  }

  isItemSelected(item) {
    return this.selectedItemsValue.includes(item.name)
  }

  updateDisplay() {
    this.selectedTarget.innerHTML = this.selectedItemsValue.map(name => `
      <span class="inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-blue-100 text-blue-800 mr-2 mb-2">
        ${name}
        <button type="button" class="ml-1 inline-flex items-center justify-center w-4 h-4 text-blue-400 hover:bg-blue-200 hover:text-blue-500 rounded-full"
                data-action="click->multiselect#removeSelectedItem"
                data-name="${name}">
          <svg class="w-2 h-2" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12"></path>
          </svg>
        </button>
      </span>
    `).join('')
  }

  updateInput() {
    // 선택된 항목들을 콤마로 구분하여 hidden input에 저장
    this.inputTarget.value = this.selectedItemsValue.join(', ')
    
    // 검증 트리거를 위해 input 이벤트 발생
    const event = new Event('input', { bubbles: true })
    this.inputTarget.dispatchEvent(event)
    
    // 디버깅 로그
    console.log('Multiselect updateInput:', this.typeValue, 'value:', this.inputTarget.value)
  }

  showDropdown() {
    this.dropdownTarget.classList.remove('hidden')
  }

  hideDropdown() {
    this.dropdownTarget.classList.add('hidden')
  }

  handleClickOutside(event) {
    if (!this.element.contains(event.target)) {
      this.hideDropdown()
    }
  }
}