require "test_helper"

class ExpenseItemGeneratedDescriptionTest < ActiveSupport::TestCase
  self.use_transactional_tests = true
  
  def setup
    # 테스트 환경 준비
    @organization = Organization.create!(
      name: "개발팀",
      code: "DEV"
    )
    
    @user = User.create!(
      email: "test@example.com",
      password: "password123",
      name: "테스트 사용자",
      organization: @organization
    )
    
    @cost_center = CostCenter.create!(
      name: "개발부",
      code: "DEV001",
      organization: @organization
    )
    
    @expense_sheet = ExpenseSheet.create!(
      user: @user,
      organization: @organization,
      year: 2025,
      month: 1,
      status: 'draft'
    )
    
    @expense_code = ExpenseCode.create!(
      code: "MEAL",
      name: "회식비",
      active: true,
      description_template: "회식비(#참석자) - #식당명",
      validation_rules: {
        'required_fields' => {
          'participants' => { 'label' => '참석자', 'type' => 'text', 'required' => true },
          'restaurant' => { 'label' => '식당명', 'type' => 'text', 'required' => true }
        }
      }
    )
  end
  
  def teardown
    # 테스트 데이터 정리 (transactional_tests 사용으로 자동 처리)
  end
  
  test "템플릿으로 generated_description 생성" do
    item = @expense_sheet.expense_items.create!(
      expense_code: @expense_code,
      expense_date: Date.new(2025, 1, 15),
      amount: 50000,
      cost_center: @cost_center,
      custom_fields: {
        'participants' => '김철수, 이영희, 박민수',
        'restaurant' => '한식당'
      }
    )
    
    assert_equal "회식비(김철수, 이영희, 박민수) - 한식당", item.generated_description
  end
  
  test "일부 필드 미입력 시 처리" do
    item = @expense_sheet.expense_items.create!(
      expense_code: @expense_code,
      expense_date: Date.new(2025, 1, 15),
      amount: 50000,
      cost_center: @cost_center,
      custom_fields: {
        'participants' => '김철수'
        # restaurant 필드 누락
      }
    )
    
    assert_equal "회식비(김철수) -", item.generated_description
  end
  
  test "직접 입력한 description이 있으면 템플릿 무시" do
    item = @expense_sheet.expense_items.create!(
      expense_code: @expense_code,
      expense_date: Date.new(2025, 1, 15),
      amount: 50000,
      cost_center: @cost_center,
      description: "직접 입력한 설명",
      custom_fields: {
        'participants' => '김철수',
        'restaurant' => '한식당'
      }
    )
    
    assert_nil item.generated_description
    assert_equal "직접 입력한 설명", item.display_description
  end
  
  test "템플릿이 없는 경비 코드는 generated_description 생성 안함" do
    @expense_code.update!(description_template: nil)
    
    item = @expense_sheet.expense_items.create!(
      expense_code: @expense_code,
      expense_date: Date.new(2025, 1, 15),
      amount: 50000,
      cost_center: @cost_center,
      custom_fields: {
        'participants' => '김철수'
      }
    )
    
    assert_nil item.generated_description
    assert_equal "설명 없음", item.display_description
  end
  
  test "업데이트 시에도 generated_description 재생성" do
    item = @expense_sheet.expense_items.create!(
      expense_code: @expense_code,
      expense_date: Date.new(2025, 1, 15),
      amount: 50000,
      cost_center: @cost_center,
      custom_fields: {
        'participants' => '김철수',
        'restaurant' => '한식당'
      }
    )
    
    assert_equal "회식비(김철수) - 한식당", item.generated_description
    
    # custom_fields 업데이트
    item.update!(custom_fields: {
      'participants' => '김철수, 이영희',
      'restaurant' => '일식당'
    })
    
    assert_equal "회식비(김철수, 이영희) - 일식당", item.generated_description
  end
end