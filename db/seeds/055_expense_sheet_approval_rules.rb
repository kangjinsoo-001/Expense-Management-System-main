# 경비 시트 승인 규칙 생성
puts "Creating Expense Sheet Approval Rules..."

# 기존 규칙 삭제
ExpenseSheetApprovalRule.destroy_all

# Admin 사용자 확인
admin = User.find_by(email: 'hjlee@tlx.kr')
unless admin
  puts "Admin user not found. Please run user seeds first."
  exit
end

# 승인자 그룹 확인 및 생성
ceo_group = ApproverGroup.find_or_create_by(name: "CEO") do |g| 
  g.priority = 10
  g.created_by = admin
end

org_head_group = ApproverGroup.find_or_create_by(name: "조직총괄") do |g| 
  g.priority = 8
  g.created_by = admin
end

org_leader_group = ApproverGroup.find_or_create_by(name: "조직리더") do |g| 
  g.priority = 6
  g.created_by = admin
end

officer_group = ApproverGroup.find_or_create_by(name: "보직자") do |g| 
  g.priority = 4
  g.created_by = admin
end

management_group = ApproverGroup.find_or_create_by(name: "경영지원") do |g| 
  g.priority = 5
  g.created_by = admin
end

# 1. 기본 규칙 (총금액 >= 0, 모든 경비 시트): 보직자, 조직리더
ExpenseSheetApprovalRule.create!(
  rule_type: 'total_amount',
  condition: '#총금액 >= 0',
  approver_group: officer_group,
  order: 1,
  is_active: true
)

ExpenseSheetApprovalRule.create!(
  rule_type: 'total_amount',
  condition: '#총금액 >= 0',
  approver_group: org_leader_group,
  order: 2,
  is_active: true
)

# 2. 제출자가 보직자인 경우: 조직리더, 조직총괄
ExpenseSheetApprovalRule.create!(
  rule_type: 'submitter_based',
  submitter_group: officer_group,
  approver_group: org_leader_group,
  order: 3,
  is_active: true
)

ExpenseSheetApprovalRule.create!(
  rule_type: 'submitter_based',
  submitter_group: officer_group,
  approver_group: org_head_group,
  order: 4,
  is_active: true
)

# 3. 제출자가 조직리더인 경우: 조직총괄, CEO
ExpenseSheetApprovalRule.create!(
  rule_type: 'submitter_based',
  submitter_group: org_leader_group,
  approver_group: org_head_group,
  order: 5,
  is_active: true
)

ExpenseSheetApprovalRule.create!(
  rule_type: 'submitter_based',
  submitter_group: org_leader_group,
  approver_group: ceo_group,
  order: 6,
  is_active: true
)

# 4. 제출자가 조직총괄인 경우: CEO
ExpenseSheetApprovalRule.create!(
  rule_type: 'submitter_based',
  submitter_group: org_head_group,
  approver_group: ceo_group,
  order: 7,
  is_active: true
)

# 5. 경비 코드 기반 (ENTN 또는 EQUM 포함 시): 조직총괄, CEO
ExpenseSheetApprovalRule.create!(
  rule_type: 'expense_code_based',
  condition: '#경비코드:ENTN,EQUM',
  approver_group: org_head_group,
  order: 8,
  is_active: true
)

ExpenseSheetApprovalRule.create!(
  rule_type: 'expense_code_based',
  condition: '#경비코드:ENTN,EQUM',
  approver_group: ceo_group,
  order: 9,
  is_active: true
)

puts "Created #{ExpenseSheetApprovalRule.count} Expense Sheet Approval Rules"
puts ""
puts "규칙 요약:"
puts "1. 기본 (총금액 >= 0): 보직자, 조직리더 승인 필요"
puts "2. 제출자가 보직자: 조직리더, 조직총괄 승인 필요"
puts "3. 제출자가 조직리더: 조직총괄, CEO 승인 필요"
puts "4. 제출자가 조직총괄: CEO 승인 필요"
puts "5. ENTN(접대비) 또는 EQUM(기기/비품비) 포함: 조직총괄, CEO 승인 필요"