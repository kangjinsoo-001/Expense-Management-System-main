// 브라우저 콘솔에서 실행할 테스트 코드

// 1. 경비 코드 선택 시뮬레이션
const expenseCodeSelect = document.querySelector('[data-expense-item-form-target="expenseCode"]');
if (expenseCodeSelect) {
  console.log("경비 코드 select 요소 찾음");
  
  // 첫 번째 경비 코드 선택
  const firstOption = expenseCodeSelect.options[1]; // 0번은 prompt
  if (firstOption) {
    console.log("선택할 경비 코드:", firstOption.text, "ID:", firstOption.value);
    expenseCodeSelect.value = firstOption.value;
    
    // change 이벤트 발생
    const event = new Event('change', { bubbles: true });
    expenseCodeSelect.dispatchEvent(event);
    
    console.log("Change 이벤트 발생 완료");
  }
} else {
  console.log("경비 코드 select 요소를 찾을 수 없음");
}

// 2. Form 컨트롤러 확인
const formElement = document.querySelector('[data-controller~="expense-item-form"]');
if (formElement) {
  console.log("Form element dataset:", formElement.dataset);
  console.log("Edit mode:", formElement.dataset.editMode);
}

// 3. 네트워크 요청 모니터링
console.log("네트워크 탭에서 recent_submission 요청을 확인하세요");