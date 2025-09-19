require "test_helper"

class Admin::ReportsControllerTest < ActionDispatch::IntegrationTest
  def setup
    @user = users(:john)
    @admin = users(:jane)
    @admin.update(role: 'admin')
    sign_in_as(@admin)
  end

  test "should get index" do
    get admin_reports_url
    assert_response :success
  end

  test "should get new" do
    get new_admin_report_url
    assert_response :success
  end

  test "should export report" do
    post export_admin_reports_url, params: {
      report: {
        export_format: 'excel',
        filters: { status: 'approved' }
      }
    }
    assert_response :redirect
  end

  private

  def sign_in_as(user)
    post login_url, params: { email: user.email, password: 'password' }
  end
end
