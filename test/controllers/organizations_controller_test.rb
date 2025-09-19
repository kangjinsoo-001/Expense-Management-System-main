require "test_helper"

class OrganizationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @organization = organizations(:one)
    @admin = users(:alice)
    @manager = users(:bob)
    @employee = users(:one)
    log_in_as(@admin)
  end

  test "should get index" do
    get organizations_url
    assert_response :success
  end

  test "should get new" do
    get new_organization_url
    assert_response :success
  end

  test "should create organization" do
    assert_difference("Organization.count") do
      post organizations_url, params: { 
        organization: { 
          name: "New Organization", 
          code: "NEW001" 
        } 
      }
    end

    assert_redirected_to organization_url(Organization.last)
  end

  test "should show organization" do
    get organization_url(@organization)
    assert_response :success
  end

  test "should get edit" do
    get edit_organization_url(@organization)
    assert_response :success
  end

  test "should update organization" do
    patch organization_url(@organization), params: { 
      organization: { 
        name: "Updated Name" 
      } 
    }
    assert_redirected_to organization_url(@organization)
  end

  test "should soft delete organization" do
    # 하위 조직이 있는 경우 함께 삭제되므로 count는 감소할 수 있음
    delete organization_url(@organization)
    
    assert_redirected_to organizations_url
    @organization.reload
    assert_not_nil @organization.deleted_at
  end

  test "should assign manager to organization" do
    post assign_manager_organization_url(@organization), params: { user_id: @employee.id }
    
    assert_redirected_to organization_url(@organization)
    @organization.reload
    assert_equal @employee, @organization.manager
  end

  test "should remove manager from organization" do
    @organization.update(manager: @manager)
    
    delete remove_manager_organization_url(@organization)
    
    assert_redirected_to organization_url(@organization)
    @organization.reload
    assert_nil @organization.manager
  end

  test "employee should not be able to edit organization" do
    log_in_as(@employee)
    
    get edit_organization_url(@organization)
    assert_redirected_to organizations_url
  end

  test "manager should be able to edit their organization" do
    log_in_as(@manager)
    child_org = organizations(:two)
    
    get edit_organization_url(child_org)
    assert_response :success
  end

  test "should get manage users page" do
    get manage_users_organization_url(@organization)
    assert_response :success
  end

  test "should add user to organization" do
    user = users(:two)
    user.update(organization: nil)
    
    post add_user_organization_url(@organization), params: { user_id: user.id }
    
    assert_redirected_to manage_users_organization_path(@organization)
    user.reload
    assert_equal @organization, user.organization
  end

  test "should remove user from organization" do
    user = users(:one)
    user.update(organization: @organization)
    
    delete remove_user_organization_url(@organization), params: { user_id: user.id }
    
    assert_redirected_to manage_users_organization_path(@organization)
    user.reload
    assert_nil user.organization
  end

  test "should remove manager when removing user who is manager" do
    @organization.update(manager: @employee)
    @employee.update(organization: @organization)
    
    delete remove_user_organization_url(@organization), params: { user_id: @employee.id }
    
    @organization.reload
    assert_nil @organization.manager
  end

  private

  def log_in_as(user)
    post login_url, params: { 
      email: user.email, 
      password: "password" 
    }
  end
end