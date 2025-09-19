class ReportExport < ApplicationRecord
  belongs_to :report_template, optional: true
  belongs_to :user
  
  # 첨부 파일 (Active Storage)
  has_one_attached :export_file

  # 상태 관리
  enum :status, {
    pending: 'pending',
    processing: 'processing',
    completed: 'completed',
    failed: 'failed'
  }, default: 'pending'

  # 검증
  validates :status, presence: true

  # 스코프
  scope :recent, -> { order(created_at: :desc) }
  scope :by_user, ->(user) { where(user: user) }

  # 콜백
  before_create :set_defaults

  # 메서드
  def duration
    return nil unless started_at && completed_at
    completed_at - started_at
  end

  def duration_in_seconds
    duration&.to_i
  end

  def filename
    return nil unless export_file.attached?
    export_file.filename.to_s
  end

  def download_url
    return nil unless export_file.attached?
    Rails.application.routes.url_helpers.rails_blob_url(export_file, only_path: true)
  end

  private

  def set_defaults
    self.status ||= 'pending'
  end
end
