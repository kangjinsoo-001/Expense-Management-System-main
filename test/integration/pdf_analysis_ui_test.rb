require "test_helper"

class PdfAnalysisUiTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:employee_one)
    login_as(@user)
    
    # 로그인한 사용자의 경비 시트 생성
    @expense_sheet = ExpenseSheet.create!(
      user: @user,
      organization: @user.organization,
      year: 2025,
      month: 7,
      status: 'draft'
    )
    
    # 경비 항목 생성 - required_fields가 없는 expense_code 사용
    @expense_item = ExpenseItem.create!(
      expense_sheet: @expense_sheet,
      expense_date: Date.new(2025, 7, 15),
      amount: 12000,
      description: "점심 미팅",
      expense_code: expense_codes(:one),
      cost_center: cost_centers(:one)
    )
  end
  
  test "PDF 분석 결과가 없을 때는 섹션이 표시되지 않음" do
    get expense_sheet_path(@expense_sheet)
    assert_response :success
    
    # PDF 분석 결과 섹션이 없어야 함
    assert_select "[data-controller='pdf-analysis']", false
    assert_select "h3", text: "PDF 분석 결과", count: 0
  end
  
  test "PDF 분석 결과가 있을 때 섹션이 표시됨" do
    # PDF 분석 결과 생성
    pdf_result = PdfAnalysisResult.create!(
      expense_sheet: @expense_sheet,
      attachment_id: "test-attachment-123",
      extracted_text: "테스트 PDF 내용",
      analysis_data: {
        pages: 2,
        transactions: [
          { date: "2025-07-15", description: "점심 미팅", amount: 12000 }
        ],
        transaction_count: 1,
        match_rate: 1.0
      },
      card_type: "shinhan",
      total_amount: 12000,
      detected_amounts: [{ amount: 12000, original: "12,000원" }],
      detected_dates: [{ date: "2025-07-15", original: "07/15" }]
    )
    
    # 매칭 결과 생성
    TransactionMatch.create!(
      pdf_analysis_result: pdf_result,
      expense_item: @expense_item,
      transaction_data: { date: "2025-07-15", description: "점심 미팅", amount: 12000 },
      confidence: 1.0,
      match_type: "exact"
    )
    
    get expense_sheet_path(@expense_sheet)
    assert_response :success
    
    # PDF 분석 결과 섹션이 표시되어야 함
    assert_select "[data-controller='pdf-analysis']"
    assert_select "h3", text: "PDF 분석 결과"
    
    # 파일명과 카드사 정보
    assert_select "p.text-sm.font-medium", text: "Unknown" # attachment가 없어서 filename이 Unknown
    assert_select "p.text-xs", text: /신한카드/
    
    # 매칭률 표시
    assert_select "span", text: "100% 매칭"
    
    # 토글 버튼
    assert_select "button[data-action='click->pdf-analysis#toggleAll']"
  end
  
  test "PDF 분석 결과 상세 정보 토글" do
    # PDF 분석 결과 생성
    pdf_result = PdfAnalysisResult.create!(
      expense_sheet: @expense_sheet,
      attachment_id: "test-attachment-123",
      extracted_text: "테스트 PDF 내용",
      analysis_data: {
        pages: 1,
        transactions: [
          { date: "2025-07-15", description: "점심 미팅", amount: 12000 },
          { date: "2025-07-20", description: "사무용품", amount: 25000 }
        ],
        transaction_count: 2,
        match_rate: 0.5
      },
      card_type: "samsung",
      total_amount: 37000
    )
    
    # 일부만 매칭
    TransactionMatch.create!(
      pdf_analysis_result: pdf_result,
      expense_item: @expense_item,
      transaction_data: { date: "2025-07-15", description: "점심 미팅", amount: 12000 },
      confidence: 1.0,
      match_type: "exact"
    )
    
    get expense_sheet_path(@expense_sheet)
    assert_response :success
    
    # 상세 정보는 기본적으로 숨겨져 있어야 함
    assert_select "[data-pdf-analysis-target='details'].hidden"
    
    # 매칭된 거래 표시
    assert_select "h4", text: "매칭된 거래 내역"
    assert_select "p.text-sm.font-medium", text: /점심 미팅/
    
    # 매칭되지 않은 거래 표시
    assert_select "h4", text: "매칭되지 않은 거래 내역"
    assert_select "span.text-gray-700", text: /사무용품/
  end
  
  test "다양한 매칭 신뢰도 표시" do
    pdf_result = PdfAnalysisResult.create!(
      expense_sheet: @expense_sheet,
      attachment_id: "test-attachment-123",
      extracted_text: "테스트 PDF 내용",
      analysis_data: {
        pages: 1,
        transactions: [],
        transaction_count: 3,
        match_rate: 0.33
      },
      card_type: "kb",
      total_amount: 50000
    )
    
    # 다양한 신뢰도의 매칭 생성
    # 높은 신뢰도
    TransactionMatch.create!(
      pdf_analysis_result: pdf_result,
      expense_item: @expense_item,
      transaction_data: { date: "2025-07-15", description: "테스트1", amount: 10000 },
      confidence: 0.95,
      match_type: "exact"
    )
    
    get expense_sheet_path(@expense_sheet)
    assert_response :success
    
    # 신뢰도 표시 확인
    assert_select "span.text-xs.text-green-600", text: /신뢰도 95%/
  end
  
  test "금액 차이가 있는 경우 표시" do
    pdf_result = PdfAnalysisResult.create!(
      expense_sheet: @expense_sheet,
      attachment_id: "test-attachment-123",
      extracted_text: "테스트 PDF 내용",
      analysis_data: {
        pages: 1,
        transactions: [],
        transaction_count: 1,
        match_rate: 1.0
      },
      card_type: "shinhan",
      total_amount: 11500
    )
    
    # 금액이 약간 다른 매칭
    TransactionMatch.create!(
      pdf_analysis_result: pdf_result,
      expense_item: @expense_item,
      transaction_data: { date: "2025-07-15", description: "점심", amount: 11500 },
      confidence: 0.8,
      match_type: "amount_similar"
    )
    
    get expense_sheet_path(@expense_sheet)
    assert_response :success
    
    # 금액 차이 표시
    assert_select "p.text-xs.text-orange-600", text: /금액 차이/
  end
  
  test "PDF 업로드 폼과 분석 결과 연동" do
    get expense_sheet_path(@expense_sheet)
    assert_response :success
    
    # PDF 업로드 폼이 있어야 함
    assert_select "form[action='#{attach_pdf_expense_sheet_path(@expense_sheet)}']"
    assert_select "input[type='file'][accept='application/pdf']"
    assert_select "input[type='submit'][value='업로드']"
  end
  
  private
  
  def login_as(user)
    post login_url, params: { email: user.email, password: 'password' }
  end
end