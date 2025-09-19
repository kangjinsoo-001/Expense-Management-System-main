require "test_helper"
require "minitest/autorun"

class MonthlyClosingJobTest < ActiveJob::TestCase
  setup do
    @user = users(:employee)
    @org = organizations(:company)
    
    # 기존 경비 시트 삭제 (중복 방지)
    ExpenseSheet.where(year: 1.month.ago.year, month: 1.month.ago.month).destroy_all
    
    # 테스트용 경비 시트 생성
    @approved_sheet = ExpenseSheet.create!(
      user: @user,
      organization: @org,
      year: 1.month.ago.year,
      month: 1.month.ago.month,
      status: 'approved',
      total_amount: 100000
    )
    
    @submitted_sheet = ExpenseSheet.create!(
      user: users(:manager),
      organization: @org,
      year: 1.month.ago.year,
      month: 1.month.ago.month,
      status: 'submitted',
      total_amount: 50000
    )
  end
  
  test "should enqueue job" do
    assert_enqueued_with(job: MonthlyClosingJob) do
      MonthlyClosingJob.perform_later
    end
  end
  
  test "should perform monthly closing" do
    # 서비스 mock
    mock_service = Minitest::Mock.new
    mock_service.expect :execute, { success: true, message: "완료" }
    
    MonthlyClosingService.stub :new, mock_service do
      MonthlyClosingJob.perform_now
    end
    
    mock_service.verify
  end
  
  test "should use previous month as default" do
    expected_year = 1.month.ago.year
    expected_month = 1.month.ago.month
    
    # 서비스가 올바른 파라미터로 호출되는지 확인
    MonthlyClosingService.stub :new, ->(args) {
      assert_equal expected_year, args[:year]
      assert_equal expected_month, args[:month]
      OpenStruct.new(execute: { success: true })
    } do
      MonthlyClosingJob.perform_now
    end
  end
  
  test "should use specified year and month" do
    # 서비스가 지정된 파라미터로 호출되는지 확인
    MonthlyClosingService.stub :new, ->(args) {
      assert_equal 2025, args[:year]
      assert_equal 11, args[:month]
      OpenStruct.new(execute: { success: true })
    } do
      MonthlyClosingJob.perform_now(2025, 11)
    end
  end
  
  test "should raise error on service failure" do
    error_result = { success: false, message: "에러 발생" }
    
    MonthlyClosingService.stub :new, ->(_) { 
      OpenStruct.new(execute: error_result)
    } do
      assert_raises StandardError do
        MonthlyClosingJob.perform_now
      end
    end
  end
end