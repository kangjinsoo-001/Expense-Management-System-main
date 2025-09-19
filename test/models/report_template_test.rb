require "test_helper"

class ReportTemplateTest < ActiveSupport::TestCase
  def setup
    @user = users(:john)
    @report_template = ReportTemplate.new(
      name: "월별 경비 리포트",
      description: "월별 경비 집계 리포트",
      user: @user,
      export_format: "excel",
      filter_config: { status: "approved" },
      columns_config: ["date", "amount", "description"]
    )
  end
  
  test "should be valid with all attributes" do
    assert @report_template.valid?
  end
  
  test "should require name" do
    @report_template.name = nil
    assert_not @report_template.valid?
    assert_includes @report_template.errors[:name], "can't be blank"
  end
  
  test "should require user" do
    @report_template.user = nil
    assert_not @report_template.valid?
    assert_includes @report_template.errors[:user], "must exist"
  end
  
  test "should require export_format" do
    @report_template.export_format = nil
    assert_not @report_template.valid?
    assert_includes @report_template.errors[:export_format], "can't be blank"
  end
  
  test "should validate export_format inclusion" do
    @report_template.export_format = "invalid"
    assert_not @report_template.valid?
    assert_includes @report_template.errors[:export_format], "is not included in the list"
  end
  
  test "should serialize filter_config as JSON" do
    @report_template.save!
    reloaded = ReportTemplate.find(@report_template.id)
    assert_equal "approved", reloaded.filter_config["status"]
  end
  
  test "should serialize columns_config as JSON" do
    @report_template.save!
    reloaded = ReportTemplate.find(@report_template.id)
    assert_equal ["date", "amount", "description"], reloaded.columns_config
  end
  
  test "filters method should return filter_config or empty hash" do
    assert_equal({ "status" => "approved" }, @report_template.filters)
    
    @report_template.filter_config = nil
    assert_equal({}, @report_template.filters)
  end
  
  test "columns method should return columns_config or default columns" do
    assert_equal ["date", "amount", "description"], @report_template.columns
    
    @report_template.columns_config = nil
    expected_defaults = ['date', 'user_name', 'organization_name', 'expense_code', 'amount', 'description', 'status']
    assert_equal expected_defaults, @report_template.columns
  end
  
  test "should have many report_exports" do
    @report_template.save!
    export1 = ReportExport.create!(report_template: @report_template, user: @user, status: 'pending')
    export2 = ReportExport.create!(report_template: @report_template, user: @user, status: 'completed')
    
    assert_equal 2, @report_template.report_exports.count
    assert_includes @report_template.report_exports, export1
    assert_includes @report_template.report_exports, export2
  end
  
  test "should be destroyed with dependent report_exports nullified" do
    @report_template.save!
    export = ReportExport.create!(report_template: @report_template, user: @user, status: 'pending')
    
    @report_template.destroy
    export.reload
    
    assert_nil export.report_template_id
  end
end
