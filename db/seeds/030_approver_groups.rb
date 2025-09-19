# 승인자 그룹 생성
puts "Creating approver groups..."

# 관리자 찾기 - 없으면 첫 번째 admin 역할 사용자 사용
admin = User.find_by(email: 'admin@tlx.kr') || User.find_by(role: 'admin')

# 승인자 그룹 정의
groups_data = [
  { name: 'CEO', description: '대표이사', priority: 10 },
  { name: '조직총괄', description: '조직총괄', priority: 8 },
  { name: '조직리더', description: '조직리더', priority: 6 },
  { name: '보직자', description: '보직자', priority: 4 }
]

# 그룹 생성
groups = {}
groups_data.each do |group_data|
  group = ApproverGroup.find_or_create_by!(name: group_data[:name]) do |g|
    g.description = group_data[:description]
    g.priority = group_data[:priority]
    g.created_by = admin
    g.is_active = true
  end
  groups[group.name] = group
  puts "  Created approver group: #{group.name} (Priority: #{group.priority})"
end

# 그룹 멤버 할당
puts "\nAssigning group members..."

# CEO 그룹 - 박재현
ceo = User.find_by(name: '박재현')
if ceo
  groups['CEO'].add_member(ceo, admin)
  puts "  Added #{ceo.name} to CEO group"
end

# 조직총괄 그룹 - 백승아, 김영만
c_level_names = ['백승아', '김영만']
c_level_names.each do |name|
  user = User.find_by(name: name)
  if user
    groups['조직총괄'].add_member(user, admin)
    puts "  Added #{user.name} to 조직총괄 group"
  end
end

# 조직리더 그룹 - 최효진, 김영남, 이현주
org_leader_names = ['최효진', '김영남', '이현주']
org_leader_names.each do |name|
  user = User.find_by(name: name)
  if user
    groups['조직리더'].add_member(user, admin)
    puts "  Added #{user.name} to 조직리더 group"
  end
end

# 보직자 그룹 - 문선주, 유천호, 이하진, 백진주
position_holder_names = ['문선주', '유천호', '이하진', '백진주']
position_holder_names.each do |name|
  user = User.find_by(name: name)
  if user
    groups['보직자'].add_member(user, admin)
    puts "  Added #{user.name} to 보직자 group"
  end
end

# 추가로 모든 manager 역할 사용자도 보직자에 포함
User.where(role: 'manager').each do |user|
  groups['보직자'].add_member(user, admin) rescue nil
  puts "  Added #{user.name} to 보직자 group (manager role)"
end

# 경비 코드별 승인 규칙 추가
puts "\n경비 코드별 승인 규칙 추가..."

# 회식비 (DINE) - 금액별 승인자 설정
dine_code = ExpenseCode.active.find_by(code: 'DINE')
if dine_code
  # 기존 규칙 삭제
  dine_code.expense_code_approval_rules.destroy_all
  
  # 30만원 이상: CEO 필수 승인
  dine_code.expense_code_approval_rules.create!(
    condition: "#금액 >= 300000",
    approver_group: groups['CEO'],
    order: 1,
    is_active: true
  )
  
  # 30만원 미만: 조직총괄 필수 승인
  dine_code.expense_code_approval_rules.create!(
    condition: "#금액 < 300000",
    approver_group: groups['조직총괄'],
    order: 2,
    is_active: true
  )
  
  puts "  Added approval rules for DINE (회식비)"
end

# 출장비 (TRIP) - 조직리더 승인 필요
trip_code = ExpenseCode.active.find_by(code: 'TRIP')
if trip_code
  trip_code.expense_code_approval_rules.create!(
    condition: "#금액 > 0",
    approver_group: groups['조직리더'],
    order: 1,
    is_active: true
  )
  puts "  Added approval rules for TRIP (출장비)"
end

# 교육비 (EDUC) - 10만원 초과 시 보직자 승인 필요
educ_code = ExpenseCode.active.find_by(code: 'EDUC')
if educ_code
  educ_code.expense_code_approval_rules.create!(
    condition: "#금액 > 100000",
    approver_group: groups['보직자'],
    order: 1,
    is_active: true
  )
  puts "  Added approval rules for EDUC (교육비)"
end

# 프로젝트 활동비 (PROJ) - 보직자 검토 필요
proj_code = ExpenseCode.active.find_by(code: 'PROJ')
if proj_code
  proj_code.expense_code_approval_rules.create!(
    condition: "#금액 > 0",
    approver_group: groups['보직자'],
    order: 1,
    is_active: true
  )
  puts "  Added approval rules for PROJ (프로젝트 활동비)"
end

puts "\nApprover groups setup completed!"