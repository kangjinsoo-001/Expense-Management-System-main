require "test_helper"

class Admin::ApproverGroupsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get admin_approver_groups_index_url
    assert_response :success
  end

  test "should get show" do
    get admin_approver_groups_show_url
    assert_response :success
  end

  test "should get new" do
    get admin_approver_groups_new_url
    assert_response :success
  end

  test "should get create" do
    get admin_approver_groups_create_url
    assert_response :success
  end

  test "should get edit" do
    get admin_approver_groups_edit_url
    assert_response :success
  end

  test "should get update" do
    get admin_approver_groups_update_url
    assert_response :success
  end

  test "should get destroy" do
    get admin_approver_groups_destroy_url
    assert_response :success
  end
end
