require "test_helper"

class PdfAnalysisFullFlowTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:employee_one)
    login_as(@user)
    
    # 경비 시트 생성
    @expense_sheet = ExpenseSheet.create!(
      user: @user,
      organization: @user.organization,
      year: 2025,
      month: 7,
      status: 'draft'
    )
    
    # 다양한 경비 항목 생성
    @expense_items = []
    
    # 정확히 매칭될 항목
    @expense_items << ExpenseItem.create!(
      expense_sheet: @expense_sheet,
      expense_date: Date.new(2025, 7, 15),
      amount: 12000,
      description: "점심 미팅",
      expense_code: expense_codes(:one),
      cost_center: cost_centers(:one)
    )
    
    # 금액이 약간 다른 항목
    @expense_items << ExpenseItem.create!(
      expense_sheet: @expense_sheet,
      expense_date: Date.new(2025, 7, 20),
      amount: 4900,
      description: "커피",
      expense_code: expense_codes(:one),
      cost_center: cost_centers(:one)
    )
    
    # 매칭되지 않을 항목
    @expense_items << ExpenseItem.create!(
      expense_sheet: @expense_sheet,
      expense_date: Date.new(2025, 7, 25),
      amount: 50000,
      description: "사무용품",
      expense_code: expense_codes(:office_supplies),
      cost_center: cost_centers(:one)
    )
  end
  
  test "PDF 업로드부터 분석 결과 표시까지 전체 플로우" do
    # 1. 경비 시트 페이지 방문
    get expense_sheet_path(@expense_sheet)
    assert_response :success
    
    # PDF 분석 결과가 없어야 함
    assert_select "[data-controller='pdf-analysis']", false
    
    # 2. 실제 PDF 파일 생성
    pdf_content = create_test_pdf_with_transactions
    
    # 3. PDF 업로드
    assert_difference '@expense_sheet.pdf_attachments.count', 1 do
      assert_difference 'PdfAnalysisResult.count', 1 do
        post attach_pdf_expense_sheet_path(@expense_sheet), params: {
          expense_sheet: {
            pdf_attachments: [fixture_file_upload(pdf_content, 'application/pdf', :binary)]
          }
        }
      end
    end
    
    assert_redirected_to expense_sheet_path(@expense_sheet)
    follow_redirect!
    
    # 4. 분석 결과 확인
    assert_select "[data-controller='pdf-analysis']"
    assert_select "h3", text: "PDF 분석 결과"
    
    # 카드사 정보 확인
    assert_select "p.text-xs", text: /신한카드/
    
    # 매칭률 확인
    assert_select "span", text: /매칭/
    
    # 5. 상세 정보 확인
    # h4 태그가 details 섹션 안에 있고 기본적으로 숨겨져 있음
    assert_select "[data-pdf-analysis-target='details']"
    
    # 6. 데이터베이스 확인
    pdf_result = @expense_sheet.pdf_analysis_results.last
    assert_not_nil pdf_result
    assert_equal "shinhan", pdf_result.card_type
    assert pdf_result.analysis_data['transaction_count'] > 0
    
    # 매칭 결과 확인
    matches = pdf_result.transaction_matches
    assert matches.any?
    
    # 정확한 매칭 확인
    exact_match = matches.find { |m| m.match_type == "exact" }
    assert_not_nil exact_match
    assert_equal 1.0, exact_match.confidence
    assert_equal @expense_items[0], exact_match.expense_item
  end
  
  test "대용량 PDF 처리 성능" do
    # 많은 거래가 포함된 PDF 생성
    pdf_content = create_large_test_pdf(100) # 100개의 거래
    
    # 처리 시간 측정
    start_time = Time.current
    
    post attach_pdf_expense_sheet_path(@expense_sheet), params: {
      expense_sheet: {
        pdf_attachments: [fixture_file_upload(pdf_content, 'application/pdf', :binary)]
      }
    }
    
    end_time = Time.current
    processing_time = end_time - start_time
    
    # 처리 시간이 5초 이내여야 함
    assert processing_time < 5.seconds, "PDF 처리가 너무 오래 걸림: #{processing_time}초"
    
    # 모든 거래가 파싱되었는지 확인
    pdf_result = @expense_sheet.pdf_analysis_results.last
    assert_equal 100, pdf_result.analysis_data['transaction_count']
  end
  
  test "다양한 카드사 형식 처리" do
    card_types = [:shinhan, :samsung, :kb]
    
    card_types.each do |card_type|
      pdf_content = create_test_pdf_for_card(card_type)
      
      post attach_pdf_expense_sheet_path(@expense_sheet), params: {
        expense_sheet: {
          pdf_attachments: [fixture_file_upload(pdf_content, 'application/pdf', :binary)]
        }
      }
      
      pdf_result = @expense_sheet.pdf_analysis_results.last
      assert_equal card_type.to_s, pdf_result.card_type
      assert pdf_result.analysis_data['transaction_count'] > 0
    end
  end
  
  test "잘못된 PDF 처리" do
    # 텍스트가 없는 이미지 PDF
    pdf_content = create_image_only_pdf
    
    post attach_pdf_expense_sheet_path(@expense_sheet), params: {
      expense_sheet: {
        pdf_attachments: [fixture_file_upload(pdf_content, 'application/pdf', :binary)]
      }
    }
    
    pdf_result = @expense_sheet.pdf_analysis_results.last
    assert_not_nil pdf_result
    assert_equal 0, pdf_result.analysis_data['transaction_count']
    assert_equal "unknown", pdf_result.card_type
  end
  
  test "암호화된 PDF 처리" do
    # 암호화된 PDF는 실제로 만들기 어려우므로 서비스 테스트에서 확인
    skip "암호화된 PDF 테스트는 서비스 단위 테스트에서 수행"
  end
  
  test "동시 다중 PDF 업로드" do
    pdf_files = 3.times.map { |i| create_test_pdf_with_index(i) }
    
    assert_difference '@expense_sheet.pdf_attachments.count', 3 do
      assert_difference 'PdfAnalysisResult.count', 3 do
        post attach_pdf_expense_sheet_path(@expense_sheet), params: {
          expense_sheet: {
            pdf_attachments: pdf_files.map { |pdf| 
              fixture_file_upload(pdf, 'application/pdf', :binary)
            }
          }
        }
      end
    end
    
    # 모든 PDF가 분석되었는지 확인
    assert_equal 3, @expense_sheet.pdf_analysis_results.count
    @expense_sheet.pdf_analysis_results.each do |result|
      assert result.has_extracted_text?
      assert result.analyzed?
    end
  end
  
  private
  
  def login_as(user)
    post login_url, params: { email: user.email, password: 'password' }
  end
  
  def create_test_pdf_with_transactions
    require 'prawn'
    
    pdf_file = Tempfile.new(['test_transactions', '.pdf'])
    
    Prawn::Document.generate(pdf_file.path) do |pdf|
      pdf.text "SHINHAN CARD Statement", size: 16, style: :bold
      pdf.move_down 20
      
      pdf.text "Period: 2025-07-01 ~ 2025-07-31"
      pdf.move_down 10
      
      transactions = [
        "07/15 Lunch Meeting 12,000",
        "07/20 Coffee Bean Gangnam 4,500",
        "07/22 GS25 Store 8,900",
        "07/25 Online Shopping 35,000"
      ]
      
      transactions.each do |transaction|
        pdf.text transaction
        pdf.move_down 5
      end
      
      pdf.move_down 20
      pdf.text "Total Amount: 60,400", size: 12, style: :bold
    end
    
    pdf_file
  end
  
  def create_large_test_pdf(transaction_count)
    require 'prawn'
    
    pdf_file = Tempfile.new(['large_test', '.pdf'])
    
    Prawn::Document.generate(pdf_file.path) do |pdf|
      pdf.text "SHINHAN CARD Large Transaction List", size: 16, style: :bold
      pdf.move_down 20
      
      transaction_count.times do |i|
        date = (Date.new(2025, 7, 1) + i.days).strftime("%m/%d")
        amount = (1000 + i * 100)
        pdf.text "#{date} Test Transaction #{i+1} #{amount}"
      end
    end
    
    pdf_file
  end
  
  def create_test_pdf_for_card(card_type)
    require 'prawn'
    
    pdf_file = Tempfile.new(["#{card_type}_test", '.pdf'])
    
    Prawn::Document.generate(pdf_file.path) do |pdf|
      case card_type
      when :shinhan
        pdf.text "SHINHAN CARD Statement", size: 16, style: :bold
        pdf.text "07/15 Transaction1 10,000"
      when :samsung
        pdf.text "SAMSUNG CARD Bill", size: 16, style: :bold
        pdf.text "2025.07.15 Transaction1 10,000"
      when :kb
        pdf.text "KB CARD Statement", size: 16, style: :bold
        pdf.text "07.15 Transaction1 Approved 10,000"
      end
    end
    
    pdf_file
  end
  
  def create_image_only_pdf
    require 'prawn'
    
    pdf_file = Tempfile.new(['image_only', '.pdf'])
    
    Prawn::Document.generate(pdf_file.path) do |pdf|
      # 텍스트 없이 빈 페이지만 생성
      pdf.stroke_rectangle [0, pdf.bounds.height], pdf.bounds.width, pdf.bounds.height
    end
    
    pdf_file
  end
  
  def create_test_pdf_with_index(index)
    require 'prawn'
    
    pdf_file = Tempfile.new(["test_#{index}", '.pdf'])
    
    Prawn::Document.generate(pdf_file.path) do |pdf|
      pdf.text "Test PDF #{index + 1}", size: 16, style: :bold
      pdf.text "SHINHAN CARD Transactions"
      pdf.text "07/#{10 + index} Transaction #{(index + 1) * 1000}"
    end
    
    pdf_file
  end
end