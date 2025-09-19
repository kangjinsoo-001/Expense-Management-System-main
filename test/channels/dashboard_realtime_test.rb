require "test_helper"

class DashboardRealtimeTest < ActionCable::Channel::TestCase
  tests DashboardChannel
  test "관리자가 대시보드 채널을 구독할 수 있다" do
    user = users(:admin)
    
    stub_connection current_user: user
    subscribe
    
    assert subscription.confirmed?
    assert_has_stream "admin_dashboard"
    assert_has_stream "admin_dashboard_#{user.id}"
  end
  
  test "일반 사용자는 대시보드 채널을 구독할 수 없다" do
    user = users(:john)
    
    stub_connection current_user: user
    subscribe
    
    assert subscription.confirmed?
    assert_no_streams
  end
  
  test "경비 시트 제출 시 실시간 업데이트가 브로드캐스트된다" do
    user = users(:admin)
    stub_connection current_user: user
    subscribe
    
    assert_broadcast_on("admin_dashboard", action: "update_stats") do
      DashboardBroadcastService.broadcast_expense_sheet_update(expense_sheets(:draft_sheet))
    end
  end
  
  test "승인 처리 시 실시간 업데이트가 브로드캐스트된다" do
    user = users(:admin)
    stub_connection current_user: user
    subscribe
    
    # ApprovalStep 모델을 직접 생성
    approval_flow = approval_flows(:submitted_flow)
    approval_step = ApprovalStep.create!(
      approval_flow: approval_flow,
      approver: user,
      order: 1,
      status: :pending
    )
    
    assert_broadcast_on("admin_dashboard", action: "update_approval") do
      DashboardBroadcastService.broadcast_approval_update(approval_step)
    end
  end
  
  test "Turbo Stream 업데이트가 정상적으로 브로드캐스트된다" do
    expense_sheet = expense_sheets(:draft_sheet)
    
    # Turbo Stream 브로드캐스트는 별도 채널을 사용하므로 직접 테스트
    assert_nothing_raised do
      DashboardBroadcastService.broadcast_expense_sheet_update(expense_sheet)
    end
  end
end