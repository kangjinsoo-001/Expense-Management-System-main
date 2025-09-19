class ExpenseAttachment < ApplicationRecord
  belongs_to :expense_item, optional: true, counter_cache: true
  has_one_attached :file
  
  # 상태 정의
  STATUSES = {
    pending: '대기중',
    uploading: '업로드중',
    processing: '분석중',
    completed: '완료',
    failed: '실패'
  }.freeze
  
  # AI 처리 단계 정의
  AI_PROCESSING_STAGES = {
    pending: 'pending',
    extracting: 'extracting',
    extracted: 'extracted',
    summarizing: 'summarizing',
    summarized: 'summarized'
  }.freeze
  
  # 영수증 유형 정의
  RECEIPT_TYPES = {
    telecom: 'telecom',
    general: 'general',
    unknown: 'unknown'
  }.freeze
  
  validates :status, inclusion: { in: STATUSES.keys.map(&:to_s) }
  validates :processing_stage, inclusion: { in: AI_PROCESSING_STAGES.values }, allow_nil: true
  validates :receipt_type, inclusion: { in: RECEIPT_TYPES.values }, allow_nil: true
  
  # 파일 타입 검증
  validate :acceptable_file
  
  # 상태별 스코프
  scope :completed, -> { where(status: 'completed') }
  scope :processing, -> { where(status: ['uploading', 'processing']) }
  scope :pending_ai_processing, -> { where(ai_processed: false, processing_stage: 'extracted') }
  scope :by_receipt_type, ->(type) { where(receipt_type: type) }
  
  # 콜백
  after_create_commit :process_file_async
  after_update_commit :enqueue_ai_summary, if: :ready_for_ai_summary?
  
  # AI 처리 관련 메서드
  def ready_for_ai_summary?
    processing_stage == 'extracted' && !ai_processed && extracted_text.present?
  end
  
  def extracted?
    processing_stage == 'extracted' || processing_stage == 'summarizing' || processing_stage == 'summarized'
  end
  
  def mark_ai_processed!(summary_data, receipt_type)
    update!(
      ai_processed: true,
      ai_processed_at: Time.current,
      summary_data: summary_data.to_json,
      receipt_type: receipt_type,
      processing_stage: AI_PROCESSING_STAGES[:summarized],
      status: 'completed'
    )
  end
  
  def parsed_summary
    return nil unless summary_data.present?
    JSON.parse(summary_data).with_indifferent_access
  rescue JSON::ParserError
    { summary_text: summary_data }
  end
  
  def update_processing_stage!(stage)
    update!(processing_stage: AI_PROCESSING_STAGES[stage])
  end
  
  private
  
  def acceptable_file
    return unless file.attached?
    
    acceptable_types = ['application/pdf', 'image/jpeg', 'image/png', 'image/jpg']
    unless acceptable_types.include?(file.content_type)
      errors.add(:file, 'PDF, JPG, PNG 파일만 업로드 가능합니다.')
    end
    
    if file.byte_size > 10.megabytes
      errors.add(:file, '파일 크기는 10MB 이하여야 합니다.')
    end
  end
  
  def process_file_async
    # TextExtractionJob을 큐에 추가
    TextExtractionJob.perform_later(self.id)
  end
  
  def enqueue_ai_summary
    # AttachmentSummaryJob을 큐에 추가  
    AttachmentSummaryJob.perform_later(self.id)
  end
end