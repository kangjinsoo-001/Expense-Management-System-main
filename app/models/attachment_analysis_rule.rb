class AttachmentAnalysisRule < ApplicationRecord
  # 관계 설정
  belongs_to :attachment_requirement

  # 검증 규칙
  validates :prompt_text, presence: true
  validates :attachment_requirement, presence: true

  # 스코프
  scope :active, -> { where(active: true) }

  # JSON 필드 처리
  serialize :expected_fields, coder: JSON, type: Hash

  # 커스텀 setter - String으로 전달된 JSON을 Hash로 변환
  def expected_fields=(value)
    if value.is_a?(String)
      begin
        # JSON 문자열을 파싱하여 Hash로 변환
        parsed_value = value.present? ? JSON.parse(value) : {}
        super(parsed_value)
      rescue JSON::ParserError => e
        Rails.logger.error "Failed to parse expected_fields JSON: #{e.message}"
        super({})
      end
    else
      super(value)
    end
  end

  # 프롬프트 생성
  def generate_prompt(context = {})
    prompt = prompt_text.dup
    
    # 컨텍스트 변수 치환
    context.each do |key, value|
      prompt.gsub!("{{#{key}}}", value.to_s)
    end
    
    prompt
  end

  # 예상 필드 목록 반환
  def field_names
    return [] if expected_fields.blank?
    
    expected_fields.keys
  end

  # 필드 타입 정보 반환
  def field_type(field_name)
    return nil if expected_fields.blank?
    
    expected_fields[field_name.to_s]
  end

  # AI 분석 결과 검증
  def validate_analysis_result(result)
    return true if expected_fields.blank?
    
    # 모든 예상 필드가 결과에 포함되어 있는지 확인
    field_names.all? { |field| result.key?(field) }
  end

  # 분석 규칙 복사
  def duplicate
    dup.tap do |new_rule|
      new_rule.expected_fields = expected_fields.deep_dup if expected_fields.present?
    end
  end
end
