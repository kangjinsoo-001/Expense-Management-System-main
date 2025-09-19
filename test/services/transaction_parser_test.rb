require "test_helper"

class TransactionParserTest < ActiveSupport::TestCase
  setup do
    @parser = TransactionParser.new
  end

  test "신한카드 거래 내역 파싱" do
    text = <<~TEXT
      신한카드 이용내역서
      
      01/15 스타벅스 강남점 5,500원
      01/20 GS25 편의점 12,300원
      02/01 네이버페이 충전 50,000원
    TEXT
    
    @parser = TransactionParser.new(:shinhan)
    result = @parser.parse_transactions(text)
    
    assert result[:success]
    assert_equal 3, result[:total_count]
    assert_equal 67800.0, result[:total_amount]
    
    # 첫 번째 거래 확인
    transaction = result[:transactions].first
    assert_equal Date.new(2025, 1, 15), transaction[:date]
    assert_equal "스타벅스 강남점", transaction[:description]
    assert_equal 5500.0, transaction[:amount]
  end

  test "삼성카드 거래 내역 파싱" do
    text = <<~TEXT
      삼성카드 청구서
      
      2025.01.15 커피빈 역삼점 4,500
      2025.01.18 이마트 성수점 123,456
      2025.02.01 쿠팡 온라인결제 35,000
    TEXT
    
    @parser = TransactionParser.new(:samsung)
    result = @parser.parse_transactions(text)
    
    assert result[:success]
    assert_equal 3, result[:total_count]
    assert_equal 162956.0, result[:total_amount]
    
    # 두 번째 거래 확인
    transaction = result[:transactions][1]
    assert_equal Date.new(2025, 1, 18), transaction[:date]
    assert_equal "이마트 성수점", transaction[:description]
    assert_equal 123456.0, transaction[:amount]
  end

  test "KB국민카드 거래 내역 파싱" do
    text = <<~TEXT
      KB국민카드 명세서
      
      01.10 CU편의점 승인 3,500원
      01.25 택시 승인 15,000원
      02.05 온라인쇼핑 승인 89,900원
    TEXT
    
    @parser = TransactionParser.new(:kb)
    result = @parser.parse_transactions(text)
    
    assert result[:success]
    assert_equal 3, result[:total_count]
    assert_equal 108400.0, result[:total_amount]
  end

  test "범용 거래 내역 파싱" do
    text = <<~TEXT
      2025-01-15 점심식사 12,000
      2025-01-20 교통비 3,200
      커피 01/25 4,500원
    TEXT
    
    result = @parser.parse_transactions(text)
    
    assert result[:success]
    assert result[:total_count] >= 2 # 최소 2개는 파싱되어야 함
  end

  test "경비 항목과 정확한 매칭" do
    # 거래 내역 파싱
    text = "07/15 점심식사 12,000원"
    @parser = TransactionParser.new(:shinhan)
    @parser.parse_transactions(text)
    
    # 경비 항목 생성
    expense_sheet = expense_sheets(:current_month)
    expense_item = ExpenseItem.create!(
      expense_sheet: expense_sheet,
      expense_date: Date.new(2025, 7, 15), # expense_sheet의 년월과 일치하도록 수정
      amount: 12000,
      description: "점심식사",
      expense_code: expense_codes(:meals),
      cost_center: cost_centers(:sales)
    )
    
    # 매칭 수행
    result = @parser.match_with_expense_items([expense_item])
    
    assert_equal 1, result[:matches].size
    assert_equal 1.0, result[:match_rate]
    
    match = result[:matches].first
    assert_equal expense_item, match[:expense_item]
    assert_equal 1.0, match[:confidence]
    assert_equal 'exact', match[:match_type]
  end

  test "금액 유사도 기반 매칭" do
    # 거래 내역 파싱
    text = "07/15 점심식사 12,000원"
    @parser = TransactionParser.new(:shinhan)
    @parser.parse_transactions(text)
    
    # 경비 항목 생성 (금액이 약간 다름)
    expense_sheet = expense_sheets(:current_month)
    expense_item = ExpenseItem.create!(
      expense_sheet: expense_sheet,
      expense_date: Date.new(2025, 7, 15),
      amount: 11500, # 500원 차이
      description: "비즈니스 런치",
      expense_code: expense_codes(:meals),
      cost_center: cost_centers(:sales)
    )
    
    # 매칭 수행
    result = @parser.match_with_expense_items([expense_item])
    
    assert_equal 1, result[:matches].size
    
    match = result[:matches].first
    assert_equal expense_item, match[:expense_item]
    assert_equal 0.8, match[:confidence]
    assert_equal 'amount_similar', match[:match_type]
  end

  test "텍스트 유사도 계산" do
    parser = TransactionParser.new
    
    # 정확히 일치
    assert_equal 1.0, parser.send(:text_similarity, "스타벅스", "스타벅스")
    
    # 부분 문자열 포함
    assert_equal 0.8, parser.send(:text_similarity, "스타벅스 강남점", "스타벅스")
    
    # 단어 일부 일치 - 한글에서는 동작이 다를 수 있음
    score = parser.send(:text_similarity, "coffee shop", "coffee bean")
    assert score > 0 && score < 1.0, "Expected score to be between 0 and 1.0, but got #{score}"
    
    # 전혀 다른 텍스트
    assert_equal 0.0, parser.send(:text_similarity, "스타벅스", "이마트")
  end

  test "매칭되지 않은 항목 처리" do
    # 거래 내역 파싱
    text = <<~TEXT
      07/15 점심식사 12,000원
      07/20 커피 4,500원
    TEXT
    @parser = TransactionParser.new(:shinhan)
    @parser.parse_transactions(text)
    
    # 경비 항목 생성 (매칭되지 않을 항목)
    expense_sheet = expense_sheets(:current_month)
    expense_item = ExpenseItem.create!(
      expense_sheet: expense_sheet,
      expense_date: Date.new(2025, 7, 1), # 다른 날짜 (같은 달)
      amount: 50000, # 다른 금액
      description: "사무용품",
      expense_code: expense_codes(:office_supplies),
      cost_center: cost_centers(:sales)
    )
    
    # 매칭 수행
    result = @parser.match_with_expense_items([expense_item])
    
    assert_equal 0, result[:matches].size
    assert_equal 2, result[:unmatched_transactions].size
    assert_equal 1, result[:unmatched_items].size
    assert_equal 0.0, result[:match_rate]
  end
end