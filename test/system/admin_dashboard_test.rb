require "application_system_test_case"

class AdminDashboardTest < ApplicationSystemTestCase
  setup do
    @admin = users(:admin)
    @organization = organizations(:one)
    @expense_code = expense_codes(:meal)
    @cost_center = cost_centers(:one)
    
    # 테스트 데이터 생성
    create_test_data
    
    # 관리자로 로그인
    login_as(@admin)
  end

  test "관리자 대시보드 메인 페이지 접근" do
    visit admin_dashboard_path
    
    assert_text "관리자 대시보드"
    assert_selector "h1", text: "관리자 대시보드"
    
    # 상단 요약 카드 확인
    assert_selector ".bg-white.shadow", count: 4
    assert_text "총 경비"
    assert_text "대기중 승인"
    assert_text "승인율"
    assert_text "예산 경고"
  end

  test "기간 필터 변경" do
    visit admin_dashboard_path
    
    # 기간 선택
    select "이번 주", from: "period"
    
    # 페이지가 새로고침되고 URL이 변경되었는지 확인
    assert_current_path admin_dashboard_path(period: "this_week")
    assert_selector "option[value='this_week'][selected]"
  end

  test "새로고침 버튼 동작" do
    visit admin_dashboard_path
    
    # 새로고침 버튼 클릭
    click_button "새로고침"
    
    # 페이지가 업데이트되었는지 확인
    assert_text "최종 업데이트:"
  end

  test "조직별 경비 차트 표시" do
    visit admin_dashboard_path
    
    within "#by_organization_chart" do
      assert_text @organization.name
      assert_selector ".bg-blue-500"  # 차트 바
    end
  end

  test "경비 코드별 차트 표시" do
    visit admin_dashboard_path
    
    within "#by_code_chart" do
      assert_text @expense_code.name
      assert_text @expense_code.code
      assert_selector ".bg-green-500"  # 차트 바
    end
  end

  test "예산 실행 현황 테이블" do
    visit admin_dashboard_path
    
    within "#budget-execution" do
      assert_text "코스트센터별 예산 실행 현황"
      assert_selector "table"
      assert_text @cost_center.name
      
      # 예산 상태 표시
      assert_selector ".rounded-full", text: /안전|정상|주의|위험/
    end
  end

  test "상위 지출자 목록" do
    visit admin_dashboard_path
    
    assert_text "상위 지출자"
    assert_selector "ul li", minimum: 1
  end

  test "기간 비교 섹션" do
    visit admin_dashboard_path
    
    assert_text "기간 비교"
    assert_text "현재 기간"
    assert_text "이전 기간"
    assert_text "변화량"
  end

  test "반응형 레이아웃 - 모바일" do
    # 모바일 뷰포트로 변경
    page.driver.browser.manage.window.resize_to(375, 667)
    
    visit admin_dashboard_path
    
    # 그리드가 단일 컬럼으로 변경되었는지 확인
    assert_selector ".grid-cols-1"
  end

  test "반응형 레이아웃 - 태블릿" do
    # 태블릿 뷰포트로 변경
    page.driver.browser.manage.window.resize_to(768, 1024)
    
    visit admin_dashboard_path
    
    # 그리드가 2 컬럼으로 변경되었는지 확인
    assert_selector ".sm\\:grid-cols-2"
  end

  test "관리자 권한 없으면 접근 불가" do
    logout
    login_as(users(:employee))
    
    visit admin_dashboard_path
    
    # 리다이렉트 또는 권한 오류 확인
    assert_current_path root_path
    assert_text "권한이 없습니다"
  end

  private

  def create_test_data
    # 테스트용 경비 시트 생성
    3.times do |i|
      sheet = ExpenseSheet.create!(
        user: @admin,
        year: Date.current.year,
        month: Date.current.month,
        organization: @organization,
        cost_center: @cost_center,
        status: 'approved'
      )
      
      # 경비 항목 추가
      2.times do |j|
        ExpenseItem.create!(
          expense_sheet: sheet,
          expense_code: @expense_code,
          expense_date: Date.current - j.days,
          amount: 50000,
          description: "테스트 경비 #{i}-#{j}"
        )
      end
    end
    
    # 승인 플로우 생성
    ApprovalFlow.create!(
      expense_sheet: ExpenseSheet.first,
      status: 'pending'
    )
  end

  def login_as(user)
    visit login_path
    fill_in "이메일", with: user.email
    fill_in "비밀번호", with: "password"
    click_button "로그인"
  end

  def logout
    click_button "로그아웃"
  end
end