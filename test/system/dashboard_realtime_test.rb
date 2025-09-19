require "application_system_test_case"

class DashboardRealtimeTest < ApplicationSystemTestCase
  setup do
    @admin = users(:admin)
    login_as @admin
  end
  
  test "대시보드에서 실시간 연결 상태가 표시된다" do
    visit admin_dashboard_path
    
    # 실시간 연결 상태 확인
    assert_selector "[data-dashboard-realtime-target='connectionStatus']", text: "실시간 연결됨"
    assert_selector "[data-dashboard-realtime-target='connectionIcon']", text: "●"
    
    # 자동 새로고침 체크박스 확인
    assert_selector "input[data-dashboard-realtime-target='autoRefresh']:checked"
    
    # 최종 업데이트 시간 표시 확인
    assert_selector "[data-dashboard-realtime-target='lastUpdate']"
  end
  
  test "자동 새로고침을 토글할 수 있다" do
    visit admin_dashboard_path
    
    # 자동 새로고침 체크 해제
    uncheck "자동 새로고침"
    
    # 알림 메시지 확인
    assert_text "자동 새로고침 비활성화됨"
    
    # 다시 체크
    check "자동 새로고침"
    assert_text "자동 새로고침 활성화됨"
  end
  
  test "수동 새로고침 버튼이 작동한다" do
    visit admin_dashboard_path
    
    # 초기 데이터 확인
    initial_time = find("[data-dashboard-realtime-target='lastUpdate']").text
    
    # 수동 새로고침 클릭
    click_button "새로고침"
    
    # 알림 메시지 확인
    assert_text "대시보드를 새로고침했습니다"
    
    # 시간이 업데이트되었는지 확인 (약간의 지연 허용)
    sleep 1
    updated_time = find("[data-dashboard-realtime-target='lastUpdate']").text
    assert_not_equal initial_time, updated_time
  end
  
  test "경비 시트 제출 시 대시보드가 실시간으로 업데이트된다" do
    # 대시보드를 별도 창에서 열기
    dashboard_window = open_new_window
    within_window dashboard_window do
      visit admin_dashboard_path
      @initial_pending = find("#pending-approvals").text.to_i
      @initial_submissions = find("#today-submissions").text.to_i
    end
    
    # 메인 창에서 경비 시트 제출
    expense_sheet = expense_sheets(:jane_draft)
    visit expense_sheet_path(expense_sheet)
    
    # 경비 항목 추가
    click_link "경비 항목 추가"
    within "turbo-frame#new_expense_item" do
      select "교통비", from: "경비 코드"
      fill_in "금액", with: "50000"
      fill_in "사용일", with: Date.current
      fill_in "설명", with: "택시비"
      click_button "저장"
    end
    
    # 제출
    click_button "제출"
    assert_text "경비 시트가 성공적으로 제출되었습니다"
    
    # 대시보드 창으로 전환하여 업데이트 확인
    within_window dashboard_window do
      # 실시간 업데이트가 반영될 때까지 대기 (최대 5초)
      assert_selector "#pending-approvals", text: (@initial_pending + 1).to_s, wait: 5
      assert_selector "#today-submissions", text: (@initial_submissions + 1).to_s, wait: 5
      
      # 알림 메시지 확인
      assert_text "데이터가 실시간으로 업데이트되었습니다"
    end
  end
  
  test "승인 처리 시 대시보드가 실시간으로 업데이트된다" do
    # 승인 대기중인 경비 시트 준비
    expense_sheet = expense_sheets(:john_pending)
    approval_flow = expense_sheet.approval_flow
    
    # 대시보드 창 열기
    dashboard_window = open_new_window
    within_window dashboard_window do
      visit admin_dashboard_path
      @initial_pending = find("#pending-approvals").text.to_i
    end
    
    # 승인 처리
    visit approvals_path
    
    within "[data-approval-id='#{approval_flow.id}']" do
      fill_in "comment", with: "승인합니다"
      click_button "승인"
    end
    
    assert_text "승인 처리되었습니다"
    
    # 대시보드 창에서 업데이트 확인
    within_window dashboard_window do
      # 대기 중 승인 건수가 감소했는지 확인
      assert_selector "#pending-approvals", text: (@initial_pending - 1).to_s, wait: 5
      
      # 승인율 업데이트 확인
      assert_selector "[data-stat='approval_rate']"
    end
  end
  
  test "네트워크 연결이 끊겼다가 복구되면 상태가 업데이트된다" do
    visit admin_dashboard_path
    
    # 초기 연결 상태 확인
    assert_selector ".text-green-500", text: "실시간 연결됨"
    
    # ActionCable 연결 끊기 시뮬레이션
    page.execute_script("App.cable.disconnect()")
    
    # 연결 끊김 상태 확인
    assert_selector ".text-red-500", text: "연결 끊김", wait: 5
    
    # 연결 복구
    page.execute_script("App.cable.connect()")
    
    # 연결 복구 상태 확인
    assert_selector ".text-green-500", text: "실시간 연결됨", wait: 5
  end
end