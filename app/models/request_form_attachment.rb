class RequestFormAttachment < ApplicationRecord
  # Active Storage
  has_one_attached :file
  
  # 관계 설정  
  belongs_to :request_form
  belongs_to :uploaded_by, class_name: 'User'
  
  # 검증 규칙
  validates :field_key, presence: true
  validates :file, presence: true
  
  # 콜백
  before_validation :set_file_metadata
  
  # 스코프
  scope :for_field, ->(field_key) { where(field_key: field_key) }
  scope :recent, -> { order(created_at: :desc) }
  
  # 파일 크기 (MB)
  def file_size_mb
    return 0 unless file_size
    (file_size / 1024.0 / 1024.0).round(2)
  end
  
  # 파일 확장자
  def file_extension
    return nil unless file_name
    File.extname(file_name).downcase
  end
  
  # 이미지 파일인지 확인
  def image?
    %w[.jpg .jpeg .png .gif .bmp].include?(file_extension)
  end
  
  # PDF 파일인지 확인
  def pdf?
    file_extension == '.pdf'
  end
  
  # 아이콘 클래스 반환
  def file_icon_class
    case file_extension
    when '.pdf'
      'bi-file-earmark-pdf'
    when '.doc', '.docx'
      'bi-file-earmark-word'
    when '.xls', '.xlsx'
      'bi-file-earmark-excel'
    when '.ppt', '.pptx'
      'bi-file-earmark-ppt'
    when '.jpg', '.jpeg', '.png', '.gif'
      'bi-file-earmark-image'
    when '.zip', '.rar', '.7z'
      'bi-file-earmark-zip'
    else
      'bi-file-earmark'
    end
  end
  
  private
  
  def set_file_metadata
    return unless file.attached?
    
    self.file_name = file.filename.to_s
    self.file_size = file.byte_size
    self.content_type = file.content_type
  end
end