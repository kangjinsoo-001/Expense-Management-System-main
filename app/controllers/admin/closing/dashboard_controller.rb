class Admin::Closing::DashboardController < Admin::BaseController
  include OrganizationTreeLoadable
  
  before_action :authenticate_user!
  before_action :authorize_access!
  before_action :set_date_params
  before_action :set_organization, only: [:organization_members, :batch_close, :export]
  
  def index
    # 사용자가 관리할 수 있는 조직 목록 가져오기
    @managed_organizations = current_user_managed_organizations
    
    # 선택된 조직 설정
    if params[:organization_id].present?
      # 전체 조직에서 찾되, 권한이 있는지 확인
      @selected_organization = Organization.includes(:children)
                                          .find_by(id: params[:organization_id])
      # 권한 확인 (관리자이거나 해당 조직의 관리 권한이 있는 경우)
      unless @selected_organization && can_manage_organization_expense?(@selected_organization)
        @selected_organization = nil
      end
    end
    @selected_organization ||= @managed_organizations.first
    
    # 선택된 조직의 요약 정보 가져오기
    if @selected_organization
      # include_descendants 기본값을 true로 설정 (명시적으로 false가 아닌 경우)
      @summary = @selected_organization.expense_closing_summary(@year, @month, include_descendants: params[:include_descendants] != 'false')
    end
  end

  def organization_members
    # 조직 구성원의 경비 상태 목록  
    # include_descendants 기본값을 true로 설정 (명시적으로 false가 아닌 경우)
    @include_descendants = params[:include_descendants] != 'false'
    @statuses = @organization.member_expense_statuses(@year, @month, include_descendants: @include_descendants)
    
    # 상태별 필터링
    if params[:status_filter].present?
      @statuses = @statuses.select { |s| s.status == params[:status_filter] }
    end
    
    # 검색 필터
    if params[:search].present?
      search_term = params[:search].downcase
      @statuses = @statuses.select do |status|
        status.user.name.downcase.include?(search_term) ||
        status.user.employee_id.downcase.include?(search_term)
      end
    end
    
    # 정렬
    sort_by = params[:sort_by] || 'name'
    sort_direction = params[:sort_direction] || 'asc'
    
    @statuses = case sort_by
    when 'name'
      @statuses.sort_by { |s| s.user.name }
    when 'employee_id'
      @statuses.sort_by { |s| s.user.employee_id }
    when 'status'
      @statuses.sort_by { |s| [s.status, s.user.name] }
    when 'amount'
      @statuses.sort_by { |s| s.total_amount || 0 }
    else
      @statuses
    end
    
    @statuses.reverse! if sort_direction == 'desc'
    
    # Turbo Frame 응답
    respond_to do |format|
      format.html { render partial: 'member_status_table', locals: { statuses: @statuses } }
      format.turbo_stream
    end
  end

  def batch_close
    # 선택된 경비 상태들을 일괄 마감 처리
    status_ids = params[:status_ids] || []
    @closed_count = 0
    @errors = []
    
    ExpenseClosingStatus.transaction do
      status_ids.each do |status_id|
        status = ExpenseClosingStatus.find_by(id: status_id)
        next unless status
        
        # 권한 확인
        unless can_manage_organization_expense?(status.organization)
          @errors << "#{status.user.name}의 경비를 마감할 권한이 없습니다."
          next
        end
        
        # 마감 가능 여부 확인
        unless status.can_close?
          @errors << "#{status.user.name}의 경비는 마감할 수 없는 상태입니다."
          next
        end
        
        # 마감 처리
        if status.close!(current_user)
          @closed_count += 1
          
          # 경비 시트도 closed 상태로 변경
          if status.expense_sheet
            status.expense_sheet.update(status: 'closed')
          end
        else
          @errors << "#{status.user.name}의 경비 마감 처리 실패"
        end
      end
    end
    
    # turbo_stream 응답을 위해 데이터 다시 로드
    include_descendants = params[:include_descendants] != 'false'
    @statuses = @organization.member_expense_statuses(@year, @month, include_descendants: include_descendants)
    
    # 요약 정보 다시 계산 (대시보드 숫자 업데이트용)
    # 데이터베이스에서 직접 최신 상태를 조회하는 _fresh 메서드 사용 (Rails Way)
    @selected_organization = @organization
    @summary = @selected_organization.expense_closing_summary_fresh(@year, @month, include_descendants: include_descendants)
    
    # 디버깅 로그
    Rails.logger.info "=== Batch Close Debug ==="
    Rails.logger.info "Organization: #{@selected_organization.name} (ID: #{@selected_organization.id})"
    Rails.logger.info "Summary: #{@summary.inspect}"
    Rails.logger.info "Closed count: #{@summary[:closed]}"
    Rails.logger.info "Approved count: #{@summary[:approved]}"
    
    # 필터 적용 (있는 경우)
    if params[:status_filter].present?
      @statuses = @statuses.select { |s| s.status == params[:status_filter] }
    end
    
    if params[:search].present?
      search_term = params[:search].downcase
      @statuses = @statuses.select do |status|
        status.user.name.downcase.include?(search_term) ||
        status.user.employee_id.downcase.include?(search_term)
      end
    end
    
    respond_to do |format|
      format.html { redirect_to admin_closing_dashboard_index_path, notice: "#{@closed_count}건의 경비가 마감되었습니다." }
      format.turbo_stream # batch_close.turbo_stream.erb 렌더링
    end
  end


  def export
    # 엑셀 내보내기
    # include_descendants 기본값을 true로 설정
    @include_descendants = params[:include_descendants] != 'false'
    @statuses = @organization.member_expense_statuses(@year, @month, include_descendants: @include_descendants)
    
    respond_to do |format|
      format.xlsx {
        response.headers['Content-Disposition'] = "attachment; filename=\"경비마감현황_#{@organization.name}_#{@year}년#{@month}월.xlsx\""
      }
    end
  end
  
  private
  
  def authenticate_user!
    redirect_to login_path unless current_user
  end
  
  def authorize_access!
    # 관리자 또는 조직 관리자만 접근 가능
    unless current_user.admin? || current_user.managed_organizations.any?
      redirect_to root_path, alert: '접근 권한이 없습니다.'
    end
  end
  
  def set_date_params
    @year = params[:year]&.to_i || Date.current.year
    @month = params[:month]&.to_i || Date.current.month
    
    # 날짜 계산
    @current_date = Date.new(@year, @month, 1)
    @prev_date = @current_date - 1.month
    @next_date = @current_date + 1.month
  end
  
  def set_organization
    @organization = Organization.find_by(id: params[:organization_id])
    
    # 권한 확인
    unless @organization && can_manage_organization_expense?(@organization)
      redirect_to admin_closing_dashboard_index_path, alert: '해당 조직에 대한 권한이 없습니다.'
    end
  end
  
  def current_user_managed_organizations
    # 조직 트리의 최대 깊이를 계산하여 동적으로 includes 구성
    # 성능을 위해 최대 10단계로 제한
    max_depth = [calculate_max_depth, 10].min
    includes_hash = build_recursive_includes(max_depth, include_manager: false)
    
    if current_user.admin?
      # 관리자는 최상위 조직만 반환 (하위는 트리 구조로 렌더링됨)
      Organization.includes(includes_hash)
                  .where(parent_id: nil)
                  .order(:path)
    else
      # 조직 관리자는 자신이 관리하는 조직의 최상위만 반환
      # 자신이 관리하는 조직 중 최상위 조직들만 찾기
      managed_orgs = current_user.managed_organizations
      
      # 관리 조직 중 다른 관리 조직의 하위가 아닌 것들만 선택
      root_managed_orgs = managed_orgs.select do |org|
        # 상위 조직들 중 관리 조직이 없으면 최상위로 간주
        !org.ancestors.any? { |ancestor| managed_orgs.include?(ancestor) }
      end
      
      Organization.includes(includes_hash)
                  .where(id: root_managed_orgs.map(&:id))
                  .order(:path)
    end
  end
  
  def can_manage_organization_expense?(organization)
    current_user.admin? || current_user.can_manage_organization?(organization)
  end
end
