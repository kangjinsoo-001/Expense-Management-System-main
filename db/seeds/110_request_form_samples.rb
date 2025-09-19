puts "Creating sample request forms..."

# 사용자 조회
choi = User.find_by(name: "최효진")
kim_b = User.find_by(name: "김보군")
moon = User.find_by(name: "문선주")
kim_k = User.find_by(name: "김경현")
yoo = User.find_by(name: "유천호")

# 템플릿 조회
templates = RequestTemplate.all.index_by(&:name)

# 결재선 조회 (최효진이 승인자로 포함된 것 찾기)
approval_lines_with_choi = ApprovalLine.joins(:approval_line_steps)
                                       .where(approval_line_steps: { approver_id: choi.id })
                                       .distinct

# 최효진이 포함된 결재선이 없으면 생성
if approval_lines_with_choi.empty?
  puts "  Creating approval line with 최효진..."
  approval_line = ApprovalLine.new(
    name: "정보보안 승인 라인",
    user_id: choi.id,
    is_active: true
  )
  
  # 결재선 단계를 먼저 빌드
  approval_line.approval_line_steps.build(
    step_order: 1,
    approver: choi,
    role: "approve",
    approval_type: "all_required"
  )
  
  # 단계와 함께 저장
  approval_line.save!
  
  approval_lines_with_choi = [approval_line]
end

# 신청서 샘플 데이터
request_forms_data = [
  {
    user: kim_b,
    template: templates["VPN 계정 신청서"],
    status: "pending",
    data: {
      application_type: "신규",
      target_user: "김보군",
      email: "kim.b@tlx.kr",
      start_date: Date.today.to_s,
      end_date: (Date.today + 90.days).to_s,
      applicant_type: "직원",
      usage_purpose: "재택근무를 위한 VPN 접속 권한 필요",
      remarks: "코로나19 재택근무 대응"
    }
  },
  {
    user: moon,
    template: templates["사용자 계정 신청서"],
    status: "pending",
    data: {
      application_type: "신규",
      target_user: "신입사원 3명",
      email: "newbies@tlx.kr",
      start_date: (Date.today + 7.days).to_s,
      end_date: (Date.today + 365.days).to_s,
      usage_purpose: "업무용",
      requested_services: "이메일, 그룹웨어, ERP 시스템 접근 권한",
      remarks: "2025년 1월 신입사원 입사 예정"
    }
  },
  {
    user: kim_k,
    template: templates["시험데이터 사용 신청서"],
    status: "pending",
    data: {
      start_date: Date.today.to_s,
      expiry_date: (Date.today + 30.days).to_s,
      usage_purpose: "신규 기능 개발 테스트",
      request_content: "고객사 데이터 마스킹 처리된 테스트 DB 사용 요청\n- 테스트 서버: dev-test-01\n- 필요 데이터: 최근 3개월 거래 데이터",
    }
  },
  {
    user: yoo,
    template: templates["보안정책 예외 신청서"],
    status: "approved",
    data: {
      exception_item: "소프트웨어 설치",
      exception_reason: "개발 도구 Docker Desktop 설치 필요\n로컬 개발 환경 구축을 위해 필수",
      expiry_date: (Date.today + 180.days).to_s,
      other_item: "Docker Desktop v4.26"
    }
  },
  {
    user: moon,
    template: templates["방화벽 정책 변경 신청서"],
    status: "approved",
    data: {
      application_type: "신규",
      source_info: "192.168.1.0/24 (개발망)",
      destination_info: "10.0.1.50 (DB 서버)",
      port_info: "3306 (MySQL)",
      request_reason: "신규 프로젝트 DB 연결 필요",
      apply_date: Date.today.to_s,
      expiry_date: (Date.today + 90.days).to_s
    }
  },
  {
    user: kim_b,
    template: templates["작업계획서"],
    status: "pending",
    data: {
      work_name: "프로덕션 서버 정기 점검",
      work_date: (Date.today + 3.days).to_s,
      work_time: "02:00 ~ 05:00",
      work_location: "데이터센터",
      risk_level: "중",
      urgency: "일반",
      work_purpose: "서버 패치 적용 및 보안 업데이트\n- OS 보안 패치\n- 미들웨어 버전 업그레이드\n- 로그 파일 정리",
      end_date: (Date.today + 3.days).to_s,
      remarks: "작업 중 5분 내외 서비스 중단 예상"
    }
  },
  {
    user: kim_k,
    template: templates["프로그램 배포 계획서"],
    status: "pending",
    data: {
      deployment_date: (Date.today + 2.days).to_s,
      deployment_time: "23:00",
      service_name: "주요서비스",
      deployment_type: "정기배포",
      target_systems: "WEB-01, WEB-02, API-01",
      work_summary: "v2.3.0 릴리즈 배포\n- 신규 기능 3건\n- 버그 수정 5건\n- 성능 개선 2건",
      remarks: "배포 후 모니터링 30분 진행"
    }
  },
  {
    user: yoo,
    template: templates["차단된 웹페이지 해제 신청서"],
    status: "rejected",
    data: {
      blocked_url: "https://stackoverflow.com\nhttps://github.com\nhttps://npmjs.com",
      unblock_reason: "개발 관련 기술 문서 및 오픈소스 라이브러리 검색을 위해 필요합니다.\n업무 효율성 향상을 위해 해제 요청드립니다."
    }
  }
]

