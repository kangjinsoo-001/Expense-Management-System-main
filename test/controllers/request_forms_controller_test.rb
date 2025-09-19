require "test_helper"

class RequestFormsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get request_forms_index_url
    assert_response :success
  end

  test "should get new" do
    get request_forms_new_url
    assert_response :success
  end

  test "should get create" do
    get request_forms_create_url
    assert_response :success
  end

  test "should get show" do
    get request_forms_show_url
    assert_response :success
  end

  test "should get edit" do
    get request_forms_edit_url
    assert_response :success
  end

  test "should get update" do
    get request_forms_update_url
    assert_response :success
  end
end
