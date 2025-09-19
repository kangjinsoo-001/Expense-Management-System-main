# 첨부파일 요구사항 시드 데이터

puts "Creating attachment requirements..."

# 경비 시트용 첨부파일 요구사항 - 법인카드 명세서
sheet_requirements = [
  {
    name: "법인카드 명세서",
    description: "법인카드 이용 명세서 (최대 10MB)",
    file_types: ["pdf", "jpg", "jpeg", "png"],
    required: false,  # 개발/테스트 환경에서는 선택사항으로 설정
    active: true,
    position: 1,
    attachment_type: 'expense_sheet',
    condition_expression: nil
  }
]

# 경비 항목용 첨부파일 요구사항 - 통합 영수증 분석
item_requirements = [
  {
    name: "영수증",
    description: "모든 종류의 영수증 및 문서 AI 분석 (통신비, 일반 영수증, 기타 문서)",
    file_types: ["pdf", "jpg", "jpeg", "png"],
    required: false,
    active: true,
    position: 1,
    attachment_type: 'expense_item',
    condition_expression: nil
  }
]

# 모든 요구사항 결합
requirements = sheet_requirements + item_requirements

requirements.each do |req_data|
  requirement = AttachmentRequirement.find_or_create_by(
    name: req_data[:name],
    attachment_type: req_data[:attachment_type]
  ) do |req|
    req.description = req_data[:description]
    req.file_types = req_data[:file_types]
    req.required = req_data[:required]
    req.active = req_data[:active]
    req.position = req_data[:position]
    req.condition_expression = req_data[:condition_expression]
  end

  # 기존 레코드가 있어도 업데이트
  if requirement.persisted? || requirement.save
    puts "  Created/Updated requirement: #{requirement.name}"
    
    # AI 분석 규칙 추가
    case requirement.name
    when "법인카드 명세서"
      # 기존 규칙이 있으면 먼저 찾기
      analysis_rule = AttachmentAnalysisRule.find_or_initialize_by(
        attachment_requirement: requirement
      )
      
      # 법인카드 명세서 분석 프롬프트 (비즈니스 로직)
      analysis_rule.prompt_text = <<~PROMPT
        법인카드 명세서 PDF를 분석하여 카드 이용 내역을 추출하세요.

        분석 범위:
        - "카드 이용 내역" 섹션만 추출
        - "해외이용내역 상세 안내" 등 추가 정보는 제외

        테이블 구조:
        | 이용일자 | 이용가맹점 | 원금 | 수수료 | 합계 |

        각 거래별 계산:
        - 합계 = 원금 + 수수료 (명세서에 없으므로 직접 계산)

        JSON 구조:
        {
          "transactions": [
            {
              "date": "MM/DD",
              "merchant": "가맹점명",
              "amount": 원금(숫자),
              "fee": 수수료(숫자),
              "total": 합계(숫자)
            }
          ],
          "total_amount": 전체_총액(숫자),
          "total_fee": 전체_수수료(숫자)
        }

        추출 규칙:
        1. 모든 거래 내역을 빠짐없이 추출
        2. 금액은 숫자만 (콤마, 원 제외)
        3. 가맹점명이 여러 줄에 걸쳐 있으면 합쳐서 처리
      PROMPT
      
      analysis_rule.expected_fields = {
        "transactions" => "array"
      }
      analysis_rule.active = true
      analysis_rule.save!
      
    when "영수증"
      # 기존 규칙이 있으면 먼저 찾기
      analysis_rule = AttachmentAnalysisRule.find_or_initialize_by(
        attachment_requirement: requirement
      )
      
      # 영수증 분석 프롬프트 (비즈니스 로직)
      analysis_rule.prompt_text = <<~PROMPT
        다음 문서를 분석하여 정보를 추출하세요.
        
        1단계: 문서 유형 분류
        - telecom: 통신비 청구서 (SKT, KT, LG U+, 알뜰폰 등)
        - general: 일반 영수증 (식당, 카페, 쇼핑, 교통 등)
        - unknown: 분류 불가능
        
        2단계: 유형에 따른 데이터 추출
        
        통신비(telecom)인 경우:
        
        **중요: 데이터 추출 및 부가세 처리 규칙**
        1. 먼저 영수증의 모든 요금 항목을 그대로 추출
        2. 영수증에 "부가세", "VAT", "부가가치세"가 별도로 표시되어 있는지 확인
        3. 부가세 처리 후 최종 JSON 생성:
           - 기타 요금이 통신 서비스 요금의 약 10% (9~11%)인 경우:
             → 부가세로 판단하고 service_charge에 합산
             → other_charges는 0으로 설정
           - 그 외의 경우 기타 요금은 그대로 유지
        
        예시: 
        - 영수증: "통신비 28,200원 + 기타 2,820원 + 할인 -31,700원 = 31,020원"
        - 올바른 분류: service_charge: 31020 (28200+2820), other_charges: 0
        
        {
          "type": "telecom",
          "data": {
            "total_amount": 실제 청구 금액 (할인 적용 후 최종 금액),
            "service_charge": 통신 서비스 요금 (부가세가 별도면 합산한 금액),
            "additional_service_charge": 부가 서비스 요금 (부가세 포함),
            "device_installment": 단말기 할부금 (부가세 포함),
            "other_charges": 기타 요금 (부가세로 판단되지 않은 실제 기타 요금만),
            "discount_amount": 할인 금액 (양수로 표시)
          }
        }
        
        **최종 검증**: 
        - 추출 후 기타 요금이 통신비의 약 10%면 부가세로 처리
        - total_amount = service_charge + additional_service_charge + device_installment + other_charges - discount_amount
        - 계산 결과가 실제 청구 금액과 일치하는지 확인
        
        일반 영수증(general)인 경우:
        {
          "type": "general",
          "data": {
            "store_name": "상호명",
            "location": "주소",
            "total_amount": 숫자값,
            "date": "YYYY-MM-DD",
            "items": [{"name": "품목명", "amount": 숫자값}]
          }
        }
        
        분류 불가(unknown)인 경우:
        {
          "type": "unknown",
          "data": {
            "summary_text": "100자 이내 요약"
          }
        }
        
        중요 규칙:
        - 금액은 숫자값만 (원, 쉼표 제외)
        - 할인 금액은 양수로 표시
        - 통신비의 경우 부가세 확인: 기타 요금이 다른 요금의 정확히 10%인 경우 부가세로 처리
        - 통신비 계산: total_amount = service_charge + additional_service_charge + device_installment + other_charges - discount_amount
      PROMPT
      
      # 모든 가능한 필드를 포함한 예상 필드 설정
      analysis_rule.expected_fields = {
        "type" => "string",
        # 통신비 관련 필드
        "total_amount" => "number",
        "service_charge" => "number",
        "additional_service_charge" => "number",
        "device_installment" => "number",
        "other_charges" => "number",
        "discount_amount" => "number",
        # 일반 영수증 관련 필드
        "store_name" => "string",
        "location" => "string",
        "date" => "date",
        "items" => "array",
        # 분류 불가 관련 필드
        "summary_text" => "string"
      }
      analysis_rule.active = true
      analysis_rule.save!
    end

    # 검증 규칙 추가
    case requirement.name
    when "법인카드 명세서"
      # 통신비 검증 규칙
      AttachmentValidationRule.find_or_create_by(
        attachment_requirement: requirement,
        rule_type: "telecom_check",
        prompt_text: "날짜가 일치하는지는 검증할 필요 없음. 통신비는 최상단 위치 1번에 배치. 통신비 항목이 경비 시트 내에 없으면 \"주의\". 법인카드 명세서에는 통신비에 해당하는 내용이 없어도 됨."
      ) do |rule|
        rule.severity = "warning"
        rule.position = 1
        rule.active = true
      end
      
      # 순서 매칭 규칙
      AttachmentValidationRule.find_or_create_by(
        attachment_requirement: requirement,
        rule_type: "order_match",
        prompt_text: "날짜가 일치하는지는 검증할 필요 없음. 입력 순서만 검증하면 됨. 통신비는 최상단 위치 1번에 배치. 법인카드 명세서에 없는 경비 시트 항목은 하단에 배치되어야 함 (순서 검증 필요 없음). 법인카드 명세서에 있는 경비 시트 항목은 법인카드 명세서의 순서와 경비 시트 입력 순서가 일치해야 함. (단, 통신비로 인해 1줄씩 밀린 순서는 허용)"
      ) do |rule|
        rule.severity = "warning"
        rule.position = 2
        rule.active = true
      end
      
      # 존재 여부 검증 규칙
      AttachmentValidationRule.find_or_create_by(
        attachment_requirement: requirement,
        rule_type: "existence_check",
        prompt_text: "날짜가 일치하는지는 검증할 필요 없음. 법인카드 명세서에는 통신비에 해당하는 내용이 없어도 됨. 법인카드 명세서에 없는데 경비 시트에 있다면 영수증 필수 \"경고\". 법인카드 명세서에 있는데 경비 시트에 없으면 \"확인 필요\"로 \"주의\"."
      ) do |rule|
        rule.severity = "warning"
        rule.position = 3
        rule.active = true
      end
      
      # 금액 매칭 규칙
      AttachmentValidationRule.find_or_create_by(
        attachment_requirement: requirement,
        rule_type: "amount_match",
        prompt_text: "날짜가 일치하는지는 검증할 필요 없음. 경비 시트의 입력 항목별 \"경비 시트 금액 > 법인카드 명세서 금액\"보다 크면 \"경고\"."
      ) do |rule|
        rule.severity = "error"
        rule.position = 4
        rule.active = true
      end
      
    when "영수증"
      AttachmentValidationRule.find_or_create_by(
        attachment_requirement: requirement,
        rule_type: "classification",
        prompt_text: "영수증 유형 분류 확인"
      ) do |rule|
        rule.severity = "warning"
        rule.position = 1
        rule.active = true
      end
      
      AttachmentValidationRule.find_or_create_by(
        attachment_requirement: requirement,
        rule_type: "amount_validation",
        prompt_text: "영수증 금액 유효성 검증"
      ) do |rule|
        rule.severity = "error"
        rule.position = 2
        rule.active = true
      end
      
      AttachmentValidationRule.find_or_create_by(
        attachment_requirement: requirement,
        rule_type: "data_completeness",
        prompt_text: "필수 데이터 추출 완료 확인"
      ) do |rule|
        rule.severity = "info"
        rule.position = 3
        rule.active = true
      end
    end
  end
end

puts "Attachment requirements created successfully!"
puts "  Total requirements: #{AttachmentRequirement.count}"
puts "  Total analysis rules: #{AttachmentAnalysisRule.count}"
puts "  Total validation rules: #{AttachmentValidationRule.count}"