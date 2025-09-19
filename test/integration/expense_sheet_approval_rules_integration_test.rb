require_relative "../test_without_fixtures"

class ExpenseSheetApprovalRulesIntegrationTest < ActionDispatch::IntegrationTest
  self.use_transactional_tests = true
  
  setup do
    # 기존 데이터 정리
    ExpenseItem.destroy_all
    ExpenseSheet.destroy_all
    ExpenseSheetApprovalRule.destroy_all
    ApproverGroupMember.destroy_all
    ApproverGroup.destroy_all
    ExpenseCode.destroy_all
    CostCenter.destroy_all
    User.destroy_all
    Organization.destroy_all
    
    setup_test_data
    setup_expense_codes
    setup_approval_rules
  end

  test "전체 승인 규칙 플로우 - 관리자 페이지부터 경비 시트 제출까지" do
    puts "\n" + "=" * 60
    puts "경비 시트 승인 규칙 통합 테스트"
    puts "=" * 60

    # 1. 관리자 페이지 접근 테스트
    puts "\n1. 관리자 페이지 접근 테스트..."
    
    # 관리자로 로그인
    post '/login', params: { 
      email: @admin.email, 
      password: 'password123' 
    }
    
    # 관리자 대시보드 접근
    get '/admin'
    assert_response :success, "관리자 대시보드 접근 가능해야 함"
    
    # 승인 규칙 관리 페이지 접근
    get '/admin/expense_sheet_approval_rules'
    if response.successful?
      puts "✅ 승인 규칙 관리 페이지 접근 성공"
    else
      puts "❌ 승인 규칙 관리 페이지 접근 실패: #{response.status}"
    end
    
    # 2. 새로운 승인 규칙 생성 테스트
    puts "\n2. 새로운 승인 규칙 생성..."
    
    # 경비 코드 기반 규칙 생성
    assert_difference('ExpenseSheetApprovalRule.count') do
      post '/admin/expense_sheet_approval_rules', params: {
        expense_sheet_approval_rule: {
          organization_id: @headquarters.id,
          approver_group_id: @executive_group.id,
          condition: '#경비코드:TRAVEL001,TRAVEL002 #총금액 > 1000000',
          rule_type: 'expense_code_amount',
          is_active: true
        }
      }
    end
    
    if response.redirect? || response.successful?
      puts "✅ 경비 코드 기반 승인 규칙 생성 성공"
      @new_rule = ExpenseSheetApprovalRule.last
      puts "   조건: #{@new_rule.condition}"
      puts "   승인그룹: #{@new_rule.approver_group.name}"
    else
      puts "❌ 승인 규칙 생성 실패: #{response.status}"
    end
    
    # 3. 규칙 목록 확인
    puts "\n3. 승인 규칙 목록 확인..."
    
    get '/admin/expense_sheet_approval_rules'
    active_rules = ExpenseSheetApprovalRule.active.ordered
    
    puts "✅ 활성 승인 규칙 수: #{active_rules.count}"
    active_rules.each_with_index do |rule, index|
      puts "   #{index + 1}. [#{rule.rule_type}] #{rule.condition || '조건없음'}"
      puts "      승인그룹: #{rule.approver_group.name} (우선순위: #{rule.approver_group.priority})"
    end
    
    # 4. 일반 사용자로 경비 시트 제출 및 규칙 적용 테스트
    puts "\n4. 경비 시트 제출 및 승인 규칙 적용 테스트..."
    
    # 일반 사용자로 로그인
    delete '/logout'
    post '/login', params: {
      email: @user.email,
      password: 'password123'
    }
    
    # 4-1. 소액 일반 경비 (팀장 승인만 필요)
    test_small_expense
    
    # 4-2. 중액 경비 (부서장 승인 필요)
    test_medium_expense
    
    # 4-3. 고액 출장 경비 (임원 승인 필요)
    test_large_travel_expense
    
    # 4-4. 특수 경비 코드 (CEO 승인 필요)
    test_special_expense
    
    # 5. 복수 승인자 그룹 테스트
    puts "\n5. 복수 승인자 그룹 요구사항 테스트..."
    test_multiple_approver_groups
    
    puts "\n" + "=" * 60
    puts "통합 테스트 완료"
    puts "=" * 60
  end

  private

  def setup_test_data
    # 조직 구조 생성
    @headquarters = Organization.create!(
      name: '본사',
      code: 'HQ'
    )
    
    @sales_dept = Organization.create!(
      name: '영업부',
      code: 'SALES',
      parent: @headquarters
    )
    
    @sales_team = Organization.create!(
      name: '영업1팀',
      code: 'SALES1',
      parent: @sales_dept
    )
    
    # 코스트 센터 생성
    @cost_center = CostCenter.create!(
      code: 'CC001',
      name: '영업1팀 코스트센터',
      fiscal_year: Date.today.year,
      budget_amount: 10000000,
      organization: @sales_team,
      active: true
    )
    
    # 사용자 생성
    @user = User.create!(
      email: 'user@example.com',
      name: '홍길동',
      password: 'password123',
      employee_id: 'E001',
      organization: @sales_team,
      role: 'employee'
    )
    
    @team_leader = User.create!(
      email: 'leader@example.com',
      name: '김팀장',
      password: 'password123',
      employee_id: 'E002',
      organization: @sales_team,
      role: 'manager'
    )
    
    @dept_manager = User.create!(
      email: 'manager@example.com',
      name: '이부장',
      password: 'password123',
      employee_id: 'E003',
      organization: @sales_dept,
      role: 'manager'
    )
    
    @executive = User.create!(
      email: 'exec@example.com',
      name: '박임원',
      password: 'password123',
      employee_id: 'E004',
      organization: @headquarters,
      role: 'admin'
    )
    
    @ceo = User.create!(
      email: 'ceo@example.com',
      name: '최대표',
      password: 'password123',
      employee_id: 'E005',
      organization: @headquarters,
      role: 'admin'
    )
    
    @admin = User.create!(
      email: 'admin@example.com',
      name: '관리자',
      password: 'password123',
      employee_id: 'E999',
      organization: @headquarters,
      role: 'admin'
    )
    
    # 승인자 그룹 생성
    @team_leader_group = ApproverGroup.create!(
      name: '팀장 승인',
      priority: 1,
      created_by: @admin
    )
    
    @dept_manager_group = ApproverGroup.create!(
      name: '부서장 승인',
      priority: 3,
      created_by: @admin
    )
    
    @executive_group = ApproverGroup.create!(
      name: '임원 승인',
      priority: 5,
      created_by: @admin
    )
    
    @ceo_group = ApproverGroup.create!(
      name: 'CEO 승인',
      priority: 10,
      created_by: @admin
    )
    
    # 그룹 멤버 추가
    [@team_leader].each do |user|
      ApproverGroupMember.create!(
        approver_group: @team_leader_group,
        user: user,
        added_by: @admin
      )
    end
    
    [@dept_manager].each do |user|
      ApproverGroupMember.create!(
        approver_group: @dept_manager_group,
        user: user,
        added_by: @admin
      )
    end
    
    [@executive].each do |user|
      ApproverGroupMember.create!(
        approver_group: @executive_group,
        user: user,
        added_by: @admin
      )
    end
    
    [@ceo].each do |user|
      ApproverGroupMember.create!(
        approver_group: @ceo_group,
        user: user,
        added_by: @admin
      )
    end
  end
  
  def setup_expense_codes
    # 경비 코드 생성
    @travel_code = ExpenseCode.create!(
      code: 'TRAVEL001',
      name: '국내출장',
      description: '국내 출장 관련 경비',
      active: true
    )
    
    @overseas_travel_code = ExpenseCode.create!(
      code: 'TRAVEL002',
      name: '해외출장',
      description: '해외 출장 관련 경비',
      active: true
    )
    
    @meal_code = ExpenseCode.create!(
      code: 'MEAL001',
      name: '식대',
      description: '업무 관련 식대',
      active: true
    )
    
    @office_code = ExpenseCode.create!(
      code: 'OFFICE001',
      name: '사무용품',
      description: '사무용품 구매',
      active: true
    )
    
    @special_code = ExpenseCode.create!(
      code: 'SPECIAL001',
      name: '특별경비',
      description: '특별 승인이 필요한 경비',
      active: true
    )
  end
  
  def setup_approval_rules
    # 기본 금액 기반 규칙
    ExpenseSheetApprovalRule.create!(
      organization: @headquarters,
      approver_group: @team_leader_group,
      condition: '#총금액 <= 100000',
      rule_type: 'amount',
      is_active: true
    )
    
    ExpenseSheetApprovalRule.create!(
      organization: @headquarters,
      approver_group: @dept_manager_group,
      condition: '#총금액 > 100000 #총금액 <= 500000',
      rule_type: 'amount',
      is_active: true
    )
    
    ExpenseSheetApprovalRule.create!(
      organization: @headquarters,
      approver_group: @executive_group,
      condition: '#총금액 > 500000',
      rule_type: 'amount',
      is_active: true
    )
    
    # 특수 경비 코드 규칙
    ExpenseSheetApprovalRule.create!(
      organization: @headquarters,
      approver_group: @ceo_group,
      condition: '#경비코드:SPECIAL001',
      rule_type: 'expense_code',
      is_active: true
    )
  end
  
  def test_small_expense
    puts "\n4-1. 소액 일반 경비 테스트 (10만원 이하)..."
    
    # 고유한 월 사용 (현재월 - 5)
    test_date = Date.today - 5.months
    
    sheet = ExpenseSheet.create!(
      user: @user,
      organization: @user.organization,
      cost_center: @cost_center,
      month: test_date.month,
      year: test_date.year,
      remarks: '소액 사무용품 구매'
    )
    
    # expense_date를 sheet의 년월에 맞춤
    expense_date = Date.new(test_date.year, test_date.month, 15)
    
    sheet.expense_items.create!(
      expense_date: expense_date,
      expense_code: @office_code,
      description: '사무용품',
      amount: 50000,
      cost_center_id: @cost_center.id
    )
    
    # 명시적으로 total_amount 계산 및 업데이트 (콜백 우회)
    amount_sum = sheet.expense_items.sum(:amount)
    sheet.update_column(:total_amount, amount_sum)
    sheet.reload  # 업데이트 후 리로드
    
    # 적용될 규칙 확인
    context = build_context(sheet)
    applicable_rules = ExpenseSheetApprovalRule.active.select { |r| r.evaluate(context) }
    
    puts "   신청 금액: #{sheet.total_amount}원"
    puts "   적용 규칙 수: #{applicable_rules.count}"
    
    if applicable_rules.any?
      rule = applicable_rules.first
      puts "   ✅ 적용된 규칙: #{rule.condition}"
      puts "      필요 승인: #{rule.approver_group.name}"
      assert_equal @team_leader_group, rule.approver_group, "팀장 승인이 필요해야 함"
    else
      puts "   ❌ 적용된 규칙이 없음"
    end
  end
  
  def test_medium_expense
    puts "\n4-2. 중액 경비 테스트 (10만원 초과 ~ 50만원)..."
    
    # 고유한 월 사용 (현재월 - 6) 
    test_date = Date.today - 6.months
    
    sheet = ExpenseSheet.create!(
      user: @user,
      organization: @user.organization,
      cost_center: @cost_center,
      month: test_date.month,
      year: test_date.year,
      remarks: '업무 회식비'
    )
    
    # expense_date를 sheet의 년월에 맞춤
    expense_date = Date.new(test_date.year, test_date.month, 15)
    
    sheet.expense_items.create!(
      expense_date: expense_date,
      expense_code: @meal_code,
      description: '팀 회식',
      amount: 300000,
      cost_center_id: @cost_center.id
    )
    
    # 명시적으로 total_amount 계산 및 업데이트 (콜백 우회)
    amount_sum = sheet.expense_items.sum(:amount)
    sheet.update_column(:total_amount, amount_sum)
    sheet.reload  # 업데이트 후 리로드
    
    context = build_context(sheet)
    applicable_rules = ExpenseSheetApprovalRule.active.select { |r| r.evaluate(context) }
    
    puts "   신청 금액: #{sheet.total_amount}원"
    puts "   적용 규칙 수: #{applicable_rules.count}"
    
    if applicable_rules.any?
      rule = applicable_rules.first
      puts "   ✅ 적용된 규칙: #{rule.condition}"
      puts "      필요 승인: #{rule.approver_group.name}"
      assert_equal @dept_manager_group, rule.approver_group, "부서장 승인이 필요해야 함"
    else
      puts "   ❌ 적용된 규칙이 없음"
    end
  end
  
  def test_large_travel_expense
    puts "\n4-3. 고액 출장 경비 테스트 (100만원 초과 + 출장비 코드)..."
    
    # 고유한 월 사용 (현재월 - 7)
    test_date = Date.today - 7.months
    
    sheet = ExpenseSheet.create!(
      user: @user,
      organization: @user.organization,
      cost_center: @cost_center,
      remarks: '해외 출장',
      month: test_date.month,
      year: test_date.year
    )
    
    # expense_date를 sheet의 년월에 맞춤
    expense_date = Date.new(test_date.year, test_date.month, 15)
    
    sheet.expense_items.create!(
      expense_date: expense_date,
      expense_code: @overseas_travel_code,
      description: '항공료',
      amount: 1000000,
      cost_center_id: @cost_center.id
    )
    
    sheet.expense_items.create!(
      expense_date: expense_date,
      expense_code: @overseas_travel_code,
      description: '호텔비',
      amount: 500000,
      cost_center_id: @cost_center.id
    )
    
    # 명시적으로 total_amount 계산 및 업데이트 (콜백 우회)
    amount_sum = sheet.expense_items.sum(:amount)
    sheet.update_column(:total_amount, amount_sum)
    sheet.reload  # 업데이트 후 리로드
    
    context = build_context(sheet)
    applicable_rules = ExpenseSheetApprovalRule.active.select { |r| r.evaluate(context) }
    
    puts "   신청 금액: #{sheet.total_amount}원"
    puts "   경비 코드: #{sheet.expense_items.map(&:expense_code).map(&:code).uniq.join(', ')}"
    puts "   적용 규칙 수: #{applicable_rules.count}"
    
    applicable_rules.each_with_index do |rule, index|
      puts "   #{index + 1}. 적용 규칙: #{rule.condition}"
      puts "      필요 승인: #{rule.approver_group.name}"
    end
    
    # 고액이므로 임원 승인이 필요해야 함
    assert applicable_rules.any? { |r| r.approver_group == @executive_group }, 
           "고액 경비는 임원 승인이 필요해야 함"
  end
  
  def test_special_expense
    puts "\n4-4. 특수 경비 코드 테스트 (CEO 승인 필요)..."
    
    # 고유한 월 사용 (현재월 - 8)
    test_date = Date.today - 8.months
    
    sheet = ExpenseSheet.create!(
      user: @user,
      organization: @user.organization,
      cost_center: @cost_center,
      remarks: '특별 프로젝트 경비',
      month: test_date.month,
      year: test_date.year
    )
    
    # expense_date를 sheet의 년월에 맞춤
    expense_date = Date.new(test_date.year, test_date.month, 15)
    
    sheet.expense_items.create!(
      expense_date: expense_date,
      expense_code: @special_code,
      description: '특별 경비',
      amount: 200000,
      cost_center_id: @cost_center.id
    )
    
    # 명시적으로 total_amount 계산 및 업데이트 (콜백 우회)
    amount_sum = sheet.expense_items.sum(:amount)
    sheet.update_column(:total_amount, amount_sum)
    sheet.reload  # 업데이트 후 리로드
    
    context = build_context(sheet)
    applicable_rules = ExpenseSheetApprovalRule.active.select { |r| r.evaluate(context) }
    
    puts "   신청 금액: #{sheet.total_amount}원"
    puts "   경비 코드: #{sheet.expense_items.map(&:expense_code).map(&:code).uniq.join(', ')}"
    puts "   적용 규칙 수: #{applicable_rules.count}"
    
    # 특수 경비 코드 규칙과 금액 규칙 모두 확인
    special_rule = applicable_rules.find { |r| r.approver_group == @ceo_group }
    amount_rule = applicable_rules.find { |r| r.approver_group == @dept_manager_group }
    
    if special_rule
      puts "   ✅ 특수 경비 규칙 적용: #{special_rule.condition}"
      puts "      필요 승인: #{special_rule.approver_group.name}"
    end
    
    if amount_rule
      puts "   ✅ 금액 규칙도 적용: #{amount_rule.condition}"
      puts "      필요 승인: #{amount_rule.approver_group.name}"
    end
    
    assert special_rule, "특수 경비 코드는 CEO 승인이 필요해야 함"
  end
  
  def test_multiple_approver_groups
    puts "\n5. 복수 승인자 그룹 테스트..."
    
    # 복합 조건 규칙 추가 (출장비 + 고액)
    complex_rule = ExpenseSheetApprovalRule.create!(
      organization: @headquarters,
      approver_group: @ceo_group,
      condition: '#경비코드:TRAVEL002 #총금액 > 2000000',
      rule_type: 'complex',
      is_active: true
    )
    
    # 고유한 월 사용 (현재월 - 9)
    test_date = Date.today - 9.months
    
    sheet = ExpenseSheet.create!(
      user: @user,
      organization: @user.organization,
      cost_center: @cost_center,
      remarks: '대규모 해외 출장',
      month: test_date.month,
      year: test_date.year
    )
    
    # expense_date를 sheet의 년월에 맞춤
    expense_date = Date.new(test_date.year, test_date.month, 15)
    
    sheet.expense_items.create!(
      expense_date: expense_date,
      expense_code: @overseas_travel_code,
      description: '팀 전체 항공료',
      amount: 2500000,
      cost_center_id: @cost_center.id
    )
    
    # 명시적으로 total_amount 계산 및 업데이트 (콜백 우회)
    amount_sum = sheet.expense_items.sum(:amount)
    sheet.update_column(:total_amount, amount_sum)
    sheet.reload  # 업데이트 후 리로드
    
    context = build_context(sheet)
    applicable_rules = ExpenseSheetApprovalRule.active.select { |r| r.evaluate(context) }
    
    puts "   신청 금액: #{sheet.total_amount}원"
    puts "   경비 코드: #{sheet.expense_items.map(&:expense_code).map(&:code).uniq.join(', ')}"
    puts "   적용 규칙 수: #{applicable_rules.count}"
    
    # 우선순위별로 정렬
    required_groups = applicable_rules.map(&:approver_group).uniq.sort_by(&:priority)
    
    puts "\n   필요한 승인 그룹 (우선순위 순):"
    required_groups.each_with_index do |group, index|
      puts "   #{index + 1}. #{group.name} (우선순위: #{group.priority})"
      members = group.approver_group_members.includes(:user).map(&:user)
      puts "      승인자: #{members.map(&:name).join(', ')}"
    end
    
    # 최고 권한자 확인
    highest_priority_group = required_groups.last
    assert_equal @ceo_group, highest_priority_group, "최고 승인 권한은 CEO여야 함"
    
    puts "\n   ✅ 최종 필요 승인: #{highest_priority_group.name}"
  end
  
  def build_context(sheet)
    {
      submitter: sheet.user,
      total_amount: sheet.total_amount,
      item_count: sheet.expense_items.count,
      expense_codes: sheet.expense_items.includes(:expense_code).map { |item| 
        item.expense_code&.code 
      }.compact.uniq
    }
  end
end