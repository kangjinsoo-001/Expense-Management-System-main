class ReportTemplate < ApplicationRecord
  belongs_to :user
  has_many :report_exports, dependent: :destroy

  # 직렬화 속성
  serialize :filter_config, coder: JSON
  serialize :columns_config, coder: JSON

  # 검증
  validates :name, presence: true
  validates :export_format, inclusion: { in: %w[excel pdf csv] }

  # 스코프
  scope :by_user, ->(user) { where(user: user) }
  scope :global, -> { where(is_global: true) }

  # 메서드
  def filters
    filter_config.presence || {}
  end

  def columns
    columns_config.presence || default_columns
  end

  private

  def default_columns
    %w[
      date
      user_name
      organization_name
      expense_code
      amount
      description
      status
      approved_at
    ]
  end
end
