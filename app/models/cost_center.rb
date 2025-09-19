class CostCenter < ApplicationRecord
  belongs_to :organization
  belongs_to :manager, class_name: 'User', optional: true
  has_many :expense_sheets
  has_many :expense_items
  
  validates :code, presence: true, uniqueness: { scope: :organization_id }
  validates :name, presence: true
  validates :fiscal_year, presence: true, numericality: { greater_than: 2000 }
  validates :budget_amount, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true
  
  scope :active, -> { where(active: true) }
  scope :for_year, ->(year) { where(fiscal_year: year) }
  scope :for_organization, ->(org) { where(organization: org) }
  scope :with_budget, -> { where.not(budget_amount: nil) }
  
  before_validation :set_default_fiscal_year
  
  def budget_utilization
    return 0 unless budget_amount&.positive?
    
    # 아직 expense_sheets 모델이 없으므로 0을 반환
    # TODO: expense_sheets 모델 구현 후 아래 코드로 변경
    # used_amount = expense_sheets.approved.sum(:total_amount)
    # (used_amount / budget_amount * 100).round(2)
    0
  end
  
  def budget_remaining
    return nil unless budget_amount
    
    # TODO: expense_sheets 모델 구현 후 실제 계산
    # budget_amount - expense_sheets.approved.sum(:total_amount)
    budget_amount
  end
  
  def budget_available?
    budget_remaining&.positive?
  end
  
  def to_s
    "#{code} - #{name}"
  end

  def name_with_code
    "#{code} - #{name}"
  end
  
  private
  
  def set_default_fiscal_year
    self.fiscal_year ||= Date.current.year
  end
end
