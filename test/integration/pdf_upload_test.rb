require "test_helper"

class PdfUploadTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:employee)
    @expense_sheet = expense_sheets(:current_month)
    
    post login_path, params: { 
      email: @user.email, 
      password: 'password' 
    }
  end

  test "경비 시트에 PDF 업로드 가능" do
    assert_difference ['@expense_sheet.pdf_attachments.count', '@expense_sheet.pdf_analysis_results.count'], 1 do
      post attach_pdf_expense_sheet_path(@expense_sheet), params: {
        expense_sheet: {
          pdf_attachments: [fixture_file_upload('test.pdf', 'application/pdf')]
        }
      }
    end

    assert_redirected_to @expense_sheet
    follow_redirect!
    assert_match 'PDF 파일이 성공적으로 업로드되고 분석되었습니다', response.body
    
    # PDF 분석 결과 확인
    analysis_result = @expense_sheet.pdf_analysis_results.last
    assert analysis_result.present?
    assert analysis_result.has_extracted_text?
  end

  test "제출된 경비 시트에는 PDF 업로드 불가" do
    @expense_sheet.update!(status: 'submitted')
    
    assert_no_difference '@expense_sheet.pdf_attachments.count' do
      post attach_pdf_expense_sheet_path(@expense_sheet), params: {
        expense_sheet: {
          pdf_attachments: [fixture_file_upload('test.pdf', 'application/pdf')]
        }
      }
    end

    assert_redirected_to @expense_sheet
    follow_redirect!
    assert_match 'PDF를 첨부할 수 없는 상태입니다', response.body
  end

  test "PDF 파일 삭제 가능" do
    # PDF 파일 첨부
    @expense_sheet.pdf_attachments.attach(
      io: File.open(Rails.root.join('test/fixtures/files/test.pdf')),
      filename: 'test.pdf',
      content_type: 'application/pdf'
    )
    attachment = @expense_sheet.pdf_attachments.first

    assert_difference '@expense_sheet.pdf_attachments.count', -1 do
      delete delete_pdf_attachment_expense_sheet_path(@expense_sheet, attachment_id: attachment.id)
    end

    assert_redirected_to @expense_sheet
    follow_redirect!
    assert_match 'PDF 파일이 삭제되었습니다', response.body
  end

  test "제출된 경비 시트에서는 PDF 삭제 불가" do
    # PDF 파일 첨부
    @expense_sheet.pdf_attachments.attach(
      io: File.open(Rails.root.join('test/fixtures/files/test.pdf')),
      filename: 'test.pdf',
      content_type: 'application/pdf'
    )
    attachment = @expense_sheet.pdf_attachments.first
    
    @expense_sheet.update!(status: 'submitted')

    assert_no_difference '@expense_sheet.pdf_attachments.count' do
      delete delete_pdf_attachment_expense_sheet_path(@expense_sheet, attachment_id: attachment.id)
    end

    assert_redirected_to @expense_sheet
    follow_redirect!
    assert_match 'PDF를 삭제할 수 없는 상태입니다', response.body
  end

  test "업로드된 PDF 파일 목록 표시" do
    # 여러 PDF 파일 첨부
    @expense_sheet.pdf_attachments.attach([
      { io: File.open(Rails.root.join('test/fixtures/files/test.pdf')), 
        filename: 'receipt1.pdf', content_type: 'application/pdf' },
      { io: File.open(Rails.root.join('test/fixtures/files/test.pdf')), 
        filename: 'receipt2.pdf', content_type: 'application/pdf' }
    ])

    get expense_sheet_path(@expense_sheet)
    assert_response :success

    assert_select 'div.bg-white.shadow-sm.rounded-lg' do
      assert_select 'h3', text: '첨부 서류'
      assert_select 'div.mt-4.space-y-2', count: 1 do
        assert_select 'p.text-sm.font-medium.text-gray-900', text: 'receipt1.pdf'
        assert_select 'p.text-sm.font-medium.text-gray-900', text: 'receipt2.pdf'
        assert_select 'a', text: '다운로드', count: 2
        assert_select 'button', text: '삭제', count: 2
      end
    end
  end
end