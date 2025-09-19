# 결재선 샘플 데이터 - 프로덕션용
puts "=== 결재선 생성 시작 ==="

# 사용자 확인
if User.count == 0
  puts "ERROR: 사용자가 없습니다. 먼저 사용자 데이터를 로드하세요."
  exit 1
end

# CEO 확인
ceo = User.find_by(email: "jaypark@tlx.kr")
if ceo.nil?
  puts "ERROR: CEO를 찾을 수 없습니다."
  exit 1
end

# 조직 계층을 따라 승인자 목록 생성
def get_approval_chain(user, ceo)
  approvers = []
  current_org = user.organization
  
  # 조직이 없으면 CEO 직접 승인
  return [ceo] unless current_org
  
  # 본인이 조직장이면 상위 조직부터 시작
  if current_org.manager == user
    current_org = current_org.parent
  end
  
  # 조직 계층을 따라 올라가며 승인자 수집
  while current_org
    if current_org.manager && current_org.manager != user && !approvers.include?(current_org.manager)
      approvers << current_org.manager
    end
    current_org = current_org.parent
  end
  
  # CEO 추가 (최종 승인자, 이미 포함되어 있지 않은 경우)
  if !approvers.include?(ceo) && user != ceo
    approvers << ceo
  end
  
  # 승인자가 없으면 CEO 직접 승인
  approvers.empty? ? [ceo] : approvers
end

# 모든 사용자에 대해 계층 기반 결재선 생성
success_count = 0
fail_count = 0

User.where.not(id: ceo.id).each do |user|
  approvers = get_approval_chain(user, ceo)
  
  # 결재선 생성
  approval_line = ApprovalLine.new(
    user: user,
    name: "기본",
    is_active: true
  )
  
  # 승인 단계 추가
  approvers.each_with_index do |approver, index|
    approval_line.approval_line_steps.build(
      approver: approver,
      step_order: index + 1,
      role: 'approve',
      approval_type: 'single_allowed'
    )
  end
  
  if approval_line.save
    success_count += 1
    puts "✓ #{user.name}: #{approvers.size}단계 (#{approvers.map(&:name).join(' → ')})"
  else
    fail_count += 1
    puts "✗ #{user.name}: #{approval_line.errors.full_messages.join(', ')}"
  end
end

puts "\n=== 결재선 생성 완료 ==="
puts "- 성공: #{success_count}개"
puts "- 실패: #{fail_count}개"  
puts "- 총 결재선: #{ApprovalLine.count}개"
puts "- 총 승인 단계: #{ApprovalLineStep.count}개"