class ExpenseSheetAttachment < ApplicationRecord
  # 상수 정의
  STATUSES = %w[pending uploading processing completed failed].freeze
  
  STATUS_LABELS = {
    'pending' => '대기중',
    'uploading' => '업로드중',
    'processing' => '분석중',
    'completed' => '완료',
    'failed' => '실패'
  }.freeze
  
  # AI 처리 단계 정의
  AI_PROCESSING_STAGES = {
    pending: 'pending',
    extracting: 'extracting',
    extracted: 'extracted',
    summarizing: 'summarizing',
    summarized: 'summarized'
  }.freeze

  # 관계 설정
  belongs_to :expense_sheet
  belongs_to :attachment_requirement, optional: true # 자유 첨부 허용
  
  # ActiveStorage
  has_one_attached :file

  # 검증 규칙
  validates :expense_sheet, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }
  validate :file_attached_validation

  # 스코프
  scope :pending, -> { where(status: 'pending') }
  scope :processing, -> { where(status: 'processing') }
  scope :completed, -> { where(status: 'completed') }
  scope :failed, -> { where(status: 'failed') }
  scope :with_requirement, -> { where.not(attachment_requirement_id: nil) }
  scope :without_requirement, -> { where(attachment_requirement_id: nil) }

  # JSON 필드 처리
  serialize :analysis_result, coder: JSON, type: Hash
  serialize :validation_result, coder: JSON, type: Hash

  # 콜백
  after_create_commit :process_file_async
  after_update_commit :enqueue_ai_summary, if: :ready_for_ai_summary?

  # 상태 전환 메서드
  def mark_as_processing!
    update!(status: 'processing')
  end

  def mark_as_analyzing!
    update!(status: 'processing')
  end

  def mark_as_completed!
    update!(status: 'completed')
  end

  def mark_as_failed!(error_message = nil)
    result = validation_result || {}
    result['error'] = error_message if error_message
    update!(status: 'failed', validation_result: result)
  end

  # 상태 확인 메서드
  def pending?
    status == 'pending'
  end

  def processing?
    status == 'processing'
  end

  def analyzing?
    status == 'processing'
  end

  def completed?
    status == 'completed'
  end

  def failed?
    status == 'failed'
  end

  # 파일 정보
  def file_name
    file.filename.to_s if file.attached?
  end

  def file_type
    return nil unless file.attached?
    
    file.filename.extension_without_delimiter.downcase
  end

  def file_size
    file.byte_size if file.attached?
  end

  # 상태 라벨
  def status_label
    STATUS_LABELS[status] || status
  end

  # 검증 결과 요약
  def validation_summary
    return nil unless validation_result.present?
    
    {
      passed: validation_result['passed'] || false,
      severity: validation_result['severity'],
      messages: validation_result['messages'] || []
    }
  end

  # 분석 결과 필드 값 가져오기
  def analysis_field(field_name)
    return nil unless analysis_result.present?
    
    analysis_result[field_name.to_s]
  end
  
  # 추출된 텍스트 반환
  def extracted_text
    analysis_result&.dig('extracted_text')
  end
  
  # AI 처리 관련 메서드
  def ready_for_ai_summary?
    processing_stage == 'extracted' && extracted_text.present? && !analysis_result&.dig('ai_processed')
  end
  
  def extracted?
    processing_stage == 'extracted' || processing_stage == 'summarizing' || processing_stage == 'summarized'
  end
  
  def mark_ai_processed!(summary_data)
    # summary_data가 문자열이면 JSON 파싱 시도
    parsed_data = if summary_data.is_a?(String)
      begin
        JSON.parse(summary_data)
      rescue JSON::ParserError
        { 'summary_text' => summary_data }
      end
    else
      summary_data
    end
    
    # summary_text 필드가 JSON 문자열이면 파싱
    if parsed_data.is_a?(Hash) && parsed_data['summary_text'].is_a?(String)
      begin
        nested_json = JSON.parse(parsed_data['summary_text'])
        parsed_data = nested_json if nested_json.is_a?(Hash)
      rescue JSON::ParserError
        # 파싱 실패시 그대로 유지
      end
    end
    
    # 디버그 로깅 추가
    Rails.logger.info "mark_ai_processed! - 저장할 데이터: #{parsed_data.inspect[0..500]}"
    
    update!(
      analysis_result: (analysis_result || {}).merge(
        'ai_processed' => true,
        'ai_processed_at' => Time.current,
        'summary_data' => parsed_data,
        'extracted_text' => extracted_text # 기존 텍스트 유지
      ),
      processing_stage: 'summarized',
      status: 'completed'
    )
  end

  private

  def file_attached_validation
    errors.add(:file, '파일이 첨부되지 않았습니다') unless file.attached?
  end

  def process_file_async
    # TextExtractionJob을 큐에 추가 (상태는 Job에서 관리)
    SheetTextExtractionJob.perform_later(self.id, 'ExpenseSheetAttachment')
  end
  
  def enqueue_ai_summary
    # 경비 항목과 동일한 AI 요약 작업을 큐에 추가
    AttachmentSummaryJob.perform_later(self.id, 'ExpenseSheetAttachment')
  end
end
