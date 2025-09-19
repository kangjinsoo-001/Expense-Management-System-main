require "test_helper"

class PdfAnalysisResultTest < ActiveSupport::TestCase
  setup do
    @expense_sheet = expense_sheets(:current_month)
    @pdf_result = PdfAnalysisResult.new(
      expense_sheet: @expense_sheet,
      attachment_id: "12345",
      extracted_text: "Sample PDF text content",
      analysis_data: { pages: 1, extraction_errors: [] },
      card_type: "shinhan",
      detected_amounts: [{ amount: 10000, formatted: "₩10,000" }],
      detected_dates: [{ date: "2025-01-15", formatted: "2025-01-15" }]
    )
  end

  test "유효한 PDF 분석 결과 생성" do
    assert @pdf_result.valid?
  end

  test "attachment_id는 필수" do
    @pdf_result.attachment_id = nil
    assert_not @pdf_result.valid?
    assert_includes @pdf_result.errors[:attachment_id], "can't be blank"
  end

  test "attachment_id는 유니크해야 함" do
    @pdf_result.save!
    
    duplicate = @pdf_result.dup
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:attachment_id], "has already been taken"
  end

  test "expense_sheet는 필수" do
    @pdf_result.expense_sheet = nil
    assert_not @pdf_result.valid?
    assert_includes @pdf_result.errors[:expense_sheet], "must exist"
  end

  test "has_extracted_text? 메서드" do
    assert @pdf_result.has_extracted_text?
    
    @pdf_result.extracted_text = nil
    assert_not @pdf_result.has_extracted_text?
    
    @pdf_result.extracted_text = ""
    assert_not @pdf_result.has_extracted_text?
  end

  test "analyzed? 메서드" do
    assert @pdf_result.analyzed?
    
    @pdf_result.analysis_data = nil
    assert_not @pdf_result.analyzed?
    
    @pdf_result.analysis_data = {}
    assert @pdf_result.analyzed?
  end

  test "has_transactions? 메서드" do
    assert_not @pdf_result.has_transactions?
    
    @pdf_result.analysis_data['transactions'] = []
    assert_not @pdf_result.has_transactions?
    
    @pdf_result.analysis_data['transactions'] = [{ date: "2025-01-15", amount: 10000 }]
    assert @pdf_result.has_transactions?
  end

  test "filename 메서드" do
    # attachment가 없을 때
    assert_equal "Unknown", @pdf_result.filename
    
    # attachment 모킹
    attachment = Minitest::Mock.new
    blob = Minitest::Mock.new
    filename = Minitest::Mock.new
    
    filename.expect :to_s, "test_document.pdf"
    blob.expect :filename, filename
    attachment.expect :blob, blob
    
    ActiveStorage::Attachment.stub :find_by, attachment do
      assert_equal "test_document.pdf", @pdf_result.filename
    end
    
    attachment.verify
    blob.verify
    filename.verify
  end
end
