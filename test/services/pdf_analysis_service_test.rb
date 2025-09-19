require "test_helper"
require "minitest/autorun"

class PdfAnalysisServiceTest < ActiveSupport::TestCase
  setup do
    @service = PdfAnalysisService.new
    @pdf_path = Rails.root.join('test/fixtures/files/test_with_text.pdf')
  end

  test "PDF에서 텍스트 추출 성공" do
    File.open(@pdf_path, 'rb') do |file|
      result = @service.extract_text(file)
      
      assert result[:success]
      assert_equal 1, result[:total_pages]
      assert result[:full_text].present?
      # PDF 내용이 정확하게 추출되는지 확인
    end
  end

  test "손상된 PDF 처리" do
    # 잘못된 PDF 파일 시뮬레이션
    corrupted_file = StringIO.new("This is not a PDF")
    result = @service.extract_text(corrupted_file)
    
    assert_not result[:success]
    assert result[:errors].any?
  end

  test "금액 패턴 찾기" do
    text = "총 금액: 150,000원\n결제액: ₩ 25,000\nKRW 30,000\n50000 won"
    amounts = @service.find_amounts(text)
    
    # 금액만 추출 (중복 제거)
    unique_amounts = amounts.map { |a| a[:amount] }.uniq
    assert_equal 4, unique_amounts.size
    assert unique_amounts.include?(150000.0)
    assert unique_amounts.include?(25000.0)
    assert unique_amounts.include?(30000.0)
    assert unique_amounts.include?(50000.0)
  end

  test "날짜 패턴 찾기" do
    text = "거래일: 2025년 1월 15일\n승인일: 2025-01-20\n결제일: 2025.01.25"
    dates = @service.find_dates(text)
    
    assert dates.size >= 3
    formatted_dates = dates.map { |d| d[:formatted] }
    assert formatted_dates.include?("2025-01-15")
    assert formatted_dates.include?("2025-01-20")
    assert formatted_dates.include?("2025-01-25")
  end

  test "카드사 타입 감지" do
    card_types = {
      "신한카드 이용내역서" => :shinhan,
      "SAMSUNG CARD Statement" => :samsung,
      "KB국민카드 청구서" => :kb,
      "우리카드 명세서" => :woori,
      "하나카드 이용대금명세서" => :hana,
      "롯데카드 청구서" => :lotte,
      "BC카드 이용내역" => :bc,
      "NH농협카드 명세서" => :nh,
      "Unknown Card Statement" => :unknown
    }
    
    card_types.each do |text, expected_type|
      assert_equal expected_type, @service.detect_card_statement_type(text)
    end
  end

  test "한글 인코딩 처리" do
    # CP949 인코딩된 텍스트 시뮬레이션
    text = "한글 텍스트 테스트"
    encoded_text = text.encode('CP949')
    
    # ensure_utf8_encoding 메서드를 public으로 테스트
    result = @service.send(:ensure_utf8_encoding, encoded_text)
    
    assert result.valid_encoding?
    # UTF-8로 변환되었는지 확인
    assert_equal "한글 텍스트 테스트", result
  end

  test "Active Storage blob에서 텍스트 추출" do
    # Active Storage blob 모킹
    blob = Minitest::Mock.new
    blob.expect :open, nil do |&block|
      File.open(@pdf_path, 'rb') { |file| block.call(file) }
    end
    
    result = @service.extract_text_from_blob(blob)
    
    assert result[:success]
    assert result[:full_text].present?
    blob.verify
  end
  
  test "전체 분석 및 파싱 플로우" do
    expense_sheet = expense_sheets(:current_month)
    
    # 경비 항목 생성
    expense_item = ExpenseItem.create!(
      expense_sheet: expense_sheet,
      expense_date: Date.new(2025, 7, 15),
      amount: 12000,
      description: "점심식사",
      expense_code: expense_codes(:one),
      cost_center: cost_centers(:one)
    )
    
    # 테스트 PDF 생성
    require 'prawn'
    pdf_file = Tempfile.new(['test_analysis', '.pdf'])
    
    Prawn::Document.generate(pdf_file.path) do |pdf|
      pdf.font_families.update("NotoSans" => {
        normal: Rails.root.join("test/fixtures/fonts/NotoSansCJK-Regular.ttc").to_s
      }) if File.exist?(Rails.root.join("test/fixtures/fonts/NotoSansCJK-Regular.ttc"))
      
      # 한글 지원 폰트가 없으면 영문으로 대체
      begin
        pdf.text "신한카드 이용내역서"
        pdf.text "07/15 점심식사 12,000원"
        pdf.text "07/20 커피 4,500원"
      rescue Prawn::Errors::IncompatibleStringEncoding
        pdf.text "Shinhan Card Statement"
        pdf.text "07/15 Lunch 12,000 KRW"
        pdf.text "07/20 Coffee 4,500 KRW"
      end
    end
    
    File.open(pdf_file.path, 'rb') do |file|
      result = @service.analyze_and_parse(file, expense_sheet)
      
      assert result[:success]
      assert_equal :shinhan, result[:card_type]
      assert_equal 2, result[:parsing][:total_count]
      assert_equal 16500.0, result[:parsing][:total_amount]
      
      # 매칭 결과 확인
      assert_equal 1, result[:matching][:matches].size
      assert_equal 0.5, result[:matching][:match_rate]
      
      match = result[:matching][:matches].first
      assert_equal expense_item, match[:expense_item]
      assert_equal 1.0, match[:confidence]
      assert_equal 'exact', match[:match_type]
    end
    
    pdf_file.unlink
  end
  
  test "빈 PDF 처리" do
    require 'prawn'
    pdf_file = Tempfile.new(['empty', '.pdf'])
    
    Prawn::Document.generate(pdf_file.path) do |pdf|
      # 빈 페이지만 생성
    end
    
    File.open(pdf_file.path, 'rb') do |file|
      result = @service.extract_text(file)
      
      assert result[:success]
      assert_equal "", result[:full_text].strip
    end
    
    pdf_file.unlink
  end
  
  test "여러 페이지 PDF 처리" do
    require 'prawn'
    pdf_file = Tempfile.new(['multi_page', '.pdf'])
    
    Prawn::Document.generate(pdf_file.path) do |pdf|
      pdf.text "Page 1 Content"
      pdf.start_new_page
      pdf.text "Page 2 Content"
      pdf.start_new_page
      pdf.text "Page 3 Content"
    end
    
    File.open(pdf_file.path, 'rb') do |file|
      result = @service.extract_text(file)
      
      assert result[:success]
      assert_equal 3, result[:total_pages]
      assert_equal 3, result[:pages].size
      
      # 각 페이지 텍스트 확인
      result[:pages].each_with_index do |page, index|
        assert_equal index + 1, page[:page_number]
        assert page[:text].include?("Page #{index + 1}")
      end
    end
    
    pdf_file.unlink
  end
  
  test "페이지별 오류 처리" do
    # 일부 페이지에서 오류가 발생해도 계속 처리되는지 확인
    service = PdfAnalysisService.new
    
    # PDF::Reader 모킹
    reader_mock = Minitest::Mock.new
    page1_mock = Minitest::Mock.new
    page2_mock = Minitest::Mock.new
    
    # 첫 번째 페이지는 정상
    page1_mock.expect :text, "Page 1 text"
    
    # 두 번째 페이지는 오류 발생
    page2_mock.expect :text, nil do
      raise StandardError, "Page read error"
    end
    
    reader_mock.expect :pages, [page1_mock, page2_mock]
    reader_mock.expect :page_count, 2
    
    PDF::Reader.stub :new, reader_mock do
      result = service.extract_text(StringIO.new("fake pdf"))
      
      assert result[:success]
      assert_equal 1, result[:pages].size
      assert_equal 1, result[:errors].size
      assert result[:errors].first.include?("페이지 2 읽기 실패")
    end
  end
  
  test "다양한 금액 형식 추출" do
    text = <<~TEXT
      1,234,567원
      ₩ 98,765
      KRW 12,345
      56789 won
      123.45
      원화 50,000
      -15,000원 (취소)
    TEXT
    
    amounts = @service.find_amounts(text)
    
    # 모든 금액이 추출되었는지 확인
    extracted_amounts = amounts.map { |a| a[:amount] }
    assert extracted_amounts.include?(1234567.0)
    assert extracted_amounts.include?(98765.0)
    assert extracted_amounts.include?(12345.0)
    assert extracted_amounts.include?(56789.0)
    assert extracted_amounts.include?(123.45)
    assert extracted_amounts.include?(50000.0)
    assert extracted_amounts.include?(15000.0)
  end
  
  test "다양한 날짜 형식 추출" do
    text = <<~TEXT
      2025년 7월 15일
      2025-07-20
      2025.07.25
      25.07.30
      07/15
      7월 1일
    TEXT
    
    dates = @service.find_dates(text)
    
    # 최소한의 날짜가 추출되었는지 확인
    assert dates.size >= 4
    
    # 연도가 없는 날짜는 현재 연도로 처리되는지 확인
    current_year_date = dates.find { |d| d[:original] == "07/15" }
    if current_year_date
      assert_equal Date.current.year, current_year_date[:date].year
    end
  end
  
  test "카드 명세서가 아닌 PDF 처리" do
    text = "일반 문서입니다. 카드 명세서가 아닙니다."
    
    card_type = @service.detect_card_statement_type(text)
    assert_equal :unknown, card_type
  end
end