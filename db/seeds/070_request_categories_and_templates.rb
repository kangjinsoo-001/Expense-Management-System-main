puts "Creating request categories and templates..."

# 정보보안 카테고리 생성
category = RequestCategory.find_or_create_by!(name: "정보보안") do |c|
  c.description = "정보보안 정책, 접근 권한, 보안 인증 관련 신청"
  c.is_active = true
  c.display_order = 1
end
puts "  Created category: #{category.name}"

# 승인자 그룹 가져오기
approver_groups = ApproverGroup.all.index_by(&:name)

# 템플릿 정의
templates = [
  {
    name: "사용자 계정 신청서",
    description: "시스템 사용자 계정 신청",
    fields: [
      { key: "application_type", label: "신청구분", type: "select", required: true, options: ["신규", "변경", "삭제"] },
      { key: "target_user", label: "대상자", type: "text", required: true },
      { key: "email", label: "이메일", type: "email", required: true },
      { key: "start_date", label: "사용시작일", type: "date", required: true },
      { key: "end_date", label: "사용종료일", type: "date", required: true },
      { key: "usage_purpose", label: "사용목적", type: "select", required: true, options: ["업무용", "테스트용", "임시사용", "기타"] },
      { key: "requested_services", label: "요청서비스 및 권한", type: "textarea", required: true },
      { key: "remarks", label: "비고", type: "textarea", required: false },
      { key: "attachment", label: "관련파일", type: "file", required: false }
    ]
  },
  {
    name: "VPN 계정 신청서",
    description: "VPN 접속 계정 신청",
    fields: [
      { key: "application_type", label: "신청구분", type: "select", required: true, options: ["신규", "변경", "삭제"] },
      { key: "target_user", label: "대상자", type: "text", required: true },
      { key: "email", label: "이메일", type: "email", required: true },
      { key: "start_date", label: "사용시작일", type: "date", required: true },
      { key: "end_date", label: "사용종료일", type: "date", required: true },
      { key: "applicant_type", label: "사용신청자", type: "select", required: true, options: ["직원", "협력사", "고객사", "기타"] },
      { key: "usage_purpose", label: "사용목적", type: "textarea", required: true },
      { key: "remarks", label: "비고", type: "textarea", required: false },
      { key: "attachment", label: "관련파일", type: "file", required: false }
    ]
  },
  {
    name: "프로그램 배포 계획서",
    description: "프로그램 배포 계획 신청",
    fields: [
      { key: "deployment_date", label: "배포일", type: "date", required: true },
      { key: "deployment_time", label: "배포시간", type: "text", required: true },
      { key: "service_name", label: "서비스명", type: "select", required: true, options: ["주요서비스", "부가서비스", "관리시스템", "기타"] },
      { key: "deployment_type", label: "구분", type: "select", required: true, options: ["정기배포", "긴급배포", "핫픽스", "롤백"] },
      { key: "target_systems", label: "배포대상시스템", type: "textarea", required: false },
      { key: "work_summary", label: "작업계획요약", type: "textarea", required: false },
      { key: "remarks", label: "비고", type: "textarea", required: false },
      { key: "attachment", label: "관련파일", type: "file", required: false }
    ]
  },
  {
    name: "프로그램 배포 결과서",
    description: "프로그램 배포 결과 보고",
    fields: [
      { key: "deployment_date", label: "배포일", type: "date", required: true },
      { key: "start_time", label: "배포시작시간", type: "text", required: true },
      { key: "end_time", label: "배포완료시간", type: "text", required: true },
      { key: "service_name", label: "서비스명", type: "select", required: true, options: ["주요서비스", "부가서비스", "관리시스템", "기타"] },
      { key: "deployment_type", label: "구분", type: "select", required: true, options: ["정기배포", "긴급배포", "핫픽스", "롤백"] },
      { key: "remarks", label: "비고", type: "textarea", required: false },
      { key: "attachment", label: "관련파일", type: "file", required: false }
    ]
  },
  {
    name: "보안정책 예외 신청서",
    description: "보안정책 예외 처리 신청",
    fields: [
      { key: "exception_item", label: "예외 신청 항목", type: "select", required: true, options: ["USB 사용", "외부 네트워크 접속", "소프트웨어 설치", "기타"] },
      { key: "exception_reason", label: "예외 신청 사유", type: "textarea", required: true },
      { key: "expiry_date", label: "예외 신청 만료일", type: "date", required: true },
      { key: "other_item", label: "기타 항목", type: "text", required: false },
      { key: "attachment", label: "관련파일", type: "file", required: false }
    ]
  },
  {
    name: "차단된 웹페이지 해제 신청서",
    description: "차단된 웹페이지 접속 해제 신청",
    fields: [
      { key: "blocked_url", label: "해제 요청 URL", type: "textarea", required: true },
      { key: "unblock_reason", label: "해제 요청 사유", type: "textarea", required: true },
      { key: "attachment", label: "관련파일", type: "file", required: false }
    ]
  },
  {
    name: "방화벽 정책 변경 신청서",
    description: "방화벽 정책 변경 요청",
    fields: [
      { key: "application_type", label: "신청 구분", type: "select", required: true, options: ["신규", "변경", "삭제"] },
      { key: "source_info", label: "출발지 정보", type: "text", required: true },
      { key: "destination_info", label: "도착지 정보", type: "text", required: true },
      { key: "port_info", label: "포트정보", type: "text", required: true },
      { key: "request_reason", label: "신청 사유", type: "text", required: true },
      { key: "apply_date", label: "정책 적용일", type: "date", required: true },
      { key: "expiry_date", label: "정책 만료일", type: "date", required: true },
      { key: "attachment", label: "관련파일", type: "file", required: false }
    ]
  },
  {
    name: "고객사 자료 전송 신청서",
    description: "고객사 자료 전송 승인 신청",
    fields: [
      { key: "customer_name", label: "고객사명", type: "text", required: true },
      { key: "data_type", label: "자료 종류", type: "text", required: true, placeholder: "ex. 영업정산 데이터, 금전정보 등" },
      { key: "download_method", label: "자료 다운로드 방식", type: "text", required: true, placeholder: "ex. Tool을 통한 export 등" },
      { key: "attachment", label: "관련파일", type: "file", required: false }
    ]
  },
  {
    name: "보안성 검토 결과 보고서",
    description: "시스템 보안성 검토 결과 보고",
    fields: [
      { key: "system_name", label: "시스템명", type: "text", required: true },
      { key: "review_date", label: "검토일자", type: "date", required: true },
      { key: "handover_person", label: "인계자", type: "text", required: true },
      { key: "takeover_person", label: "인수자", type: "text", required: true },
      { key: "review_opinion", label: "검토종합의견", type: "textarea", required: false },
      { key: "remarks", label: "비고", type: "textarea", required: false },
      { key: "attachment", label: "관련파일", type: "file", required: false }
    ]
  },
  {
    name: "작업계획서",
    description: "시스템 작업 계획서",
    fields: [
      { key: "work_name", label: "작업명", type: "text", required: true },
      { key: "work_date", label: "작업일", type: "date", required: true },
      { key: "work_time", label: "작업시간", type: "text", required: true },
      { key: "work_location", label: "작업위치", type: "select", required: true, options: ["본사", "원격", "데이터센터", "고객사"] },
      { key: "risk_level", label: "위험도", type: "select", required: true, options: ["상", "중", "하"] },
      { key: "urgency", label: "긴급여부", type: "select", required: true, options: ["긴급", "일반"] },
      { key: "work_purpose", label: "작업목적 및 내용", type: "textarea", required: true },
      { key: "end_date", label: "종료예정일", type: "date", required: false },
      { key: "remarks", label: "비고", type: "textarea", required: false },
      { key: "attachment", label: "관련파일", type: "file", required: false }
    ]
  },
  {
    name: "시험데이터 사용 신청서",
    description: "시험데이터 사용 승인 신청",
    fields: [
      { key: "start_date", label: "시험데이터사용시작일", type: "date", required: true },
      { key: "expiry_date", label: "시험데이터만기일", type: "date", required: true },
      { key: "usage_purpose", label: "사용목적", type: "text", required: true },
      { key: "request_content", label: "신청내용", type: "textarea", required: true },
      { key: "attachment", label: "관련파일", type: "file", required: false }
    ]
  },
  {
    name: "개인정보 파기 확인서",
    description: "개인정보 파기 처리 확인서",
    fields: [
      { key: "target_info", label: "파기 대상 개인정보", type: "text", required: true },
      { key: "subject_count", label: "개인정보의 정보주체 수", type: "text", required: true },
      { key: "destruction_reason", label: "파기사유", type: "text", required: true },
      { key: "destruction_date", label: "파기일자", type: "date", required: true },
      { key: "processor", label: "파기 처리자", type: "text", required: true },
      { key: "witness", label: "파기 입회자", type: "text", required: true },
      { key: "destruction_info", label: "파기정보", type: "text", required: true },
      { key: "destruction_method", label: "파기 방법", type: "text", required: true },
      { key: "backup_status", label: "백업 조치 유무", type: "text", required: true },
      { key: "special_notes", label: "특이사항", type: "textarea", required: false },
      { key: "attachment", label: "관련파일", type: "file", required: false }
    ]
  }
]

