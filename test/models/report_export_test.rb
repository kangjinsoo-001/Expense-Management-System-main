require "test_helper"

class ReportExportTest < ActiveSupport::TestCase
  def setup
    @user = users(:john)
    @template = ReportTemplate.create!(
      name: "Test Template",
      user: @user,
      export_format: "excel"
    )
    @report_export = ReportExport.new(
      user: @user,
      report_template: @template,
      status: 'pending'
    )
  end
  
  test "should be valid with all attributes" do
    assert @report_export.valid?
  end
  
  test "should require user" do
    @report_export.user = nil
    assert_not @report_export.valid?
    assert_includes @report_export.errors[:user], "must exist"
  end
  
  test "should be valid without report_template" do
    @report_export.report_template = nil
    assert @report_export.valid?
  end
  
  test "should have default status of pending" do
    export = ReportExport.new(user: @user)
    assert_equal 'pending', export.status
  end
  
  test "should validate status inclusion" do
    @report_export.status = 'invalid'
    assert_not @report_export.valid?
    assert_includes @report_export.errors[:status], "is not included in the list"
  end
  
  test "status predicate methods should work" do
    @report_export.status = 'pending'
    assert @report_export.pending?
    assert_not @report_export.processing?
    assert_not @report_export.completed?
    assert_not @report_export.failed?
    
    @report_export.status = 'processing'
    assert @report_export.processing?
    
    @report_export.status = 'completed'
    assert @report_export.completed?
    
    @report_export.status = 'failed'
    assert @report_export.failed?
  end
  
  test "recent scope should order by created_at desc" do
    old_export = ReportExport.create!(user: @user, status: 'completed', created_at: 2.days.ago)
    new_export = ReportExport.create!(user: @user, status: 'completed', created_at: 1.hour.ago)
    
    recent = ReportExport.recent
    assert_equal new_export, recent.first
    assert_equal old_export, recent.last
  end
  
  test "by_user scope should filter by user" do
    other_user = users(:jane)
    user_export = ReportExport.create!(user: @user, status: 'completed')
    other_export = ReportExport.create!(user: other_user, status: 'completed')
    
    user_exports = ReportExport.by_user(@user)
    assert_includes user_exports, user_export
    assert_not_includes user_exports, other_export
  end
  
  test "should have one attached export_file" do
    @report_export.save!
    assert @report_export.export_file.respond_to?(:attach)
  end
  
  test "should track file metadata" do
    @report_export.file_size = 1024 * 1024  # 1MB
    @report_export.total_records = 100
    @report_export.completed_at = Time.current
    @report_export.save!
    
    assert_equal 1024 * 1024, @report_export.file_size
    assert_equal 100, @report_export.total_records
    assert_not_nil @report_export.completed_at
  end
  
  test "should track error message for failed exports" do
    @report_export.status = 'failed'
    @report_export.error_message = "데이터베이스 연결 오류"
    @report_export.save!
    
    assert_equal "데이터베이스 연결 오류", @report_export.error_message
  end
end
