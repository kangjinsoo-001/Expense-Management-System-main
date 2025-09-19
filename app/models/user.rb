class User < ApplicationRecord
  has_secure_password
  
  # Associations
  belongs_to :organization, optional: true, counter_cache: true
  has_many :managed_organizations, class_name: 'Organization', foreign_key: 'manager_id'
  has_many :managed_cost_centers, class_name: 'CostCenter', foreign_key: 'manager_id'
  has_many :expense_sheets, dependent: :destroy
  has_many :expense_closing_statuses, dependent: :destroy
  
  # 회의실 예약 관련
  has_many :room_reservations, dependent: :destroy
  
  # 신청서 관련
  has_many :request_forms, dependent: :destroy
  
  # 결재선 관련
  has_many :approval_lines, dependent: :destroy
  has_many :approval_line_steps, foreign_key: 'approver_id', dependent: :restrict_with_error
  has_many :approval_histories, foreign_key: 'approver_id', dependent: :restrict_with_error
  
  # 승인자 그룹 관련
  has_many :created_approver_groups, class_name: 'ApproverGroup', foreign_key: 'created_by_id', dependent: :restrict_with_error
  has_many :approver_group_memberships, class_name: 'ApproverGroupMember', dependent: :destroy
  has_many :approver_groups, through: :approver_group_memberships
  has_many :added_group_members, class_name: 'ApproverGroupMember', foreign_key: 'added_by_id', dependent: :restrict_with_error
  
  # Role definitions
  enum :role, { employee: 0, manager: 1, admin: 2, finance: 3 }
  
  # Validations
  validates :email, presence: true, uniqueness: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :password, length: { minimum: 6 }, if: :password_required?
  validates :name, presence: true
  validates :employee_id, presence: true, uniqueness: true
  validates :role, presence: true
  
  # Callbacks
  before_validation :normalize_email
  
  # 권한 확인 메서드
  def manager_of?(organization)
    return false unless organization
    managed_organizations.include?(organization)
  end
  
  def can_manage_organization?(organization)
    return false unless organization
    
    # admin은 모든 조직 관리 가능
    return true if admin?
    
    # 해당 조직의 조직장인 경우
    return true if manager_of?(organization)
    
    # 상위 조직의 조직장인 경우
    organization.ancestors.any? { |ancestor| manager_of?(ancestor) }
  end
  
  def can_assign_manager?(organization)
    # admin이거나 해당 조직을 관리할 수 있는 권한이 있는 경우
    admin? || can_manage_organization?(organization)
  end
  
  # 사용 가능한 코스트 센터 조회
  def available_cost_centers
    # 조직 제한 없이 모든 활성 코스트 센터 반환
    CostCenter.active
  end
  
  # 활성 사용자인지 확인 (향후 비활성화 기능 추가 시 수정)
  def active?
    true
  end
  
  # 사용자가 속한 승인자 그룹들의 우선순위 중 최고값
  def max_approver_group_priority
    approver_groups.active.maximum(:priority) || 0
  end
  
  # 특정 우선순위 이상의 그룹에 속하는지 확인
  def in_approver_group_with_priority?(min_priority)
    approver_groups.active.where('priority >= ?', min_priority).exists?
  end
  
  # 경비 마감 관련 메서드
  def expense_status_for_month(year, month)
    # ExpenseSheet와 동기화하여 상태 가져오기
    ExpenseClosingStatus.sync_with_expense_sheet(self, year, month)
  end
  
  # 특정 월의 경비 시트 조회
  def expense_sheet_for_month(year, month)
    expense_sheets.where(year: year, month: month).first
  end
  
  private
  
  def password_required?
    new_record? || password.present?
  end
  
  def normalize_email
    self.email = email.to_s.downcase.strip
  end
end
