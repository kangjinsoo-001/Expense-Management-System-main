require "test_helper"

class OrganizationTest < ActiveSupport::TestCase
  def setup
    @company = Organization.create!(name: "회사", code: "COMPANY")
    @division = Organization.create!(name: "영업부", code: "SALES", parent: @company)
    @team = Organization.create!(name: "영업1팀", code: "SALES1", parent: @division)
    @user = users(:one)
  end

  test "should be valid with required attributes" do
    org = Organization.new(name: "개발부", code: "DEV")
    assert org.valid?
  end

  test "should require name" do
    org = Organization.new(code: "TEST")
    assert_not org.valid?
    assert_includes org.errors[:name], "can't be blank"
  end

  test "should require code" do
    org = Organization.new(name: "테스트")
    assert_not org.valid?
    assert_includes org.errors[:code], "can't be blank"
  end

  test "should have unique code" do
    duplicate = Organization.new(name: "중복부서", code: "COMPANY")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:code], "has already been taken"
  end

  test "should not allow self as parent" do
    @company.parent = @company
    assert_not @company.valid?
    assert_includes @company.errors[:parent], "자기 자신을 상위 조직으로 설정할 수 없습니다"
  end

  test "should not allow circular reference" do
    @company.parent = @team
    assert_not @company.valid?
    assert_includes @company.errors[:parent], "순환 참조가 발생합니다"
  end

  test "ancestors should return parent hierarchy" do
    ancestors = @team.ancestors
    assert_equal [@company, @division], ancestors
  end

  test "descendants should return all children" do
    descendants = @company.descendants
    assert_equal [@division, @team], descendants
  end

  test "depth should return level in hierarchy" do
    assert_equal 0, @company.depth
    assert_equal 1, @division.depth
    assert_equal 2, @team.depth
  end

  test "root? should identify root organization" do
    assert @company.root?
    assert_not @division.root?
    assert_not @team.root?
  end

  test "leaf? should identify leaf organization" do
    assert_not @company.leaf?
    assert_not @division.leaf?
    assert @team.leaf?
  end

  test "full_path should return complete hierarchy path" do
    assert_equal "회사", @company.full_path
    assert_equal "회사 > 영업부", @division.full_path
    assert_equal "회사 > 영업부 > 영업1팀", @team.full_path
  end

  test "should add and remove users" do
    @team.add_user(@user)
    assert_includes @team.users, @user
    
    @team.remove_user(@user)
    assert_not_includes @team.users, @user
  end

  test "all_users should include users from descendants" do
    user1 = users(:one)
    user2 = users(:two)
    
    @division.users << user1
    @team.users << user2
    
    all_users = @company.all_users
    assert_includes all_users, user1
    assert_includes all_users, user2
  end

  test "soft_delete should mark as deleted with timestamp" do
    @team.soft_delete
    assert_not_nil @team.deleted_at
  end

  test "soft_delete should cascade to children" do
    @company.soft_delete
    @division.reload
    @team.reload
    
    assert_not_nil @company.deleted_at
    assert_not_nil @division.deleted_at
    assert_not_nil @team.deleted_at
  end

  test "default scope should exclude deleted organizations" do
    @team.soft_delete
    
    organizations = Organization.all
    assert_not_includes organizations, @team
  end

  test "deleted scope should only show deleted organizations" do
    @team.soft_delete
    
    deleted_orgs = Organization.deleted
    assert_includes deleted_orgs, @team
    assert_not_includes deleted_orgs, @company
  end

  test "restore should clear deleted_at" do
    @team.soft_delete
    assert_not_nil @team.deleted_at
    
    @team.restore
    assert_nil @team.deleted_at
  end

  test "should assign manager and update user role" do
    user = users(:one)
    assert @company.assign_manager(user)
    assert_equal user, @company.manager
    assert user.reload.manager?
  end

  test "should not change admin role when assigning as manager" do
    admin = users(:alice)
    @company.assign_manager(admin)
    assert admin.reload.admin?
  end

  test "should change previous manager role to employee" do
    manager = users(:bob)
    @company.update(manager: manager)
    manager.update(role: :manager)
    
    new_manager = users(:one)
    @company.assign_manager(new_manager)
    assert manager.reload.employee?
  end

  test "should remove manager" do
    manager = users(:bob)
    @company.update(manager: manager)
    assert @company.remove_manager
    assert_nil @company.reload.manager
  end

  test "should get manager candidates from organization users" do
    @company.users << @user
    candidates = @company.manager_candidates
    assert_includes candidates, @user
  end
end
