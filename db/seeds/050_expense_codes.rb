# 경비 코드 생성
puts '경비 코드 생성 중...'

# 경비 코드와 승인 규칙 데이터
expense_codes_data = [
  {
    code: 'OTME',
    name: '초과근무 식대',
    description: '소정근로시간 이후 초과근무 필요 시의 식대',
    active: true,
    attachment_required: false,
    limit_amount: '#참석자 * 15000',
    description_template: '야근식대 (#참석자)_#사유',
    validation_rules: {
      "required_fields" => {
        "참석자" => {"label" => "참석자", "type" => "participants", "required" => true, "order" => 0},
        "사유" => {"label" => "사유", "type" => "text", "required" => true, "order" => 1}
      }
    },
    approval_rules: [
      {group_name: '조직리더', condition: '#금액 >= 0', order: 1},
      {group_name: '보직자', condition: '#금액 >= 0', order: 2}
    ]
  },
  {
    code: 'CARM',
    name: '차량유지비',
    description: '차량유지비 (통행료, 주차비)',
    active: true,
    attachment_required: false,
    limit_amount: nil,
    description_template: '#이동사유 (#출발지→#도착지, #거리km)',
    validation_rules: {
      "required_fields" => {
        "이동사유" => {"label" => "이동사유", "type" => "text", "required" => true, "order" => 0},
        "출발지" => {"label" => "출발지", "type" => "text", "required" => true, "order" => 1},
        "도착지" => {"label" => "도착지", "type" => "text", "required" => true, "order" => 2},
        "거리km" => {"label" => "거리km", "type" => "text", "required" => true, "order" => 3}
      }
    },
    approval_rules: [
      {group_name: '조직리더', condition: '#금액 >= 0', order: 1},
      {group_name: '보직자', condition: '#금액 >= 0', order: 2}
    ]
  },
  {
    code: 'TRNS',
    name: '교통비',
    description: '교통비',
    active: true,
    attachment_required: false,
    limit_amount: nil,
    description_template: '#이동수단 (#출발지→#도착지)_#이동사유',
    validation_rules: {
      "required_fields" => {
        "이동수단" => {"label" => "이동수단", "type" => "select", "required" => true, "order" => 0, "options" => ["택시", "버스", "지하철", "기차", "항공", "자가용"]},
        "출발지" => {"label" => "출발지", "type" => "text", "required" => true, "order" => 1},
        "도착지" => {"label" => "도착지", "type" => "text", "required" => true, "order" => 2},
        "이동사유" => {"label" => "이동사유", "type" => "text", "required" => true, "order" => 3}
      }
    },
    approval_rules: [
      {group_name: '조직리더', condition: '#금액 >= 0', order: 1},
      {group_name: '보직자', condition: '#금액 >= 0', order: 2}
    ]
  },
  {
    code: 'BOOK',
    name: '도서인쇄비',
    description: '업무 관련 도서 구입비',
    active: true,
    attachment_required: false,
    limit_amount: nil,
    description_template: '#사용내용_#사용목적',
    validation_rules: {
      "required_fields" => {
        "사용내용" => {"label" => "사용내용", "type" => "text", "required" => true, "order" => 0},
        "구매목적" => {"label" => "사용목적", "type" => "text", "required" => true, "order" => 1}
      }
    },
    approval_rules: [
      {group_name: '조직리더', condition: '#금액 >= 0', order: 1},
      {group_name: '보직자', condition: '#금액 >= 0', order: 2}
    ]
  },
  {
    code: 'STAT',
    name: '사무용품/소모품비',
    description: '사무용품/소모품비',
    active: true,
    attachment_required: false,
    limit_amount: nil,
    description_template: '#품목_#구매목적',
    validation_rules: {
      "required_fields" => {
        "품목" => {"label" => "품목", "type" => "text", "required" => true, "order" => 0},
        "구매목적" => {"label" => "구매목적", "type" => "text", "required" => true, "order" => 1}
      }
    },
    approval_rules: [
      {group_name: '조직리더', condition: '#금액 >= 0', order: 1},
      {group_name: '보직자', condition: '#금액 >= 0', order: 2}
    ]
  },
  {
    code: 'DINE',
    name: '회식비',
    description: "팀 회식 및 단합 행사비 (영수증 필수)\n- 30만원 미만 보직자 → 조직리더 → 조직총괄\n- 30만원 이상 보직자 → 조직리더 → 조직총괄 → CEO",
    active: true,
    attachment_required: true,
    limit_amount: nil,
    description_template: '회식 (#구성원)_#사유',
    validation_rules: {
      "required_fields" => {
        "구성원" => {"label" => "구성원", "type" => "participants", "required" => true, "order" => 0},
        "사유" => {"label" => "사유", "type" => "text", "required" => true, "order" => 1}
      }
    },
    approval_rules: [
      {group_name: 'CEO', condition: '#금액 >= 300000', order: 1},
      {group_name: '조직총괄', condition: '#금액 >= 0', order: 2},
      {group_name: '조직리더', condition: '#금액 >= 0', order: 3},
      {group_name: '보직자', condition: '#금액 >= 0', order: 4}
    ]
  },
  {
    code: 'ENTN',
    name: '접대비',
    description: "고객 접대 및 미팅비 (영수증 필수)\n- 30만원 미만 보직자 → 조직리더 → 조직총괄\n- 30만원 이상 보직자 → 조직리더 → 조직총괄 → CEO",
    active: true,
    attachment_required: true,
    limit_amount: nil,
    description_template: '접대비 (#참석자)_#사유',
    validation_rules: {
      "required_fields" => {
        "참석자" => {"label" => "참석자", "type" => "participants", "required" => true, "order" => 0},
        "사유" => {"label" => "사유", "type" => "text", "required" => true, "order" => 1}
      }
    },
    approval_rules: [
      {group_name: 'CEO', condition: '#금액 >= 300000', order: 1},
      {group_name: '조직총괄', condition: '#금액 >= 0', order: 2},
      {group_name: '조직리더', condition: '#금액 >= 0', order: 3},
      {group_name: '보직자', condition: '#금액 >= 0', order: 4}
    ]
  },
  {
    code: 'EQUM',
    name: '기기/비품비',
    description: "IT 기기 및 사무 비품 구입비\n- 30만원 미만: 보직자 → 조직리더 → 조직총괄\n- 30만원 이상: 보직자 → 조직리더 → 조직총괄 → CEO",
    active: true,
    attachment_required: false,
    limit_amount: nil,
    description_template: '#품목_#사용처',
    validation_rules: {
      "required_fields" => {
        "품목" => {"label" => "품목", "type" => "text", "required" => true, "order" => 0},
        "사용처" => {"label" => "사용처", "type" => "text", "required" => true, "order" => 1}
      }
    },
    approval_rules: [
      {group_name: 'CEO', condition: '#금액 >= 300000', order: 1},
      {group_name: '조직총괄', condition: '#금액 >= 0', order: 2},
      {group_name: '조직리더', condition: '#금액 >= 0', order: 3},
      {group_name: '보직자', condition: '#금액 >= 0', order: 4}
    ]
  },
  {
    code: 'PHON',
    name: '통신비',
    description: "업무용 휴대폰 요금 (청구서 필수)\n- 4만원 이하: 자동 승인\n- 4만원 초과: 조직리더 승인 (세일즈 등 특수 직무만 가능)",
    active: true,
    attachment_required: true,
    limit_amount: nil,
    description_template: '통신비',
    validation_rules: {
      "required_fields" => {}
    },
    approval_rules: [
      {group_name: '조직리더', condition: '#금액 > 40000', order: 1}
    ]
  },
  {
    code: 'PETE',
    name: '잡비',
    description: '기타 업무 관련 잡비',
    active: true,
    attachment_required: false,
    limit_amount: nil,
    description_template: '#내역_#사유',
    validation_rules: {
      "required_fields" => {
        "내역" => {"label" => "내역", "type" => "text", "required" => true, "order" => 0},
        "사유" => {"label" => "사유", "type" => "text", "required" => true, "order" => 1}
      }
    },
    approval_rules: [
      {group_name: '보직자', condition: '#금액 >= 0', order: 1},
      {group_name: '조직리더', condition: '#금액 >= 0', order: 2}
    ]
  }
]

