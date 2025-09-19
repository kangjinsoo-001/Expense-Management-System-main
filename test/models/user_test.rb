require "test_helper"

class UserTest < ActiveSupport::TestCase
  setup do
    @admin = users(:alice)
    @manager = users(:bob)
    @employee = users(:one)
    @organization = organizations(:one)
    @child_organization = organizations(:two)
  end

  test "admin can manage any organization" do
    assert @admin.can_manage_organization?(@organization)
    assert @admin.can_manage_organization?(@child_organization)
  end

  test "manager can manage their organization" do
    assert @manager.manager_of?(@child_organization)
    assert @manager.can_manage_organization?(@child_organization)
  end

  test "manager of parent organization can manage child organizations" do
    parent_manager = users(:alice)
    assert parent_manager.can_manage_organization?(@child_organization)
  end

  test "employee cannot manage organizations" do
    assert_not @employee.can_manage_organization?(@organization)
    assert_not @employee.can_manage_organization?(@child_organization)
  end

  test "can assign manager checks permissions correctly" do
    assert @admin.can_assign_manager?(@organization)
    assert @manager.can_assign_manager?(@child_organization)
    assert_not @employee.can_assign_manager?(@organization)
  end
end