require "test_helper"

class ReportGeneratorServiceTest < ActiveSupport::TestCase
  def setup
    @user = users(:john)
    @template = report_templates(:monthly_report)
    @export = ReportExport.create!(
      user: @user,
      report_template: @template,
      status: 'pending'
    )
    @service = ReportGeneratorService.new(@export)
    
    # 테스트 데이터 생성
    create_test_expense_data
  end
  
  test "should generate report successfully" do
    @service.generate
    
    @export.reload
    assert_equal 'completed', @export.status
    assert_not_nil @export.completed_at
    assert @export.total_records > 0
    assert @export.export_file.attached?
  end
  
  test "should handle errors gracefully" do
    # 잘못된 필터로 오류 유발
    @template.update!(filter_config: { invalid_field: 'test' })
    
    @service.generate
    
    @export.reload
    assert_equal 'failed', @export.status
    assert_not_nil @export.error_message
  end
  
  test "should generate excel report" do
    @template.update!(export_format: 'excel')
    @service.generate
    
    assert @export.export_file.attached?
    assert_equal 'application/vnd.ms-excel', @export.export_file.content_type
  end
  
  test "should generate pdf report" do
    @template.update!(export_format: 'pdf')
    @service.generate
    
    assert @export.export_file.attached?
    assert_equal 'application/pdf', @export.export_file.content_type
  end
  
  test "should generate csv report" do
    @template.update!(export_format: 'csv')
    @service.generate
    
    assert @export.export_file.attached?
    assert_equal 'text/csv', @export.export_file.content_type
  end
  
  test "should apply filters correctly" do
    # 승인된 항목만 필터
    @template.update!(filter_config: { status: 'approved' })
    @service.generate
    
    @export.reload
    approved_count = ExpenseItem.joins(:expense_sheet)
                               .where(expense_sheets: { status: 'approved' })
                               .count
    assert_equal approved_count, @export.total_records
  end
  
  test "should respect column configuration" do
    @template.update!(
      export_format: 'csv',
      columns_config: ['date', 'amount']
    )
    
    @service.generate
    
    # CSV 내용 검증
    assert @export.export_file.attached?
    csv_content = @export.export_file.download
    lines = csv_content.split("\n")
    headers = lines.first.split(",")
    
    assert_equal 2, headers.size
    assert_includes headers, "사용일"
    assert_includes headers, "금액"
  end
  
  private
  
  def create_test_expense_data
    # 테스트용 경비 데이터 생성
    3.times do |i|
      sheet = ExpenseSheet.create!(
        user: @user,
        year_month: Date.current.strftime('%Y%m'),
        status: ['draft', 'submitted', 'approved'][i]
      )
      
      2.times do |j|
        ExpenseItem.create!(
          expense_sheet: sheet,
          date: Date.current - j.days,
          expense_code: expense_codes(:transportation),
          amount: 10000 * (j + 1),
          description: "테스트 경비 #{i}-#{j}"
        )
      end
    end
  end
end