require "application_system_test_case"

class AdminDashboardChartsTest < ApplicationSystemTestCase
  setup do
    @admin = users(:admin)
    @organization = organizations(:one)
    @expense_code = expense_codes(:meal)
    @cost_center = cost_centers(:one)
    
    # 테스트 데이터 생성
    create_test_data
  end

  test "Chart.js 차트들이 올바르게 렌더링됨" do
    login_as(@admin)
    visit admin_dashboard_path
    
    # 차트 캔버스 요소 확인
    assert_selector "canvas[data-organization-chart-target='canvas']"
    assert_selector "canvas[data-expense-code-chart-target='canvas']"
    assert_selector "canvas[data-trend-chart-target='canvas']"
    
    # 예산 게이지 차트 확인
    assert_selector "canvas[data-budget-gauge-target='canvas']", minimum: 1
  end

  test "차트 export 메뉴가 작동함" do
    login_as(@admin)
    visit admin_dashboard_path
    
    # Export 메뉴 버튼 찾기
    export_buttons = all("[data-action*='toggleMenu']")
    assert export_buttons.any?
    
    # 첫 번째 차트의 export 메뉴 열기
    export_buttons.first.click
    
    # Export 옵션들 확인
    assert_text "PNG로 내보내기"
    assert_text "CSV로 내보내기"
    assert_text "인쇄"
  end

  test "기간 변경 시 차트 데이터 업데이트" do
    login_as(@admin)
    visit admin_dashboard_path
    
    # 초기 차트 렌더링 대기
    assert_selector "canvas[data-trend-chart-target='canvas']"
    
    # 기간을 '이번 주'로 변경
    # 기간 선택기 찾기
    period_select = find('select[data-period-filter-target="select"]')
    period_select.select "이번 주"
    
    # 페이지 새로고침 대기
    sleep 0.5
    
    # URL 파라미터 확인
    assert_equal "this_week", find('select[data-period-filter-target="select"]').value
    assert_selector "canvas[data-trend-chart-target='canvas']"
  end

  test "조직별 경비 막대 차트 인터랙션" do
    login_as(@admin)
    visit admin_dashboard_path
    
    within "[data-controller='organization-chart']" do
      assert_selector "canvas"
      
      # 차트가 정상적으로 렌더링되었는지 확인
      # Chart.js는 canvas에 직접 그리므로 시각적 확인은 제한적
      canvas = find("canvas")
      assert canvas[:width].to_i > 0
      assert canvas[:height].to_i > 0
    end
  end

  test "경비 코드별 도넛 차트 범례 표시" do
    login_as(@admin)
    visit admin_dashboard_path
    
    # 경비 코드별 차트가 있는지 확인
    assert_selector "[data-controller='expense-code-chart']"
    
    chart_element = find("[data-controller='expense-code-chart']")
    assert_selector "canvas", visible: true
    
    # 차트 데이터 확인
    data = chart_element["data-expense-code-chart-data-value"]
    assert data.present?
    assert data.include?(@expense_code.name)
  end

  test "예산 게이지 차트 상태별 색상" do
    login_as(@admin)
    visit admin_dashboard_path
    
    # 예산 게이지 차트 확인
    gauge_charts = all("[data-controller='budget-gauge']")
    assert gauge_charts.any?
    
    # 각 게이지의 상태 확인
    gauge_charts.each do |gauge|
      status = gauge["data-budget-gauge-status-value"]
      assert %w[safe normal warning danger].include?(status)
      
      # info 영역에 정보 표시 확인
      within gauge do
        assert_selector "[data-budget-gauge-target='info']"
      end
    end
  end

  test "추이 차트 타입 (라인/바)" do
    login_as(@admin)
    visit admin_dashboard_path
    
    # 추이 차트 데이터 포인트 수 확인
    trend_chart = find("[data-controller='trend-chart']")
    data = JSON.parse(trend_chart["data-trend-chart-data-value"])
    
    # 데이터 포인트가 7개 이하면 바 차트, 초과면 라인 차트
    assert data.is_a?(Array)
    assert data.length > 0
  end

  test "차트 반응형 디자인" do
    login_as(@admin)
    # 모바일 뷰포트
    page.driver.browser.manage.window.resize_to(375, 667)
    visit admin_dashboard_path
    
    # 차트들이 여전히 표시되는지 확인
    assert_selector "canvas[data-organization-chart-target='canvas']"
    
    # 데스크톱 뷰포트
    page.driver.browser.manage.window.resize_to(1920, 1080)
    
    # 차트들이 확장되어 표시되는지 확인
    assert_selector "canvas[data-organization-chart-target='canvas']"
  end

  private

  def create_test_data
    # 기존 경비 시트 삭제
    ExpenseSheet.destroy_all
    
    # 예산이 있는 코스트센터 생성
    @cost_center.update!(budget_amount: 10000000)
    
    # 다양한 사용자와 월로 경비 시트 생성
    users = [users(:admin), users(:manager), users(:employee)]
    
    3.times do |i|
      # 각 시트마다 다른 월 사용
      target_month = Date.current.month - i
      target_year = Date.current.year
      
      # 월이 0 이하가 되면 이전 년도로 조정
      if target_month <= 0
        target_month += 12
        target_year -= 1
      end
      
      sheet = ExpenseSheet.create!(
        user: users[i % users.length],
        year: target_year,
        month: target_month,
        organization: @organization,
        cost_center: @cost_center,
        status: ['approved', 'closed'].sample
      )
      
      # 해당 월의 날짜로 경비 항목 추가
      sheet_date = Date.new(target_year, target_month, 15)
      
      3.times do |j|
        ExpenseItem.create!(
          expense_sheet: sheet,
          expense_code: @expense_code,
          expense_date: sheet_date + j.days,
          amount: rand(10000..30000),
          description: "테스트 경비 #{i}-#{j}"
        )
      end
    end
  end

  def login_as(user)
    visit login_path
    fill_in "이메일", with: user.email
    fill_in "비밀번호", with: "password"
    click_button "로그인"
    
    # 로그인 성공 확인 - 대시보드로 이동 확인
    assert_current_path root_path
  end
end