# 경비 코드 생성
expense_codes_data.each do |code_data|
  expense_code = ExpenseCode.find_or_create_by!(code: code_data[:code], version: 1) do |ec|
    ec.name = code_data[:name]
    ec.description = code_data[:description]
    ec.active = code_data[:active]
    ec.attachment_required = code_data[:attachment_required]
    ec.limit_amount = code_data[:limit_amount]
    ec.description_template = code_data[:description_template]
    ec.validation_rules = code_data[:validation_rules]
    ec.is_current = true
    ec.effective_from = Date.current
  end
  
  # 승인 규칙이 없는 경우에만 생성
  if expense_code.expense_code_approval_rules.empty? && code_data[:approval_rules].present?
    code_data[:approval_rules].each do |rule_data|
      # ApproverGroup은 005_approver_groups.rb에서 생성되므로 여기서는 참조만
      group = ApproverGroup.find_by(name: rule_data[:group_name])
      
      if group
        ExpenseCodeApprovalRule.create!(
          expense_code: expense_code,
          approver_group: group,
          condition: rule_data[:condition],
          order: rule_data[:order],
          is_active: true
        )
      else
        puts "  경고: 승인자 그룹 '#{rule_data[:group_name]}'을 찾을 수 없습니다."
      end
    end
  end
end

puts "경비 코드 #{ExpenseCode.count}개 생성 완료!"
puts "승인 규칙 #{ExpenseCodeApprovalRule.count}개 생성 완료!"