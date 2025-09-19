import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["validateButton", "resultContainer"]
  static values = { expenseSheetId: Number }
  
  // 토큰 사용량을 한국 원화로 계산
  calculateCostInKRW(tokenUsage) {
    if (!tokenUsage || !tokenUsage.prompt_tokens) return null
    
    // Gemini 2.5 Flash 가격 (2025년 기준)
    const inputPricePerMillion = 0.30  // USD
    const outputPricePerMillion = 2.50 // USD
    const usdToKrw = 1400 // 환율
    
    const inputTokens = tokenUsage.prompt_tokens || 0
    const outputTokens = tokenUsage.completion_tokens || 0
    
    const inputCostUSD = (inputTokens / 1000000) * inputPricePerMillion
    const outputCostUSD = (outputTokens / 1000000) * outputPricePerMillion
    const totalCostUSD = inputCostUSD + outputCostUSD
    
    return (totalCostUSD * usdToKrw).toFixed(1)
  }
  
  async validateWithAI(event) {
    event.preventDefault()
    
    // 버튼 비활성화 및 로딩 상태 표시
    const button = this.validateButtonTarget
    const originalText = button.innerHTML
    button.disabled = true
    button.innerHTML = `
      <svg class="animate-spin h-4 w-4 mr-2" fill="none" viewBox="0 0 24 24">
        <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
        <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
      </svg>
      검증 시작 중...
    `
    
    // 진행 상황 표시 영역 표시
    this.showValidationProgress()
    
    try {
      // 단계별로 순차적으로 API 호출
      let stepResults = []
      let allTokenUsage = { total_tokens: 0, prompt_tokens: 0, completion_tokens: 0 }
      let totalCostKRW = 0
      
      for (let step = 1; step <= 4; step++) {
        // 단계 시작 - UI 업데이트
        this.updateStepStatus(step, 'processing')
        button.innerHTML = `
          <svg class="animate-spin h-4 w-4 mr-2" fill="none" viewBox="0 0 24 24">
            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
          </svg>
          검증 ${step}/4 단계 진행 중...
        `
        
        // 단계별 API 호출 (3단계와 4단계에서는 Turbo Stream 응답 요청)
        const headers = {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        }
        
        // 4단계에서는 Turbo Stream 응답도 받을 수 있도록 설정
        if (step === 4) {
          headers['Accept'] = 'text/vnd.turbo-stream.html, application/json'
        }
        
        const response = await fetch(`/expense_sheets/${this.expenseSheetIdValue}/validate_step`, {
          method: 'POST',
          headers: headers,
          body: JSON.stringify({ step: step })
        })
      
        if (!response.ok) {
          throw new Error(`HTTP error! status: ${response.status}`)
        }
        
        // 응답 타입 확인
        const contentType = response.headers.get('content-type')
        
        if (contentType && contentType.includes('text/vnd.turbo-stream')) {
          // Turbo Stream 응답 처리 (3단계 또는 4단계)
          const turboStreamHTML = await response.text()
          // Turbo가 자동으로 DOM을 업데이트함
          Turbo.renderStreamMessage(turboStreamHTML)
          
          // 4단계인 경우 validation_details_table이 업데이트됨
          if (step === 4) {
            console.log('%c[4단계 Turbo Stream 업데이트]', 'background: #4CAF50; color: white; padding: 2px 5px; font-weight: bold;')
            console.log('validation_details_table이 새로운 검증 결과로 업데이트됨')
          }
          
          // 4단계는 서버에서 데이터가 반환되지 않으므로 더미 데이터 생성
          const stepData = {
            step: step,
            name: '영수증 첨부 확인',
            status: 'success',
            is_final: true,
            validation_summary: '검증이 완료되었습니다'
          }
          stepResults.push(stepData)
        } else {
          // JSON 응답 처리 (1-4단계)
          const stepData = await response.json()
          stepResults.push(stepData)
        }
        
        // 현재 단계 데이터 참조
        const currentStepData = stepResults[stepResults.length - 1]
        
        // 콘솔에 단계별 결과 출력
        this.logStepResult(step, currentStepData)
        
        // 토큰 사용량 누적
        if (currentStepData.token_usage) {
          allTokenUsage.total_tokens += currentStepData.token_usage.total_tokens || 0
          allTokenUsage.prompt_tokens += currentStepData.token_usage.prompt_tokens || 0
          allTokenUsage.completion_tokens += currentStepData.token_usage.completion_tokens || 0
        }
        
        // 비용 누적
        if (currentStepData.cost_krw) {
          totalCostKRW += parseFloat(currentStepData.cost_krw)
        }
        
        // 단계 완료 - UI 업데이트
        const status = currentStepData.status || (currentStepData.issues_found?.length > 0 ? 'warning' : 'success')
        
        // 단계별 메시지 설정
        let stepMessage = ''
        const debugInfo = currentStepData.debug_info || {}
        
        if (step === 1) {
          stepMessage = status === 'success' ? '첨부파일 검증 통과' : '첨부파일이 필요합니다'
        } else if (step === 2) {
          // 통신비 이동 메시지 확인
          const telecomMoved = currentStepData.validation_details?.some(d => 
            d.message && d.message.includes('자동 이동')
          )
          if (telecomMoved) {
            stepMessage = '통신비를 최상단으로 이동했습니다'
          } else {
            stepMessage = status === 'success' ? '통신비 위치 확인 완료' : '통신비 위치 조정 필요'
          }
        } else if (step === 3) {
          // 3단계: 재정렬 및 영수증 정보 표시
          
          // 디버그 정보 출력
          console.group('%c[3단계 검증 디버깅]', 'background: #9C27B0; color: white; padding: 2px 5px; font-weight: bold;')
          console.log('전체 debug_info:', debugInfo)
          
          // Gemini API 요청/응답 디버깅
          if (debugInfo.gemini_request || debugInfo.gemini_response) {
            console.group('%c📊 Gemini API 통신', 'color: #673AB7; font-weight: bold;')
            
            if (debugInfo.gemini_request) {
              console.group('%c📤 요청 데이터', 'color: #2196F3; font-weight: bold;')
              console.log('카드 거래 내역 (%d건):', debugInfo.gemini_request.card_transactions?.length || 0)
              if (debugInfo.gemini_request.card_transactions) {
                console.table(debugInfo.gemini_request.card_transactions)
              }
              console.log('경비 항목 (%d건):', debugInfo.gemini_request.expense_items?.length || 0)
              if (debugInfo.gemini_request.expense_items) {
                console.table(debugInfo.gemini_request.expense_items)
              }
              console.groupEnd()
            }
            
            if (debugInfo.gemini_response) {
              console.group('%c📥 응답 데이터', 'color: #4CAF50; font-weight: bold;')
              console.log('전체 응답:', debugInfo.gemini_response)
              
              if (debugInfo.gemini_response.validation_details) {
                console.log('검증 결과 (%d건):', debugInfo.gemini_response.validation_details.length)
                console.table(debugInfo.gemini_response.validation_details)
              }
              
              // 토큰 사용량 표시
              if (debugInfo.token_usage || debugInfo.gemini_response.token_usage) {
                const tokenData = debugInfo.token_usage || debugInfo.gemini_response.token_usage
                console.group('%c⚡ 토큰 사용량', 'color: #FF9800; font-weight: bold;')
                console.log('프롬프트 토큰:', tokenData.prompt_tokens || 0)
                console.log('응답 토큰:', tokenData.completion_tokens || 0)
                console.log('총 토큰:', tokenData.total_tokens || 0)
                console.groupEnd()
              }
              
              if (debugInfo.gemini_response.suggested_order) {
                console.group('%c🔄 재정렬 제안', 'color: #FF9800; font-weight: bold;')
                const order = debugInfo.gemini_response.suggested_order
                console.log('재정렬 필요:', order.reorder_needed)
                console.log('요약:', order.reorder_summary)
                
                if (order.reorder_details || order.suggested_order) {
                  const details = order.reorder_details || order.suggested_order
                  console.log('재정렬 상세 (%d건):', details?.length || 0)
                  if (details) console.table(details)
                }
                
                if (order.items_needing_receipts) {
                  console.log('영수증 필요 항목 (%d건):', order.items_needing_receipts.length)
                  console.table(order.items_needing_receipts)
                }
                console.groupEnd()
              }
              
              if (debugInfo.gemini_response.token_usage) {
                console.log('토큰 사용량:', debugInfo.gemini_response.token_usage)
              }
              
              console.groupEnd()
            }
            
            console.groupEnd()
          }
          
          // 재정렬 결과 메시지
          if (debugInfo.items_reordered) {
            console.log('✅ 재정렬 실행됨: %d개 항목', debugInfo.reorder_count || 0)
            stepMessage = `${debugInfo.reorder_count || 0}개 항목 재정렬 완료`
          }
          
          // 영수증 필요 항목 메시지
          if (debugInfo.items_needing_receipts && debugInfo.items_needing_receipts.length > 0) {
            console.log('⚠️ 영수증 필요: %d개 항목', debugInfo.receipt_needed_count || debugInfo.items_needing_receipts.length)
            const receiptMsg = `${debugInfo.receipt_needed_count || debugInfo.items_needing_receipts.length}개 항목 영수증 필요`
            stepMessage = stepMessage ? `${stepMessage}, ${receiptMsg}` : receiptMsg
          }
          
          if (!stepMessage) {
            stepMessage = status === 'success' ? '항목 순서/금액 검증 완료' : '항목 확인이 필요합니다'
          }
          
          console.groupEnd() // 3단계 검증 디버깅 그룹 종료
        } else if (step === 4) {
          // 4단계: 영수증 첨부 확인
          if (currentStepData.receipt_check) {
            const { items_missing_receipts } = currentStepData.receipt_check
            if (items_missing_receipts && items_missing_receipts.length > 0) {
              stepMessage = `${items_missing_receipts.length}개 항목에 영수증 첨부 필요`
            } else {
              stepMessage = '모든 항목 영수증 확인 완료'
            }
          } else {
            stepMessage = status === 'success' ? '영수증 첨부 확인 완료' : '영수증 첨부가 필요합니다'
          }
        }
        
        this.updateStepStatus(step, status, stepMessage, debugInfo)
        
        // 실패 상태이면 나머지 단계 건너뛰기
        if (status === 'failed') {
          console.log(`%c[검증 중단] 단계 ${step}에서 문제 발견`, 'color: red; font-weight: bold;')
          
          // 나머지 단계를 건너뜀 상태로 표시
          for (let skipStep = step + 1; skipStep <= 4; skipStep++) {
            this.updateStepStatus(skipStep, 'skipped')
            stepResults.push({
              step: skipStep,
              name: this.getStepName(skipStep),
              status: 'skipped',
              debug_info: { skipped: true, reason: `Step ${step} failed` }
            })
          }
          
          break // 루프 종료
        }
        
        // 잠시 대기 (시각적 효과)
        await new Promise(resolve => setTimeout(resolve, 300))
      }
      
      // 모든 단계 완료 후 전체 검증 결과를 별도로 가져오기
      const resultResponse = await fetch(`/expense_sheets/${this.expenseSheetIdValue}/validation_result`, {
        method: 'GET',
        headers: {
          'Accept': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        }
      })
      
      let fullValidationData = null
      if (resultResponse.ok) {
        fullValidationData = await resultResponse.json()
        console.log('%c[전체 검증 결과 수신]', 'background: #4CAF50; color: white; padding: 2px 5px; font-weight: bold;')
        console.log(fullValidationData)
        
        // 전체 결과를 stepResults에 병합
        if (fullValidationData.step_results) {
          stepResults = fullValidationData.step_results
          allTokenUsage = fullValidationData.total_token_usage
        }
      }
      
      // 전체 결과 생성
      // 4단계 영수증 검증 결과 확인
      const step4Result = stepResults.find(r => r.step === 4)
      const hasMissingReceipts = step4Result?.receipt_check?.items_missing_receipts?.length > 0
      
      // 실제 검증 결과 반영
      const allStepsSuccess = stepResults.every(r => r.status === 'success')
      const isValid = allStepsSuccess && !hasMissingReceipts
      
      // 검증 요약 메시지 생성
      let validationSummary
      if (isValid) {
        validationSummary = "모든 경비 항목이 검증을 통과했습니다."
      } else if (hasMissingReceipts) {
        const missingCount = step4Result.receipt_check.items_missing_receipts.length
        validationSummary = `${missingCount}개 항목에 영수증 첨부가 필요합니다.`
      } else {
        const warningCount = stepResults.filter(r => r.status === 'warning').length
        validationSummary = `${warningCount}개 단계에서 문제가 발견되었습니다.`
      }
      
      const data = {
        step_results: stepResults,
        token_usage: allTokenUsage,
        cost_krw: totalCostKRW.toFixed(1),
        all_valid: isValid,
        validation_summary: validationSummary
      }
      
      // 단계별 검증 결과 콘솔 출력
      if (data.step_results && data.step_results.length > 0) {
        console.group('%c[단계별 AI 검증 결과]', 'background: #00BCD4; color: white; padding: 2px 5px; font-weight: bold;')
        
        data.step_results.forEach((stepResult, index) => {
          const statusColor = stepResult.status === 'success' ? '#4CAF50' : '#FF9800'
          console.group(`%c[단계 ${stepResult.step}: ${stepResult.name}]`, `background: ${statusColor}; color: white; padding: 2px 5px;`)
          
          // 디버그 정보 출력
          if (stepResult.debug_info) {
            console.log('%c📋 검증 규칙:', 'font-weight: bold; color: #2196F3;')
            console.log(`  규칙 타입: ${stepResult.debug_info.rule_type}`)
            console.log(`  검증 항목 수: ${stepResult.debug_info.items_count}개`)
            console.log(`  첨부파일 수: ${stepResult.debug_info.attachments_count}개`)
            
            // 3단계 특별 처리
            if (stepResult.step === 3) {
              console.log('%c🔍 3단계 상세 정보:', 'font-weight: bold; color: #FF5722;')
              if (stepResult.debug_info.gemini_request) {
                console.log('카드 거래 내역:')
                console.table(stepResult.debug_info.gemini_request.card_transactions)
                console.log('경비 항목:')
                console.table(stepResult.debug_info.gemini_request.expense_items)
              }
              if (stepResult.debug_info.gemini_response) {
                console.log('%cGemini 응답:', 'font-weight: bold; color: #9C27B0;')
                console.log(stepResult.debug_info.gemini_response)
              }
              if (stepResult.debug_info.items_needing_receipts) {
                console.log('%c⚠️ 영수증 필요 항목:', 'font-weight: bold; color: red;')
                console.table(stepResult.debug_info.items_needing_receipts)
              }
            }
            
            // 프롬프트 상세 정보
            if (stepResult.debug_info.prompt) {
              console.log('%c💬 프롬프트:', 'font-weight: bold; color: #673AB7;')
              console.log('  System:', stepResult.debug_info.prompt.system_prompt)
              console.log('  Rule:', stepResult.debug_info.prompt.validation_rule)
              console.log('  Request:', stepResult.debug_info.prompt.request?.substring(0, 200) + '...')
            }
          }
          
          // 토큰 사용량
          if (stepResult.token_usage) {
            console.log('%c⚡ 토큰 사용량:', 'font-weight: bold; color: #FF5722;')
            console.log(`  프롬프트: ${stepResult.token_usage.prompt_tokens || 0}`)
            console.log(`  응답: ${stepResult.token_usage.completion_tokens || 0}`)
            console.log(`  총계: ${stepResult.token_usage.total_tokens || 0}`)
          }
          
          console.log(`%c✅ 상태: ${stepResult.status === 'success' ? '통과' : '문제 발견'}`, 
                     `color: ${stepResult.status === 'success' ? 'green' : 'orange'}; font-weight: bold;`)
          console.groupEnd()
        })
        
        // 전체 토큰 사용량 요약
        if (data.token_usage) {
          console.group('%c[전체 토큰 사용량 요약]', 'background: #9C27B0; color: white; padding: 2px 5px; font-weight: bold;')
          console.log(`총 프롬프트 토큰: ${data.token_usage.prompt_tokens || 0}`)
          console.log(`총 응답 토큰: ${data.token_usage.completion_tokens || 0}`)
          console.log(`전체 토큰: ${data.token_usage.total_tokens || 0}`)
          console.groupEnd()
        }
        
        console.groupEnd()
      }
      
      // 기존 디버깅 정보 (단계별이 아닌 경우)
      else if (data.debug_prompt) {
        console.group('%c[AI 검증 프롬프트 - Gemini 요청]', 'background: #4CAF50; color: white; padding: 2px 5px; font-weight: bold;')
        console.log('%cSystem Prompt:', 'font-weight: bold; color: #2196F3;')
        console.log(data.debug_prompt.system_prompt)
        console.log('%cValidation Rules:', 'font-weight: bold; color: #2196F3;')
        console.log(data.debug_prompt.validation_rules)
        console.log('%cRequest:', 'font-weight: bold; color: #2196F3;')
        console.log(data.debug_prompt.request)
        console.log('%c경비 항목:', 'font-weight: bold; color: #FF9800;')
        console.table(data.debug_prompt.expense_items)
        console.log('%c첨부파일 분석 결과:', 'font-weight: bold; color: #FF9800;')
        console.table(data.debug_prompt.expense_sheet_data)
        console.groupEnd()
      }
      
      // 결과 표시
      this.displayResults(data)
      
      // 검증 완료 메시지 업데이트 (새로고침 없이)
      this.updateValidationStatus(data)
      
      // 검증 완료 후 UI 정리
      this.cleanupAfterValidation()
    } catch (error) {
      console.error('AI 검증 중 오류 발생:', error)
      this.showError('AI 검증 중 오류가 발생했습니다. 다시 시도해주세요.')
      // 에러 발생 시에도 UI 정리
      this.cleanupAfterValidation()
    } finally {
      // 버튼 원래 상태로 복원
      button.disabled = false
      button.innerHTML = originalText
    }
  }
  
  displayResults(data) {
    // 모든 검증 결과를 표시하지 않음 (테이블로 대체됨)
    const container = this.resultContainerTarget
    container.classList.add('hidden')
    container.innerHTML = ''
  }
  
  // 원본 데이터 토글 기능 제거
  // toggleRawData 함수는 더 이상 사용되지 않음
  
  showError(message) {
    const container = this.resultContainerTarget
    container.classList.remove('hidden')
    container.innerHTML = `
      <div class="bg-red-50 border border-red-200 rounded-md p-4">
        <div class="flex">
          <div class="flex-shrink-0">
            <svg class="h-5 w-5 text-red-400" fill="currentColor" viewBox="0 0 20 20">
              <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
            </svg>
          </div>
          <div class="ml-3">
            <h3 class="text-sm font-medium text-red-800">오류 발생</h3>
            <p class="text-sm text-red-700 mt-1">${message}</p>
          </div>
        </div>
      </div>
    `
  }
  
  getStatusIcon(status) {
    switch(status) {
      case '완료':
        return `
          <svg class="h-5 w-5 text-green-500" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
          </svg>
        `
      case '확인 필요':
        return `
          <svg class="h-5 w-5 text-yellow-500" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
          </svg>
        `
      default:
        return `
          <svg class="h-5 w-5 text-gray-400" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm0-2a6 6 0 100-12 6 6 0 000 12z" clip-rule="evenodd" />
          </svg>
        `
    }
  }
  
  escapeHtml(text) {
    const div = document.createElement('div')
    div.textContent = text
    return div.innerHTML
  }
  
  logStepResult(stepNumber, stepData) {
    const statusColor = stepData.status === 'success' ? '#4CAF50' : '#FF9800'
    
    console.group(`%c[단계 ${stepNumber}: ${stepData.name}]`, `background: ${statusColor}; color: white; padding: 2px 5px; font-weight: bold;`)
    
    // 디버그 정보 출력
    if (stepData.debug_info) {
      console.log('%c📋 검증 규칙:', 'font-weight: bold; color: #2196F3;')
      console.log(`  규칙 타입: ${stepData.debug_info.rule_type}`)
      console.log(`  검증 항목 수: ${stepData.debug_info.items_count}개`)
      console.log(`  첨부파일 수: ${stepData.debug_info.attachments_count}개`)
      
      // 프롬프트 정보
      if (stepData.debug_info.prompt) {
        console.log('%c💬 프롬프트:', 'font-weight: bold; color: #673AB7;')
        console.log('  System:', stepData.debug_info.prompt.system_prompt)
        console.log('  Rule:', stepData.debug_info.prompt.validation_rule)
        console.log('  Request (일부):', stepData.debug_info.prompt.request?.substring(0, 200) + '...')
      }
    }
    
    // 토큰 사용량
    if (stepData.token_usage) {
      console.log('%c⚡ 토큰 사용량:', 'font-weight: bold; color: #FF5722;')
      console.log(`  프롬프트: ${stepData.token_usage.prompt_tokens || 0}`)
      console.log(`  응답: ${stepData.token_usage.completion_tokens || 0}`)
      console.log(`  총계: ${stepData.token_usage.total_tokens || 0}`)
    }
    
    // 검증 결과
    if (stepData.validation_details && stepData.validation_details.length > 0) {
      console.log('%c📝 검증 결과:', 'font-weight: bold; color: #009688;')
      const warningItems = stepData.validation_details.filter(d => d.status === '확인 필요')
      if (warningItems.length > 0) {
        console.log(`  ⚠️ 확인 필요 항목: ${warningItems.length}개`)
        warningItems.forEach(item => {
          console.log(`    - ${item.item_name || 'ID:' + item.item_id}: ${item.message}`)
        })
      } else {
        console.log('  ✅ 모든 항목 통과')
      }
    }
    
    console.log(`%c상태: ${stepData.status === 'success' ? '통과' : '문제 발견'}`, 
               `color: ${stepData.status === 'success' ? 'green' : 'orange'}; font-weight: bold;`)
    console.groupEnd()
  }
  
  updateValidationStatus(data) {
    // 로컬 스토리지 제거 - DB에서 관리
    
    // 버튼 아래 상태 메시지 업데이트
    const buttonContainer = this.validateButtonTarget.parentElement
    let statusMessage = buttonContainer.querySelector('.validation-status-message')
    
    if (!statusMessage) {
      statusMessage = document.createElement('p')
      statusMessage.className = 'validation-status-message mt-2 text-xs text-center'
      buttonContainer.appendChild(statusMessage)
    }
    
    if (data.all_valid) {
      statusMessage.className = 'validation-status-message mt-2 text-xs text-green-600 text-center'
      statusMessage.innerHTML = `
        <svg class="inline h-4 w-4 mr-1" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
        </svg>
        모든 경비 항목 검증 완료
      `
    } else {
      const warningCount = data.validation_details?.filter(d => d.status === '확인 필요').length || 0
      statusMessage.className = 'validation-status-message mt-2 text-xs text-yellow-600 text-center'
      statusMessage.innerHTML = `
        <svg class="inline h-4 w-4 mr-1" fill="currentColor" viewBox="0 0 20 20">
          <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
        </svg>
        검증 완료 - 확인 필요 항목 ${warningCount}개
      `
    }
  }
  
  connect() {
    console.log("AI Validation controller connected for expense sheet:", this.expenseSheetIdValue)
    
    // 서버에서 검증 이력 로드
    this.loadValidationHistory()
    
    // 최근 검증 단계 상태 표시
    this.displayRecentValidationSteps()
    
    // Turbo Streams 구독 설정 (단계별 진행 상황 수신)
    this.subscribeToValidationUpdates()
  }
  
  showValidationProgress() {
    // 1. 진행 상황 표시 영역 보이기
    const progressContainer = document.getElementById('validation_progress')
    if (progressContainer) {
      progressContainer.classList.remove('hidden')
      
      // 모든 단계를 초기 상태로 리셋 (4단계 포함)
      for (let i = 1; i <= 4; i++) {
        this.updateStepStatus(i, 'waiting')
      }
    }
    
    // 2. 기존 검증 결과 테이블 완전히 숨기기
    const detailsTable = document.getElementById('validation_details_table')
    if (detailsTable) {
      // 즉시 숨기기
      detailsTable.style.display = 'none'
      detailsTable.classList.add('updating')
    }
    
    // 3. 이전 검증 결과 컨테이너 비우기
    if (this.hasResultContainerTarget) {
      const resultContainer = this.resultContainerTarget
      resultContainer.classList.add('hidden')
      resultContainer.innerHTML = ''
    }
  }
  
  updateStepStatus(stepNumber, status, message = null, debugInfo = null) {
    const stepElement = document.getElementById(`validation_step_${stepNumber}`)
    if (!stepElement) return
    
    const iconContainer = stepElement.querySelector('.flex-shrink-0:first-child')
    const statusContainer = document.getElementById(`validation_step_${stepNumber}_status`)
    const messageContainer = document.getElementById(`validation_step_${stepNumber}_message`)
    
    // 아이콘 업데이트
    let iconHtml = ''
    let statusText = ''
    let messageText = message || ''
    
    switch(status) {
      case 'processing':
        iconHtml = `
          <svg class="animate-spin h-5 w-5 text-blue-500" fill="none" viewBox="0 0 24 24">
            <circle class="opacity-25" cx="12" cy="12" r="10" stroke="currentColor" stroke-width="4"></circle>
            <path class="opacity-75" fill="currentColor" d="M4 12a8 8 0 018-8V0C5.373 0 0 5.373 0 12h4zm2 5.291A7.962 7.962 0 014 12H0c0 3.042 1.135 5.824 3 7.938l3-2.647z"></path>
          </svg>
        `
        statusText = '진행중...'
        break
      case 'success':
        iconHtml = `
          <svg class="h-5 w-5 text-green-500" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
          </svg>
        `
        statusText = '통과'
        
        // 3단계 성공 시 특별 메시지
        if (stepNumber === 3 && debugInfo) {
          if (debugInfo.items_reordered) {
            messageText = `${debugInfo.reorder_count || 0}개 항목 재정렬 완료`
          }
          if (debugInfo.items_without_card && debugInfo.items_without_card.length > 0) {
            messageText += `, ${debugInfo.items_without_card.length}개 항목 영수증 필요`
          }
        }
        break
      case 'warning':
        iconHtml = `
          <svg class="h-5 w-5 text-yellow-500" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M8.257 3.099c.765-1.36 2.722-1.36 3.486 0l5.58 9.92c.75 1.334-.213 2.98-1.742 2.98H4.42c-1.53 0-2.493-1.646-1.743-2.98l5.58-9.92zM11 13a1 1 0 11-2 0 1 1 0 012 0zm-1-8a1 1 0 00-1 1v3a1 1 0 002 0V6a1 1 0 00-1-1z" clip-rule="evenodd" />
          </svg>
        `
        statusText = '주의'
        break
      case 'failed':
        iconHtml = `
          <svg class="h-5 w-5 text-red-500" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
          </svg>
        `
        statusText = '문제 발견'
        break
      case 'skipped':
        iconHtml = `
          <svg class="h-5 w-5 text-gray-400" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM7 9a1 1 0 000 2h6a1 1 0 100-2H7z" clip-rule="evenodd" />
          </svg>
        `
        statusText = '건너뜀'
        break
      case 'error':
        iconHtml = `
          <svg class="h-5 w-5 text-red-500" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zM8.707 7.293a1 1 0 00-1.414 1.414L8.586 10l-1.293 1.293a1 1 0 101.414 1.414L10 11.414l1.293 1.293a1 1 0 001.414-1.414L11.414 10l1.293-1.293a1 1 0 00-1.414-1.414L10 8.586 8.707 7.293z" clip-rule="evenodd" />
          </svg>
        `
        statusText = '실패'
        break
      default:
        iconHtml = `
          <svg class="h-5 w-5 text-gray-400" fill="currentColor" viewBox="0 0 20 20">
            <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm0-2a6 6 0 100-12 6 6 0 000 12z" clip-rule="evenodd" />
          </svg>
        `
        statusText = '대기중'
    }
    
    if (iconContainer) iconContainer.innerHTML = iconHtml
    if (statusContainer) {
      statusContainer.textContent = statusText
      statusContainer.className = `text-sm ${
        status === 'success' ? 'text-green-600' :
        status === 'warning' ? 'text-yellow-600' :
        status === 'failed' || status === 'error' ? 'text-red-600' :
        status === 'processing' ? 'text-blue-600' :
        'text-gray-500'
      }`
    }
    
    // 메시지 표시
    if (messageContainer && messageText) {
      messageContainer.textContent = messageText
      messageContainer.classList.remove('hidden')
    }
  }
  
  getStepName(stepNumber) {
    switch(stepNumber) {
      case 1: return '첨부파일 검증'
      case 2: return '통신비 검증'
      case 3: return '항목 순서/금액 검증'
      case 4: return '영수증 첨부 확인'
      default: return `단계 ${stepNumber}`
    }
  }
  
  cleanupAfterValidation() {
    // 1. 검증 상세 테이블 다시 표시
    // 4단계에서 Turbo Stream으로 이미 업데이트되었으므로 display만 복원
    const detailsTable = document.getElementById('validation_details_table')
    if (detailsTable) {
      // display 원복 (새로운 내용은 이미 Turbo Stream으로 업데이트됨)
      detailsTable.style.display = ''
      detailsTable.classList.remove('updating')
      console.log('%c[검증 완료] validation_details_table 표시', 'color: #4CAF50; font-weight: bold;')
    }
    
    // 2. 진행 상황 표시 영역 숨기기 (잠시 후)
    setTimeout(() => {
      const progressContainer = document.getElementById('validation_progress')
      if (progressContainer) {
        // 페이드 아웃 효과
        progressContainer.style.transition = 'opacity 0.5s'
        progressContainer.style.opacity = '0'
        
        setTimeout(() => {
          progressContainer.classList.add('hidden')
          progressContainer.style.opacity = '1'
        }, 500)
      }
    }, 2000) // 2초 후 진행 상황 숨기기
  }
  
  subscribeToValidationUpdates() {
    // Turbo Streams를 통한 실시간 업데이트 수신
    // 서버에서 broadcast_progress로 전송되는 업데이트를 자동으로 받음
  }
  
  async loadValidationHistory() {
    try {
      const response = await fetch(`/expense_sheets/${this.expenseSheetIdValue}/validation_history`, {
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        }
      })
      
      if (response.ok) {
        const histories = await response.json()
        
        if (histories.length > 0) {
          // 최신 검증 결과 표시
          const latest = histories[0]
          this.displayLatestValidation(latest)
          
          // 검증 횟수 표시 (비활성화)
          // this.showHistoryCount(histories.length)
          
          // 기존 검증 횟수 배지 제거
          const buttonContainer = this.validateButtonTarget.parentElement
          const countBadge = buttonContainer.querySelector('.validation-count-badge')
          if (countBadge) {
            countBadge.remove()
          }
          
          // 이력 네비게이션 활성화
          if (histories.length > 1) {
            this.enableHistoryNavigation(histories)
          }
        }
      }
    } catch (error) {
      console.error('검증 이력 로드 실패:', error)
    }
  }
  
  displayLatestValidation(validation) {
    // 최신 검증 결과를 표시
    const data = {
      validation_summary: validation.validation_summary,
      all_valid: validation.all_valid,
      validation_details: validation.validation_details,
      issues_found: validation.issues_found,
      recommendations: validation.recommendations
    }
    
    this.displayResults(data)
    this.updateValidationStatus(data)
    
    // 검증 시간 표시
    const container = this.resultContainerTarget
    if (!container.classList.contains('hidden')) {
      const timeInfo = document.createElement('div')
      timeInfo.className = 'text-xs text-gray-500 mt-2'
      const validatedAt = new Date(validation.created_at)
      timeInfo.textContent = `검증자: ${validation.validated_by} | 검증 시간: ${validatedAt.toLocaleString('ko-KR')}`
      container.appendChild(timeInfo)
    }
  }
  
  showHistoryCount(count) {
    // 검증 횟수를 버튼 근처에 표시
    const buttonContainer = this.validateButtonTarget.parentElement
    let countBadge = buttonContainer.querySelector('.validation-count-badge')
    
    if (!countBadge) {
      countBadge = document.createElement('span')
      countBadge.className = 'validation-count-badge text-xs text-gray-500 ml-2'
      this.validateButtonTarget.parentElement.insertBefore(countBadge, this.validateButtonTarget.nextSibling)
    }
    
    countBadge.textContent = `(검증 ${count}회)`
  }
  
  enableHistoryNavigation(histories) {
    // 이력 간 네비게이션 버튼 추가
    this.histories = histories
    this.currentHistoryIndex = 0
    
    // 네비게이션 버튼 컨테이너 생성
    const navContainer = document.createElement('div')
    navContainer.className = 'flex justify-between items-center mt-2'
    navContainer.innerHTML = `
      <button type="button" 
              data-action="click->ai-validation#showPreviousHistory"
              class="text-sm text-blue-600 hover:text-blue-500 disabled:text-gray-400"
              ${this.currentHistoryIndex >= this.histories.length - 1 ? 'disabled' : ''}>
        ← 이전 검증
      </button>
      <span class="text-xs text-gray-500">
        ${this.currentHistoryIndex + 1} / ${this.histories.length}
      </span>
      <button type="button"
              data-action="click->ai-validation#showNextHistory"
              class="text-sm text-blue-600 hover:text-blue-500 disabled:text-gray-400"
              ${this.currentHistoryIndex <= 0 ? 'disabled' : ''}>
        다음 검증 →
      </button>
    `
    
    this.resultContainerTarget.appendChild(navContainer)
  }
  
  showPreviousHistory(event) {
    event.preventDefault()
    if (this.currentHistoryIndex < this.histories.length - 1) {
      this.currentHistoryIndex++
      this.displayLatestValidation(this.histories[this.currentHistoryIndex])
      this.updateNavigationButtons()
    }
  }
  
  showNextHistory(event) {
    event.preventDefault()
    if (this.currentHistoryIndex > 0) {
      this.currentHistoryIndex--
      this.displayLatestValidation(this.histories[this.currentHistoryIndex])
      this.updateNavigationButtons()
    }
  }
  
  updateNavigationButtons() {
    // 네비게이션 버튼 상태 업데이트
    const navContainer = this.resultContainerTarget.querySelector('.flex.justify-between')
    if (navContainer) {
      navContainer.innerHTML = `
        <button type="button" 
                data-action="click->ai-validation#showPreviousHistory"
                class="text-sm text-blue-600 hover:text-blue-500 disabled:text-gray-400"
                ${this.currentHistoryIndex >= this.histories.length - 1 ? 'disabled' : ''}>
          ← 이전 검증
        </button>
        <span class="text-xs text-gray-500">
          ${this.currentHistoryIndex + 1} / ${this.histories.length}
        </span>
        <button type="button"
                data-action="click->ai-validation#showNextHistory"
                class="text-sm text-blue-600 hover:text-blue-500 disabled:text-gray-400"
                ${this.currentHistoryIndex <= 0 ? 'disabled' : ''}>
          다음 검증 →
        </button>
      `
    }
  }
  
  showNotification(message, type = 'info') {
    // 알림 표시
    const notification = document.createElement('div')
    notification.className = `fixed top-4 right-4 z-50 p-4 rounded-lg shadow-lg ${
      type === 'success' ? 'bg-green-500 text-white' : 
      type === 'error' ? 'bg-red-500 text-white' : 
      'bg-blue-500 text-white'
    }`
    notification.innerHTML = `
      <div class="flex items-center">
        <svg class="h-5 w-5 mr-2" fill="currentColor" viewBox="0 0 20 20">
          ${type === 'success' ? 
            '<path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />' :
            '<path fill-rule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7-4a1 1 0 11-2 0 1 1 0 012 0zM9 9a1 1 0 000 2v3a1 1 0 001 1h1a1 1 0 100-2v-3a1 1 0 00-1-1H9z" clip-rule="evenodd" />'
          }
        </svg>
        <span>${message}</span>
      </div>
    `
    
    document.body.appendChild(notification)
    
    // 3초 후 자동으로 제거
    setTimeout(() => {
      notification.style.opacity = '0'
      notification.style.transition = 'opacity 0.5s'
      setTimeout(() => notification.remove(), 500)
    }, 3000)
  }
  
  async displayRecentValidationSteps() {
    try {
      // 최근 검증 이력 가져오기
      const response = await fetch(`/expense_sheets/${this.expenseSheetIdValue}/validation_history`, {
        headers: {
          'Content-Type': 'application/json',
          'X-CSRF-Token': document.querySelector('meta[name="csrf-token"]').content
        }
      })
      
      if (response.ok) {
        const histories = await response.json()
        
        if (histories.length > 0) {
          const latest = histories[0]
          
          // validation_details에 steps 정보가 있으면 표시
          if (latest.validation_details && latest.validation_details.steps) {
            const steps = latest.validation_details.steps
            
            // 검증 진행 상황 영역 표시
            const progressContainer = document.getElementById('validation_progress')
            if (progressContainer) {
              progressContainer.classList.remove('hidden')
              
              // 각 단계별 상태 업데이트
              for (let i = 1; i <= 3; i++) {
                const stepData = steps[`step_${i}`]
                if (stepData) {
                  const status = stepData.status === 'success' ? 'success' : 
                                stepData.status === 'warning' ? 'warning' : 
                                'completed'
                  this.updateStepStatus(i, status)
                }
              }
              
              // 검증 완료 시간 표시
              const summaryDiv = document.getElementById('validation_summary')
              if (summaryDiv && latest.created_at) {
                const validatedAt = new Date(latest.created_at)
                const timeAgo = this.getTimeAgo(validatedAt)
                summaryDiv.classList.remove('hidden')
                summaryDiv.innerHTML = `
                  <div class="p-3 bg-white rounded-lg border">
                    <p class="text-sm text-gray-600">
                      <svg class="inline h-4 w-4 mr-1 text-green-500" fill="currentColor" viewBox="0 0 20 20">
                        <path fill-rule="evenodd" d="M10 18a8 8 0 100-16 8 8 0 000 16zm3.707-9.293a1 1 0 00-1.414-1.414L9 10.586 7.707 9.293a1 1 0 00-1.414 1.414l2 2a1 1 0 001.414 0l4-4z" clip-rule="evenodd" />
                      </svg>
                      마지막 검증: ${timeAgo} (${latest.validated_by})
                    </p>
                  </div>
                `
              }
            }
          }
        }
      }
    } catch (error) {
      console.error('최근 검증 단계 표시 중 오류:', error)
    }
  }
  
  getTimeAgo(date) {
    const seconds = Math.floor((new Date() - date) / 1000)
    
    if (seconds < 60) return '방금 전'
    if (seconds < 3600) return `${Math.floor(seconds / 60)}분 전`
    if (seconds < 86400) return `${Math.floor(seconds / 3600)}시간 전`
    if (seconds < 604800) return `${Math.floor(seconds / 86400)}일 전`
    
    return date.toLocaleString('ko-KR')
  }
}