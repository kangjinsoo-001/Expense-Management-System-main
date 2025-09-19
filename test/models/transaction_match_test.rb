require "test_helper"

class TransactionMatchTest < ActiveSupport::TestCase
  setup do
    @expense_sheet = expense_sheets(:current_month)
    @pdf_result = PdfAnalysisResult.create!(
      expense_sheet: @expense_sheet,
      attachment_id: "test-attachment-id",
      extracted_text: "테스트 PDF 내용",
      analysis_data: { pages: 1 }
    )
    # expense_item 생성 - fixture에 의존하지 않음
    @expense_item = ExpenseItem.create!(
      expense_sheet: @expense_sheet,
      expense_date: Date.new(2025, 7, 15),
      amount: 10000,
      description: "테스트 경비",
      expense_code: expense_codes(:one),
      cost_center: cost_centers(:one)
    )
  end

  test "유효한 매칭 생성" do
    match = TransactionMatch.new(
      pdf_analysis_result: @pdf_result,
      expense_item: @expense_item,
      transaction_data: {
        date: "2025-01-15",
        description: "점심식사",
        amount: 12000
      },
      confidence: 0.95,
      match_type: "exact"
    )
    
    assert match.valid?
    assert match.save
  end

  test "필수 속성 검증" do
    match = TransactionMatch.new
    
    assert_not match.valid?
    assert_includes match.errors[:pdf_analysis_result], "반드시 존재해야 합니다"
    assert_includes match.errors[:expense_item], "반드시 존재해야 합니다"
    assert_includes match.errors[:transaction_data], "입력해주세요"
    assert_includes match.errors[:confidence], "입력해주세요"
    assert_includes match.errors[:match_type], "입력해주세요"
  end

  test "신뢰도 범위 검증" do
    match = TransactionMatch.new(
      pdf_analysis_result: @pdf_result,
      expense_item: @expense_item,
      transaction_data: { amount: 1000 },
      confidence: 1.5,
      match_type: "exact"
    )
    
    assert_not match.valid?
    assert_includes match.errors[:confidence], "1보다 작거나 같아야 합니다"
    
    match.confidence = -0.1
    assert_not match.valid?
    assert_includes match.errors[:confidence], "0보다 크거나 같아야 합니다"
  end

  test "매칭 타입 검증" do
    match = TransactionMatch.new(
      pdf_analysis_result: @pdf_result,
      expense_item: @expense_item,
      transaction_data: { amount: 1000 },
      confidence: 0.8,
      match_type: "invalid_type"
    )
    
    assert_not match.valid?
    assert_includes match.errors[:match_type], "목록에 포함되어 있지 않습니다"
  end

  test "거래 데이터 접근 메서드" do
    match = TransactionMatch.create!(
      pdf_analysis_result: @pdf_result,
      expense_item: @expense_item,
      transaction_data: {
        date: "2025-01-15",
        description: "스타벅스 강남점",
        amount: 5500
      },
      confidence: 1.0,
      match_type: "exact"
    )
    
    assert_equal "2025-01-15", match.transaction_date
    assert_equal "스타벅스 강남점", match.transaction_description
    assert_equal 5500, match.transaction_amount
  end

  test "신뢰도 레벨 판단" do
    # 높은 신뢰도
    match = TransactionMatch.new(confidence: 0.95)
    assert match.high_confidence?
    
    # 중간 신뢰도
    match.confidence = 0.75
    assert match.medium_confidence?
    
    # 낮은 신뢰도
    match.confidence = 0.4
    assert match.low_confidence?
  end

  test "경비 항목과의 금액 차이 계산" do
    # @expense_item이 nil일 수 있으므로 안전하게 처리
    @expense_item ||= ExpenseItem.create!(
      expense_sheet: @expense_sheet,
      expense_date: Date.new(2025, 7, 15),
      amount: 10000,
      description: "테스트 경비",
      expense_code: expense_codes(:one),
      cost_center: cost_centers(:one)
    )
    @expense_item.update!(amount: 10000)
    
    match = TransactionMatch.create!(
      pdf_analysis_result: @pdf_result,
      expense_item: @expense_item,
      transaction_data: { amount: 9500 },
      confidence: 0.8,
      match_type: "amount_similar"
    )
    
    assert_equal 500, match.amount_difference
    assert_equal 5.0, match.amount_difference_percentage
  end

  test "매칭 타입별 라벨" do
    match = TransactionMatch.new(match_type: "exact")
    assert_equal "정확히 일치", match.match_type_label
    
    match.match_type = "amount_similar"
    assert_equal "금액 유사", match.match_type_label
    
    match.match_type = "text_similar"
    assert_equal "설명 유사", match.match_type_label
  end

  test "동일 경비 항목에 대한 중복 매칭 방지" do
    TransactionMatch.create!(
      pdf_analysis_result: @pdf_result,
      expense_item: @expense_item,
      transaction_data: { amount: 1000 },
      confidence: 0.9,
      match_type: "exact"
    )
    
    # 같은 경비 항목에 대한 두 번째 매칭 시도
    duplicate_match = TransactionMatch.new(
      pdf_analysis_result: @pdf_result,
      expense_item: @expense_item,
      transaction_data: { amount: 2000 },
      confidence: 0.8,
      match_type: "amount_similar"
    )
    
    assert_not duplicate_match.valid?
    assert_includes duplicate_match.errors[:expense_item_id], "이미 사용 중입니다"
  end
end
