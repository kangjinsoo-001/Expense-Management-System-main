class ExpenseClosingStatus < ApplicationRecord
  belongs_to :user
  belongs_to :organization
  belongs_to :closed_by, class_name: 'User', optional: true
  belongs_to :expense_sheet, optional: true
  
  # 상태 enum
  enum :status, {
    not_created: 0,      # 경비 시트 미작성
    draft: 1,            # 작성중
    submitted: 2,        # 제출됨
    approval_in_progress: 3,  # 승인중
    approved: 4,         # 승인완료
    closed: 5           # 마감완료
  }, default: :not_created
  
  # 유효성 검증
  validates :year, presence: true, numericality: { greater_than: 2020, less_than_or_equal_to: 2100 }
  validates :month, presence: true, numericality: { greater_than_or_equal_to: 1, less_than_or_equal_to: 12 }
  validates :user_id, uniqueness: { scope: [:year, :month], message: "해당 월의 상태가 이미 존재합니다" }
  
  # 스코프
  scope :for_month, ->(year, month) { where(year: year, month: month) }
  scope :for_organization, ->(org) { where(organization: org) }
  scope :for_organization_tree, ->(org) { joins(:organization).where("organizations.path LIKE ?", "#{org.path}%") }
  scope :pending_close, -> { where(status: :approved) }
  scope :not_submitted, -> { where(status: [:not_created, :draft]) }
  
  # 콜백
  before_validation :set_organization_from_user, on: :create
  
  # 클래스 메서드
  def self.sync_with_expense_sheet(user, year, month)
    # 해당 월의 경비 시트 찾기
    expense_sheet = user.expense_sheets.where(year: year, month: month).first
    
    # 경비 마감 상태 찾거나 생성
    closing_status = find_or_initialize_by(user: user, year: year, month: month)
    
    if expense_sheet.nil?
      # 경비 시트가 없는 경우
      closing_status.status = :not_created
      closing_status.expense_sheet_id = nil
      closing_status.total_amount = 0
      closing_status.item_count = 0
    else
      # 경비 시트가 있는 경우 상태 동기화
      closing_status.expense_sheet_id = expense_sheet.id
      closing_status.status = map_expense_sheet_status(expense_sheet.status)
      closing_status.total_amount = expense_sheet.expense_items.sum(:amount)
      closing_status.item_count = expense_sheet.expense_items.count
      
      # 승인 완료된 경우 마감 정보 업데이트
      if expense_sheet.status == 'approved' && closing_status.closed_at.nil?
        closing_status.closed_at = expense_sheet.approved_at || Time.current
      end
    end
    
    closing_status.organization_id = user.organization_id if closing_status.organization_id.nil?
    closing_status.save!
    closing_status
  end
  
  # 벌크 동기화 메서드 - 여러 사용자의 상태를 한번에 처리
  def self.bulk_sync_with_expense_sheets(users, year, month)
    user_ids = users.map(&:id)
    
    # 모든 경비 시트를 한 번에 조회 (expense_items 포함)
    expense_sheets = ExpenseSheet.includes(:expense_items)
                                 .where(user_id: user_ids, year: year, month: month)
                                 .index_by(&:user_id)
    
    # 모든 경비 마감 상태를 한 번에 조회
    existing_statuses = ExpenseClosingStatus.where(user_id: user_ids, year: year, month: month)
                                            .index_by(&:user_id)
    
    statuses_to_update = []
    statuses_to_create = []
    
    users.each do |user|
      expense_sheet = expense_sheets[user.id]
      closing_status = existing_statuses[user.id]
      
      if closing_status.nil?
        # 새로 생성해야 하는 경우
        closing_status = new(
          user: user, 
          year: year, 
          month: month,
          organization_id: user.organization_id
        )
        
        if expense_sheet.nil?
          closing_status.status = :not_created
          closing_status.expense_sheet_id = nil
          closing_status.total_amount = 0
          closing_status.item_count = 0
        else
          closing_status.expense_sheet_id = expense_sheet.id
          closing_status.status = map_expense_sheet_status(expense_sheet.status)
          closing_status.total_amount = expense_sheet.expense_items.sum(&:amount)
          closing_status.item_count = expense_sheet.expense_items.size
          
          # 자동 마감 처리 제거 - 승인된 경비도 수동으로 마감해야 함
          # if expense_sheet.status == 'approved' && closing_status.closed_at.nil?
          #   closing_status.closed_at = expense_sheet.approved_at || Time.current
          # end
        end
        
        statuses_to_create << closing_status
      else
        # 업데이트해야 하는 경우
        if expense_sheet.nil?
          closing_status.status = :not_created
          closing_status.expense_sheet_id = nil
          closing_status.total_amount = 0
          closing_status.item_count = 0
        else
          closing_status.expense_sheet_id = expense_sheet.id
          closing_status.status = map_expense_sheet_status(expense_sheet.status)
          closing_status.total_amount = expense_sheet.expense_items.sum(&:amount)
          closing_status.item_count = expense_sheet.expense_items.size
          
          # 자동 마감 처리 제거 - 승인된 경비도 수동으로 마감해야 함
          # if expense_sheet.status == 'approved' && closing_status.closed_at.nil?
          #   closing_status.closed_at = expense_sheet.approved_at || Time.current
          # end
        end
        
        statuses_to_update << closing_status if closing_status.changed?
      end
    end
    
    # 벌크 삽입과 업데이트
    import(statuses_to_create) if statuses_to_create.any?
    
    # 벌크 업데이트
    if statuses_to_update.any?
      statuses_to_update.each(&:save!)
    end
    
    # 전체 상태 반환
    all_statuses = statuses_to_create + existing_statuses.values
    all_statuses.sort_by { |s| s.user_id }
  end
  
  # 경비 시트 상태를 마감 상태로 매핑
  def self.map_expense_sheet_status(sheet_status)
    case sheet_status.to_s
    when 'draft' then :draft
    when 'submitted' then :submitted
    when 'approval_in_progress' then :approval_in_progress
    when 'approved' then :approved
    when 'closed' then :closed
    else :draft
    end
  end
  
  # 인스턴스 메서드
  def can_close?
    approved? && closed_at.nil?
  end
  
  def close!(user)
    return false unless can_close?
    
    update!(
      status: :closed,
      closed_at: Time.current,
      closed_by: user
    )
  end
  
  def status_label
    I18n.t("expense_closing_status.statuses.#{status}")
  end
  
  def status_badge_class
    case status
    when 'not_created' then 'bg-gray-100 text-gray-800'
    when 'draft' then 'bg-yellow-100 text-yellow-800'
    when 'submitted' then 'bg-blue-100 text-blue-800'
    when 'approval_in_progress' then 'bg-indigo-100 text-indigo-800'
    when 'approved' then 'bg-green-100 text-green-800'
    when 'closed' then 'bg-purple-100 text-purple-800'
    else 'bg-gray-100 text-gray-800'
    end
  end
  
  private
  
  def set_organization_from_user
    self.organization_id ||= user&.organization_id
  end
end