# 템플릿 및 필드 생성
templates.each_with_index do |template_data, index|
  template = RequestTemplate.find_or_create_by!(
    name: template_data[:name],
    request_category: category
  ) do |t|
    t.description = template_data[:description]
    t.is_active = true
    t.display_order = index + 1
  end
  puts "  Created template: #{template.name}"

  # 템플릿 필드 생성
  template_data[:fields].each_with_index do |field_data, field_index|
    field = RequestTemplateField.find_or_create_by!(
      request_template: template,
      field_key: field_data[:key]
    ) do |f|
      f.field_label = field_data[:label]
      f.field_type = field_data[:type]
      f.is_required = field_data[:required]
      f.display_order = field_index + 1
      f.placeholder = field_data[:placeholder] if field_data[:placeholder]
      
      # select 타입의 경우 옵션 설정
      if field_data[:type] == "select" && field_data[:options]
        f.field_options = { "options" => field_data[:options] }
      end
    end
    puts "    Added field: #{field.field_label} (#{field.field_type})"
  end

  # 승인 규칙 생성 (보직자, 조직리더)
  if approver_groups["보직자"]
    RequestTemplateApprovalRule.find_or_create_by!(
      request_template: template,
      approver_group: approver_groups["보직자"]
    ) do |rule|
      rule.condition = "always"
      rule.order = 1
      rule.is_active = true
    end
    puts "    Added approval rule: 보직자"
  end

  if approver_groups["조직리더"]
    RequestTemplateApprovalRule.find_or_create_by!(
      request_template: template,
      approver_group: approver_groups["조직리더"]
    ) do |rule|
      rule.condition = "always"
      rule.order = 2
      rule.is_active = true
    end
    puts "    Added approval rule: 조직리더"
  end
end

puts "Request categories and templates creation completed!"
puts "Total categories: #{RequestCategory.count}"
puts "Total templates: #{RequestTemplate.count}"
puts "Total fields: #{RequestTemplateField.count}"
puts "Total approval rules: #{RequestTemplateApprovalRule.count}"