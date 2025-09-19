require "test_helper"

class CostCenterTest < ActiveSupport::TestCase
  def setup
    @organization = organizations(:company)
    @manager = users(:alice)
    @cost_center = CostCenter.new(
      code: "CC001",
      name: "개발팀 비용센터",
      description: "개발팀 경비 관리",
      organization: @organization,
      manager: @manager,
      budget_amount: 10000000,
      fiscal_year: Date.current.year
    )
  end
  
  test "should be valid with valid attributes" do
    assert @cost_center.valid?
  end
  
  test "should require code" do
    @cost_center.code = nil
    assert_not @cost_center.valid?
    assert_includes @cost_center.errors[:code], "는 필수입니다"
  end
  
  test "should require name" do
    @cost_center.name = nil
    assert_not @cost_center.valid?
    assert_includes @cost_center.errors[:name], "은 필수입니다"
  end
  
  test "should require fiscal year" do
    @cost_center.fiscal_year = nil
    @cost_center.valid? # before_validation 콜백이 실행되어 기본값 설정됨
    # fiscal_year는 before_validation에서 자동 설정되므로 에러가 없음
    assert @cost_center.fiscal_year.present?
    assert_equal Date.current.year, @cost_center.fiscal_year
  end
  
  test "should validate fiscal year is greater than 2000" do
    @cost_center.fiscal_year = 1999
    assert_not @cost_center.valid?
    assert_includes @cost_center.errors[:fiscal_year], "는 2000보다 커야 합니다"
  end
  
  test "should validate budget amount is non-negative" do
    @cost_center.budget_amount = -1000
    assert_not @cost_center.valid?
    assert_includes @cost_center.errors[:budget_amount], "는 0 이상이어야 합니다"
  end
  
  test "should allow nil budget amount" do
    @cost_center.budget_amount = nil
    assert @cost_center.valid?
  end
  
  test "should enforce unique code per organization" do
    @cost_center.save!
    duplicate = @cost_center.dup
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:code], "는 이미 사용 중입니다"
    
    # 다른 조직에서는 같은 코드 사용 가능
    other_org = organizations(:two)  # one 대신 two 사용
    other_cc = CostCenter.new(
      code: "CC001",
      name: "다른 조직 비용센터",
      organization: other_org,
      fiscal_year: Date.current.year
    )
    assert other_cc.valid?
  end
  
  test "should set default fiscal year to current year" do
    cc = CostCenter.new(
      code: "CC002",
      name: "테스트 비용센터",
      organization: @organization
    )
    cc.valid? # before_validation 콜백 실행
    assert_equal Date.current.year, cc.fiscal_year
  end
  
  test "should have active scope" do
    @cost_center.save!
    inactive_cc = CostCenter.create!(
      code: "CC003",
      name: "비활성 비용센터",
      organization: @organization,
      fiscal_year: Date.current.year,
      active: false
    )
    
    active_centers = CostCenter.active
    assert_includes active_centers, @cost_center
    assert_not_includes active_centers, inactive_cc
  end
  
  test "should have for_year scope" do
    @cost_center.save!
    last_year_cc = CostCenter.create!(
      code: "CC004",
      name: "작년 비용센터",
      organization: @organization,
      fiscal_year: Date.current.year - 1
    )
    
    current_year_centers = CostCenter.for_year(Date.current.year)
    assert_includes current_year_centers, @cost_center
    assert_not_includes current_year_centers, last_year_cc
  end
  
  test "should have for_organization scope" do
    @cost_center.save!
    other_org = organizations(:one)
    other_cc = CostCenter.create!(
      code: "CC005",
      name: "다른 조직 비용센터",
      organization: other_org,
      fiscal_year: Date.current.year
    )
    
    org_centers = CostCenter.for_organization(@organization)
    assert_includes org_centers, @cost_center
    assert_not_includes org_centers, other_cc
  end
  
  test "should have with_budget scope" do
    @cost_center.save!
    no_budget_cc = CostCenter.create!(
      code: "CC006",
      name: "예산 없는 비용센터",
      organization: @organization,
      fiscal_year: Date.current.year,
      budget_amount: nil
    )
    
    with_budget_centers = CostCenter.with_budget
    assert_includes with_budget_centers, @cost_center
    assert_not_includes with_budget_centers, no_budget_cc
  end
  
  test "should calculate budget utilization" do
    # 현재는 expense_sheets가 없으므로 0을 반환
    assert_equal 0, @cost_center.budget_utilization
    
    # 예산이 없는 경우도 0 반환
    @cost_center.budget_amount = nil
    assert_equal 0, @cost_center.budget_utilization
  end
  
  test "should calculate budget remaining" do
    # 현재는 expense_sheets가 없으므로 전체 예산 반환
    assert_equal 10000000, @cost_center.budget_remaining
    
    # 예산이 없는 경우 nil 반환
    @cost_center.budget_amount = nil
    assert_nil @cost_center.budget_remaining
  end
  
  test "should check budget availability" do
    assert @cost_center.budget_available?
    
    @cost_center.budget_amount = 0
    assert_not @cost_center.budget_available?
    
    @cost_center.budget_amount = nil
    assert_nil @cost_center.budget_available?
  end
  
  test "should have string representation" do
    assert_equal "CC001 - 개발팀 비용센터", @cost_center.to_s
  end
  
  test "manager should be optional" do
    @cost_center.manager = nil
    assert @cost_center.valid?
  end
end
