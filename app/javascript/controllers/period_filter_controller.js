import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["select"]

  connect() {
    console.log("Period filter controller connected")
  }

  updatePeriod(event) {
    const period = event.target.value
    const currentUrl = new URL(window.location)
    currentUrl.searchParams.set('period', period)
    
    // Turbo를 사용하여 페이지 새로고침
    window.location.href = currentUrl.toString()
  }
}