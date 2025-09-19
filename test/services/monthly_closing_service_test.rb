require "test_helper"

class MonthlyClosingServiceTest < ActiveSupport::TestCase
  setup do
    # 과거 월을 사용하여 중복 방지
    @year = 2.months.ago.year
    @month = 2.months.ago.month
    @service = MonthlyClosingService.new(year: @year, month: @month)
    
    @user = users(:employee)
    @org = organizations(:company)
    
    # 승인된 경비 시트
    @approved_sheet = ExpenseSheet.create!(
      user: @user,
      organization: @org,
      year: @year,
      month: @month,
      status: 'approved',
      total_amount: 100000
    )
    
    # 제출된 경비 시트
    @submitted_sheet = ExpenseSheet.create!(
      user: users(:manager),
      organization: @org,
      year: @year,
      month: @month,
      status: 'submitted',
      total_amount: 50000
    )
    
    # Draft 상태 경비 시트
    @draft_sheet = ExpenseSheet.create!(
      user: users(:finance),
      organization: @org,
      year: @year,
      month: @month,
      status: 'draft',
      total_amount: 0
    )
    
    # 경비 항목 추가 - 간단한 경비 코드 사용
    expense_code = expense_codes(:one)  # 검증 규칙이 없는 일반 경비
    cost_center = cost_centers(:one)
    @draft_sheet.expense_items.create!(
      expense_code: expense_code,
      cost_center: cost_center,
      amount: 30000,
      expense_date: Date.new(@year, @month, 15),
      description: "일반 경비",
      is_valid: true
    )
  end
  
  test "should close approved expense sheets" do
    result = @service.execute
    
    assert result[:success]
    assert_equal "closed", @approved_sheet.reload.status
  end
  
  test "should not close non-approved sheets" do
    result = @service.execute
    
    assert_equal "submitted", @submitted_sheet.reload.status
    assert_equal "draft", @draft_sheet.reload.status
  end
  
  
  test "should generate closing summary" do
    result = @service.execute
    
    assert result[:success]
    assert result[:summary]
    assert_equal 3, result[:summary][:total_sheets]
    assert_equal 0, result[:summary][:closed]  # 마감 전
    assert_equal 1, result[:summary][:approved]
    assert_equal 1, result[:summary][:pending_approval]
    assert_equal 1, result[:summary][:draft]
  end
  
  
  test "should handle errors gracefully" do
    # 에러 발생 시뮬레이션
    ExpenseSheet.stub :where, ->(*args) { raise StandardError, "DB 에러" } do
      result = @service.execute
      
      assert_not result[:success]
      assert_equal "DB 에러", result[:message]
    end
  end
  
  test "should calculate organization summary" do
    result = @service.execute
    
    summary = result[:summary]
    assert summary[:by_organization]
    assert summary[:by_organization][@org.name]
  end
  
  test "should calculate expense code summary" do
    result = @service.execute
    
    summary = result[:summary]
    assert summary[:by_expense_code]
  end
end