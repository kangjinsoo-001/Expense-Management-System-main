class PdfAnalysisResult < ApplicationRecord
  belongs_to :expense_sheet
  has_many :transaction_matches, dependent: :destroy
  
  validates :attachment_id, presence: true, uniqueness: true
  
  # Active Storage attachment 찾기
  def attachment
    ActiveStorage::Attachment.find_by(id: attachment_id)
  end
  
  # 파일명 가져오기
  def filename
    attachment&.blob&.filename&.to_s || "Unknown"
  end
  
  # 추출된 텍스트가 있는지 확인
  def has_extracted_text?
    extracted_text.present?
  end
  
  # 분석이 완료되었는지 확인
  def analyzed?
    analysis_data.present?
  end
  
  # 거래 내역이 파싱되었는지 확인
  def has_transactions?
    analysis_data&.dig('transactions').present?
  end
end