# 신청서 생성
request_forms_data.each_with_index do |form_data, index|
  next unless form_data[:user] && form_data[:template]
  
  # 신청 번호 생성 (랜덤)
  date_prefix = Date.current.strftime('%Y%m')
  random_num = rand(1000..9999)
  request_number = "REQ-#{date_prefix}-#{random_num.to_s.rjust(4, '0')}"
  
  request_form = RequestForm.create!(
    user: form_data[:user],
    organization: form_data[:user].organization,
    request_template: form_data[:template],
    request_category: form_data[:template].request_category,
    title: "[#{form_data[:template].request_category.name}] #{form_data[:template].name} - #{form_data[:user].name}",
    request_number: request_number,
    status: form_data[:status],
    form_data: form_data[:data],
    is_draft: false,
    submitted_at: form_data[:status] != 'draft' ? Time.current : nil,
    approved_at: form_data[:status] == 'approved' ? Time.current : nil,
    rejected_at: form_data[:status] == 'rejected' ? Time.current : nil,
    rejection_reason: form_data[:status] == 'rejected' ? "보안 정책상 허용 불가" : nil,
    approval_line: approval_lines_with_choi.sample
  )
  
  puts "  Created RequestForm: #{request_form.title} (#{request_form.status})"
  
  # pending 상태인 경우 승인 요청 생성
  if form_data[:status] == 'pending' && request_form.approval_line
    approval_request = ApprovalRequest.create!(
      approvable: request_form,
      approval_line: request_form.approval_line,
      status: 'pending',
      current_step: 2  # 유천호가 승인했으므로 2단계로 설정
    )
    
    # ApprovalLineStep을 ApprovalRequestStep으로 복사
    request_form.approval_line.approval_line_steps.each do |line_step|
      # approval_type 매핑: single_allowed -> any_one
      mapped_approval_type = line_step.approval_type == 'single_allowed' ? 'any_one' : line_step.approval_type
      
      # 1단계(유천호)는 approved, 나머지는 pending
      step_status = line_step.step_order == 1 ? 'approved' : 'pending'
      
      approval_request.approval_request_steps.create!(
        approver_id: line_step.approver_id,
        step_order: line_step.step_order,
        role: line_step.role,
        approval_type: mapped_approval_type,
        status: step_status,
        actioned_at: step_status == 'approved' ? Time.current : nil
      )
    end
    
    # 유천호의 승인 이력 추가
    first_approver = request_form.approval_line.approval_line_steps.find_by(step_order: 1)
    if first_approver
      ApprovalHistory.create!(
        approval_request: approval_request,
        approver_id: first_approver.approver_id,
        action: 'approve',
        step_order: 1,
        role: 'approve',
        comment: "승인합니다.",
        approved_at: Time.current
      )
    end
    
    puts "    Created ApprovalRequest ##{approval_request.id} with 유천호 already approved, waiting for 최효진"
  elsif form_data[:status] == 'approved' && request_form.approval_line
    # 승인 완료된 건도 이력 생성
    approval_request = ApprovalRequest.create!(
      approvable: request_form,
      approval_line: request_form.approval_line,
      status: 'approved',
      current_step: 1,
      completed_at: Time.current
    )
    
    # ApprovalLineStep을 ApprovalRequestStep으로 복사
    request_form.approval_line.approval_line_steps.each do |line_step|
      # approval_type 매핑: single_allowed -> any_one
      mapped_approval_type = line_step.approval_type == 'single_allowed' ? 'any_one' : line_step.approval_type
      
      approval_request.approval_request_steps.create!(
        approver_id: line_step.approver_id,
        step_order: line_step.step_order,
        role: line_step.role,
        approval_type: mapped_approval_type,
        status: 'approved'
      )
    end
    
    # current_step을 마지막 단계로 설정
    last_step = approval_request.approval_request_steps.maximum(:step_order) || 1
    approval_request.update!(current_step: last_step)
    
    # 승인 이력 추가
    ApprovalHistory.create!(
      approval_request: approval_request,
      approver: choi,
      action: 'approve',
      step_order: 1,
      role: 'approve',
      comment: "승인합니다.",
      approved_at: Time.current
    )
    
    puts "    Created approved ApprovalRequest ##{approval_request.id} with history"
  elsif form_data[:status] == 'rejected' && request_form.approval_line
    # 반려된 건도 이력 생성
    approval_request = ApprovalRequest.create!(
      approvable: request_form,
      approval_line: request_form.approval_line,
      status: 'rejected',
      current_step: 1,
      completed_at: Time.current
    )
    
    # ApprovalLineStep을 ApprovalRequestStep으로 복사
    request_form.approval_line.approval_line_steps.each do |line_step|
      # approval_type 매핑: single_allowed -> any_one
      mapped_approval_type = line_step.approval_type == 'single_allowed' ? 'any_one' : line_step.approval_type
      
      approval_request.approval_request_steps.create!(
        approver_id: line_step.approver_id,
        step_order: line_step.step_order,
        role: line_step.role,
        approval_type: mapped_approval_type,
        status: line_step.step_order == 1 ? 'rejected' : 'pending'
      )
    end
    
    # 승인 요청 생성 완료
    
    # 반려 이력 추가
    ApprovalHistory.create!(
      approval_request: approval_request,
      approver: choi,
      action: 'reject',
      step_order: 1,
      role: 'approve',
      comment: form_data[:status] == 'rejected' ? "보안 정책상 허용 불가" : nil,
      approved_at: Time.current
    )
    
    puts "    Created rejected ApprovalRequest ##{approval_request.id} with history"
  end
end

puts "\nRequestForm sample data creation completed!"
puts "Total RequestForms: #{RequestForm.count}"
puts "Pending RequestForms: #{RequestForm.where(status: 'pending').count}"
puts "RequestForms with 최효진 as approver: #{ApprovalRequest.joins(approval_line: :approval_line_steps).where(approval_line_steps: { approver_id: choi.id }, approvable_type: 'RequestForm').count}"