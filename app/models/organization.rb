class Organization < ApplicationRecord
  # 트리 구조를 위한 자기 참조 관계
  belongs_to :parent, class_name: 'Organization', optional: true
  has_many :children, class_name: 'Organization', foreign_key: 'parent_id', dependent: :destroy
  
  # 조직장(관리자)
  belongs_to :manager, class_name: 'User', optional: true
  
  # 조직 소속 사용자들
  has_many :users, counter_cache: true
  
  # 경비 관련
  has_many :expense_codes
  has_many :cost_centers
  has_many :expense_closing_statuses
  
  # 검증
  validates :name, presence: true
  validates :code, presence: true, uniqueness: true
  validate :parent_not_self
  validate :no_circular_reference
  validate :valid_path_format
  
  # 콜백
  after_create :set_initial_path
  after_update :update_path_if_needed
  after_save :clear_depth_cache
  # update_descendants_path는 parent_id 변경 시에만 필요하고, 
  # 새로 생성할 때는 실행하지 않음 (자식이 없으므로)
  after_update :update_descendants_path, if: :saved_change_to_parent_id?
  after_destroy :clear_depth_cache
  
  # 소프트 삭제
  default_scope { where(deleted_at: nil) }
  scope :deleted, -> { unscoped.where.not(deleted_at: nil) }
  
  # 계층 구조 관련 메서드
  def ancestors
    node, nodes = self, []
    nodes << node = node.parent while node.parent
    nodes.reverse
  end
  
  def ancestor_ids
    ancestors.map(&:id)
  end
  
  def descendants
    @descendants ||= begin
      if path.present?
        # path 기반으로 모든 하위 조직을 한 번에 가져옴
        Organization.unscoped
                   .where(deleted_at: nil)
                   .where("organizations.path LIKE ?", "#{path}.%")
                   .order(:path)
      elsif children.loaded?
        # path가 없는 경우 재귀적으로 사용 (마이그레이션 전 데이터 대응)
        children.flat_map { |child| [child] + child.descendants }
      else
        # path도 없고 children도 로드되지 않은 경우
        Organization.unscoped
                   .where(deleted_at: nil)
                   .where(id: descendant_ids_by_recursion)
      end
    end
  end
  
  def descendant_ids
    @descendant_ids ||= descendants.pluck(:id)
  end
  
  # 재귀적으로 하위 조직 ID 가져오기 (path가 없는 경우 fallback)
  def descendant_ids_by_recursion
    all_ids = []
    to_check = children.pluck(:id)
    
    while to_check.any?
      all_ids.concat(to_check)
      to_check = Organization.where(parent_id: to_check).pluck(:id)
    end
    
    all_ids
  end
  
  def depth
    ancestors.count
  end
  
  def root?
    parent.nil?
  end
  
  def leaf?
    children.empty?
  end
  
  def siblings
    parent ? parent.children.where.not(id: id) : Organization.where(parent_id: nil).where.not(id: id)
  end
  
  # 전체 경로 (루트부터 현재 조직까지)
  def full_path
    (ancestors + [self]).map(&:name).join(' > ')
  end
  
  # 사용자 관리
  def add_user(user)
    users << user unless users.include?(user)
  end
  
  def remove_user(user)
    users.delete(user)
  end
  
  # 하위 조직 포함 모든 사용자
  def all_users
    # Eager loading을 위해 includes 사용
    # descendants가 이미 children을 포함하므로 추가 includes 불필요
    if path.present?
      # path 기반 조회는 이미 최적화됨
      User.joins(:organization)
          .where("organizations.path LIKE ?", "#{path}%")
          .distinct
    else
      # path가 없는 경우 재귀적 조회
      descendant_orgs = descendants.includes(:users)
      all_user_ids = user_ids + descendant_orgs.flat_map(&:user_ids)
      User.where(id: all_user_ids.uniq)
    end
  end
  
  # 조직장 관리
  def assign_manager(user)
    return false unless user
    
    # 이전 조직장의 role을 employee로 변경 (admin이 아닌 경우)
    if manager && !manager.admin?
      manager.update(role: :employee)
    end
    
    # 새 조직장 지정 및 role을 manager로 변경
    self.manager = user
    user.update(role: :manager) unless user.admin?
    save
  end
  
  def remove_manager
    if manager && !manager.admin?
      manager.update(role: :employee)
    end
    self.manager = nil
    save
  end
  
  # 조직장 후보자 목록 (해당 조직 소속 사용자)
  def manager_candidates
    users.order(:name)
  end
  
  # 경비 마감 관련 메서드
  def member_expense_statuses(year, month, include_descendants: false)
    # 조직 멤버 가져오기
    members = include_descendants ? all_users : users
    
    # 벌크 처리로 모든 멤버의 경비 상태 한번에 처리
    ExpenseClosingStatus.bulk_sync_with_expense_sheets(members, year, month)
  end
  
  # 특정 월의 경비 마감 통계
  def expense_closing_summary(year, month, include_descendants: false)
    statuses = member_expense_statuses(year, month, include_descendants: include_descendants)
    
    {
      total_members: statuses.count,
      not_created: statuses.count { |s| s.not_created? },
      draft: statuses.count { |s| s.draft? },
      submitted: statuses.count { |s| s.submitted? },
      approval_in_progress: statuses.count { |s| s.approval_in_progress? },
      approved: statuses.count { |s| s.approved? },
      closed: statuses.count { |s| s.closed? },
      submission_rate: statuses.count > 0 ? 
        ((statuses.count - statuses.count { |s| s.not_created? || s.draft? }).to_f / statuses.count * 100).round(1) : 0,
      approval_rate: statuses.count { |s| s.submitted? || s.approval_in_progress? } > 0 ?
        (statuses.count { |s| s.approved? || s.closed? }.to_f / statuses.count { |s| !s.not_created? && !s.draft? } * 100).round(1) : 0
    }
  end
  
  # 특정 월의 경비 마감 통계 (데이터베이스에서 직접 조회)
  # Turbo Stream 업데이트 후 최신 상태를 반영하기 위해 사용
  def expense_closing_summary_fresh(year, month, include_descendants: false)
    # 데이터베이스에서 직접 최신 상태 조회
    query = ExpenseClosingStatus.where(year: year, month: month)
    
    if include_descendants
      # 하위 조직 포함
      query = query.joins(:organization)
                   .where("organizations.path LIKE ?", "#{path}%")
    else
      # 현재 조직만
      query = query.where(organization_id: id)
    end
    
    # 데이터베이스 레벨에서 통계 계산
    total = query.count
    not_created_count = query.where(status: 'not_created').count
    draft_count = query.where(status: 'draft').count
    submitted_count = query.where(status: 'submitted').count
    approval_in_progress_count = query.where(status: 'approval_in_progress').count
    approved_count = query.where(status: 'approved').count
    closed_count = query.where(status: 'closed').count
    
    # 제출률과 승인률 계산
    submission_rate = if total > 0
      ((total - not_created_count - draft_count).to_f / total * 100).round(1)
    else
      0
    end
    
    submitted_total = submitted_count + approval_in_progress_count + approved_count + closed_count
    approval_rate = if submitted_total > 0
      ((approved_count + closed_count).to_f / submitted_total * 100).round(1)
    else
      0
    end
    
    {
      total_members: total,
      not_created: not_created_count,
      draft: draft_count,
      submitted: submitted_count,
      approval_in_progress: approval_in_progress_count,
      approved: approved_count,
      closed: closed_count,
      submission_rate: submission_rate,
      approval_rate: approval_rate
    }
  end
  
  # 소프트 삭제
  def soft_delete
    update(deleted_at: Time.current)
    children.each(&:soft_delete)
  end
  
  def restore
    update(deleted_at: nil)
  end
  
  private
  
  # 생성 직후 path 설정 (ID가 할당된 후)
  def set_initial_path
    if parent_id.nil?
      # 루트 조직
      update_column(:path, id.to_s)
    elsif parent && parent.path.present?
      # 하위 조직
      update_column(:path, "#{parent.path}.#{id}")
    else
      # parent path가 없는 경우 재구성
      path_value = build_path_from_ancestors
      update_column(:path, path_value)
    end
  end
  
  # 업데이트 시 path 재설정 (parent_id 변경 시)
  def update_path_if_needed
    if saved_change_to_parent_id?
      if parent_id.nil?
        update_column(:path, id.to_s)
      elsif parent && parent.path.present?
        update_column(:path, "#{parent.path}.#{id}")
      else
        path_value = build_path_from_ancestors
        update_column(:path, path_value)
      end
    end
  end
  
  def build_path_from_ancestors
    # 조상들의 ID를 이용해 path 재구성
    ancestor_ids = ancestors.map(&:id)
    ancestor_ids << id
    ancestor_ids.join('.')
  end
  
  def update_descendants_path
    return unless path.present?
    
    # 모든 하위 조직의 path 업데이트
    old_path = path_before_last_save || path.split('.')[0...-1].join('.')
    
    if old_path != path
      Organization.unscoped
                  .where("organizations.path LIKE ?", "#{old_path}.%")
                  .find_each do |org|
        new_org_path = org.path.sub(/^#{Regexp.escape(old_path)}/, path)
        org.update_columns(path: new_org_path)
      end
    end
  end
  
  def parent_not_self
    errors.add(:parent, '자기 자신을 상위 조직으로 설정할 수 없습니다') if parent == self
  end
  
  def no_circular_reference
    return unless parent
    
    if ancestors.include?(self)
      errors.add(:parent, '순환 참조가 발생합니다')
    end
  end
  
  # 조직 구조 변경 시 캐시 삭제
  def clear_depth_cache
    Rails.cache.delete('organization_max_depth')
  end
  
  # path 형식 검증
  def valid_path_format
    return unless path.present?
    
    # 연속된 점(.. 또는 ...)이 있는지 확인
    if path.include?('...')
      errors.add(:path, 'path에 연속된 점(...)이 포함될 수 없습니다')
    elsif path.include?('..')
      errors.add(:path, 'path에 연속된 점(..)이 포함될 수 없습니다')
    end
    
    # path가 숫자와 점으로만 구성되었는지 확인
    unless path.match?(/\A\d+(\.\d+)*\z/)
      errors.add(:path, 'path는 숫자와 점(.)으로만 구성되어야 합니다')
    end
  end
end
