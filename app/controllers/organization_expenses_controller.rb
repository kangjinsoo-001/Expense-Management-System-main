class OrganizationExpensesController < ApplicationController
  before_action :require_login
  before_action :require_organization_manager
  before_action :set_date_params
  
  def index
    # 내가 관리하는 조직들을 효율적으로 로드 (상위 조직이 이미 포함된 경우 하위 조직 제외)
    all_managed = current_user.managed_organizations.includes(:parent)
    
    # 상위 조직이 이미 관리 목록에 있으면 하위 조직은 제외
    @managed_organizations = all_managed.reject do |org|
      all_managed.any? { |other| other != org && org.ancestors.include?(other) }
    end
    
    # 권한이 없으면 빈 페이지 표시
    if @managed_organizations.empty?
      @organization_expenses = {}
      @total_amount = 0
      @total_by_code = {}
      @total_organization_count = 0
      @prev_date = Date.current.prev_month
      @next_date = Date.current.next_month
      return
    end
    
    # 모든 관련 조직을 한 번에 로드 (path 기반)
    all_related_orgs = if @managed_organizations.any? { |org| org.path.present? }
      # path가 있는 경우 효율적인 쿼리
      path_conditions = @managed_organizations.map { |org| 
        org.path.present? ? "organizations.path LIKE '#{org.path}.%' OR organizations.path = '#{org.path}'" : "organizations.id = #{org.id}"
      }.join(' OR ')
      
      Organization.where(path_conditions).includes(:children)
    else
      # path가 없는 경우 기존 방식 (fallback)
      all_org_ids = @managed_organizations.flat_map { |org| [org.id] + org.descendant_ids }.uniq
      Organization.where(id: all_org_ids).includes(:children)
    end
    
    # 조직 트리 구조 메모리에 구성
    org_lookup = all_related_orgs.index_by(&:id)
    
    # 모든 사용자 ID를 한 번에 조회
    all_user_ids_by_org = User.where(organization_id: all_related_orgs.pluck(:id))
                              .group(:organization_id)
                              .pluck(:organization_id, :id)
                              .group_by(&:first)
                              .transform_values { |v| v.map(&:last) }
    
    # 한 번에 모든 경비 데이터 조회 (조직별로 그룹화)
    all_org_ids = all_related_orgs.pluck(:id)
    all_user_ids = all_user_ids_by_org.values.flatten
    
    # 조직별 경비 합계를 한 번에 조회
    expense_sheets_query = ExpenseSheet.joins(:user)
                                       .where(users: { id: all_user_ids })
    if @view_mode == 'yearly'
      expense_sheets_query = expense_sheets_query.where(year: @year)
    else
      expense_sheets_query = expense_sheets_query.where(year: @year, month: @month)
    end
    expense_totals_by_org = expense_sheets_query.group('users.organization_id').sum(:total_amount)
    
    # 경비 코드별 합계를 한 번에 조회
    expense_items_query = ExpenseItem.joins(:expense_sheet, :expense_code, expense_sheet: :user)
                                        .where(users: { id: all_user_ids })
    if @view_mode == 'yearly'
      expense_items_query = expense_items_query.where(expense_sheets: { year: @year })
    else
      expense_items_query = expense_items_query.where(expense_sheets: { year: @year, month: @month })
    end
    expense_by_code_and_org = expense_items_query.group('users.organization_id', 'expense_codes.code', 'expense_codes.name').sum(:amount)
    
    # 조직별 항목 수를 한 번에 조회
    item_counts_query = ExpenseItem.joins(:expense_sheet, expense_sheet: :user)
                                   .where(users: { id: all_user_ids })
    if @view_mode == 'yearly'
      item_counts_query = item_counts_query.where(expense_sheets: { year: @year })
    else
      item_counts_query = item_counts_query.where(expense_sheets: { year: @year, month: @month })
    end
    item_counts_by_org = item_counts_query.group('users.organization_id').count
    
    # 추이 모드일 때는 추가로 12개월 데이터 조회
    if @view_mode == 'trend'
      # 12개월 월별 데이터 조회
      @trend_data = {}
      @trend_months = []
      
      12.times do |i|
        month_date = @end_date.beginning_of_month - i.months
        @trend_months.unshift(month_date.strftime("%Y-%m"))
        
        month_expense_totals = ExpenseSheet.joins(:user)
                                          .where(users: { id: all_user_ids })
                                          .where(year: month_date.year, month: month_date.month)
                                          .group('users.organization_id')
                                          .sum(:total_amount)
        
        month_expense_by_code = ExpenseItem.joins(:expense_sheet, :expense_code, expense_sheet: :user)
                                          .where(users: { id: all_user_ids })
                                          .where(expense_sheets: { year: month_date.year, month: month_date.month })
                                          .group('expense_codes.code', 'expense_codes.name')
                                          .sum(:amount)
        
        @trend_data[month_date.strftime("%Y-%m")] = {
          total: month_expense_totals.values.sum,
          by_code: month_expense_by_code
        }
      end
      
      # 전체 기간의 경비 코드 상위 10개 추출
      all_codes = {}
      @trend_data.each do |month, data|
        data[:by_code].each do |(code, name), amount|
          key = [code, name]
          all_codes[key] = (all_codes[key] || 0) + amount
        end
      end
      @top_expense_codes = all_codes.sort_by { |_, v| -v }.first(10).map(&:first)
    end
    
    # 조직별 경비 현황 계산
    @organization_expenses = {}
    
    @managed_organizations.each do |org|
      # path 기반으로 하위 조직 효율적으로 가져오기
      if org.path.present?
        descendant_orgs = all_related_orgs.select { |o| o.path&.start_with?("#{org.path}.") }
        all_descendant_ids = descendant_orgs.map(&:id)
      else
        all_descendant_ids = org.descendant_ids
      end
      
      all_org_ids_including_self = [org.id] + all_descendant_ids
      
      # 미리 조회한 데이터에서 계산
      total_with_descendants = all_org_ids_including_self.sum { |oid| expense_totals_by_org[oid] || 0 }
      org_only_total = expense_totals_by_org[org.id] || 0
      
      # 경비 코드별 합계 계산
      total_by_code = {}
      expense_by_code_and_org.each do |(oid, code, name), amount|
        if all_org_ids_including_self.include?(oid)
          key = [code, name]
          total_by_code[key] = (total_by_code[key] || 0) + amount
        end
      end
      
      # 직속 하위 조직별 상세
      children_details = {}
      org.children.each do |child_org|
        if child_org.path.present?
          child_descendant_orgs = all_related_orgs.select { |o| o.path&.start_with?("#{child_org.path}.") }
          child_all_ids = [child_org.id] + child_descendant_orgs.map(&:id)
        else
          child_all_ids = [child_org.id] + child_org.descendant_ids
        end
        
        child_total = child_all_ids.sum { |oid| expense_totals_by_org[oid] || 0 }
        
        if child_total > 0
          child_by_code = {}
          expense_by_code_and_org.each do |(oid, code, name), amount|
            if child_all_ids.include?(oid)
              key = [code, name]
              child_by_code[key] = (child_by_code[key] || 0) + amount
            end
          end
          
          children_details[child_org] = {
            total: child_total,
            descendant_count: child_all_ids.length - 1,
            by_code: child_by_code
          }
        end
      end
      
      @organization_expenses[org] = {
        name: org.name,
        total_amount: total_with_descendants,
        total_with_descendants: total_with_descendants,
        org_only_total: org_only_total,
        descendant_count: all_descendant_ids.length,
        item_count: all_org_ids_including_self.sum { |oid| item_counts_by_org[oid] || 0 },
        total_by_code: total_by_code,
        children_details: children_details
      }
    end
    
    # 전체 통계 계산 (이미 조회한 데이터 재사용)
    @total_amount = expense_totals_by_org.values.sum
    
    # 전체 경비 코드별 합계
    @total_by_code = {}
    expense_by_code_and_org.each do |(oid, code, name), amount|
      key = [code, name]
      @total_by_code[key] = (@total_by_code[key] || 0) + amount
    end
    @total_by_code = @total_by_code.sort_by { |_, v| -v }.to_h
    
    # 전체 조직 수 계산
    @total_organization_count = all_related_orgs.length
    
    # 이전/다음 네비게이션 날짜 계산
    if @view_mode == 'yearly'
      @prev_year = @year - 1
      @next_year = @year + 1
    else
      current_date = Date.new(@year, @month, 1)
      @prev_date = current_date.prev_month
      @next_date = current_date.next_month
    end
  end
  
  def show
    @organization = Organization.find(params[:id])
    
    # 권한 체크: 자신이 관리하는 조직이거나 그 상위 조직이어야 함
    unless can_view_organization?(@organization)
      respond_to do |format|
        format.html { 
          if request.xhr?
            render plain: '권한이 없습니다.', status: :forbidden
          else
            redirect_to organization_expenses_path, alert: '해당 조직에 대한 권한이 없습니다.'
          end
        }
        format.json { render json: { error: '권한이 없습니다.' }, status: :forbidden }
      end
      return
    end
    
    set_date_params
    
    # 해당 조직과 모든 하위 조직을 효율적으로 로드
    if @organization.path.present?
      # path 기반으로 모든 하위 조직을 한 번에 조회 (자기 자신 포함)
      all_related_orgs = Organization.where("organizations.path = ? OR organizations.path LIKE ?", @organization.path, "#{@organization.path}.%")
      all_org_ids = all_related_orgs.pluck(:id)
    else
      # path가 없는 경우 기존 방식
      all_org_ids = [@organization.id] + @organization.descendant_ids
      all_related_orgs = Organization.where(id: all_org_ids)
    end
    
    # 모든 사용자 ID를 한 번에 조회
    all_user_ids = User.where(organization_id: all_org_ids).pluck(:id)
    
    # 경비 데이터를 효율적으로 조회
    expense_sheets_query = ExpenseSheet.where(user_id: all_user_ids)
                                     .joins(:user)
    if @view_mode == 'yearly'
      expense_sheets_query = expense_sheets_query.where(year: @year)
    else
      expense_sheets_query = expense_sheets_query.where(year: @year, month: @month)
    end
    expense_sheets_data = expense_sheets_query.group('users.organization_id').sum(:total_amount)
    
    # 전체 금액
    @total_amount = expense_sheets_data.values.sum
    
    # 경비 코드별 집계
    expense_items_query = ExpenseItem.joins(:expense_sheet, :expense_code)
                               .where(expense_sheets: { user_id: all_user_ids })
    if @view_mode == 'yearly'
      expense_items_query = expense_items_query.where(expense_sheets: { year: @year })
    else
      expense_items_query = expense_items_query.where(expense_sheets: { year: @year, month: @month })
    end
    @total_by_code = expense_items_query.group('expense_codes.code', 'expense_codes.name')
                               .order('sum_amount DESC')
                               .sum(:amount)
    
    # 하위 조직별 집계 (직접 하위 조직들)
    @children_expenses = {}
    item_counts_query = ExpenseItem.joins(:expense_sheet, expense_sheet: :user)
                            .where(users: { id: all_user_ids })
    if @view_mode == 'yearly'
      item_counts_query = item_counts_query.where(expense_sheets: { year: @year })
    else
      item_counts_query = item_counts_query.where(expense_sheets: { year: @year, month: @month })
    end
    item_counts = item_counts_query.group('users.organization_id').count
    
    @organization.children.each do |child|
      if child.path.present?
        # 자식 조직과 그 하위 조직들 (path 기반)
        child_orgs = all_related_orgs.select { |o| o.path == child.path || o.path&.start_with?("#{child.path}.") }
        child_org_ids = child_orgs.map(&:id)
      else
        # path가 없는 경우 기존 방식
        child_org_ids = [child.id] + child.descendant_ids
      end
      
      child_total = child_org_ids.sum { |oid| expense_sheets_data[oid] || 0 }
      
      if child_total > 0
        @children_expenses[child] = {
          name: child.name,
          total_amount: child_total,
          item_count: child_org_ids.sum { |oid| item_counts[oid] || 0 }
        }
      end
    end
    
    # 경비 항목 수
    @item_count = item_counts.values.sum
    
    # 추이 모드일 때 12개월 데이터 조회
    if @view_mode == 'trend'
      @trend_data = {}
      @trend_months = []
      @trend_item_counts = []
      
      12.times do |i|
        month_date = @end_date.beginning_of_month - i.months
        @trend_months.unshift(month_date.strftime("%Y-%m"))
        
        month_expense_items = ExpenseItem.joins(:expense_sheet, :expense_code)
                                        .where(expense_sheets: { user_id: all_user_ids })
                                        .where(expense_sheets: { year: month_date.year, month: month_date.month })
                                        .group('expense_codes.code', 'expense_codes.name')
                                        .sum(:amount)
        
        # 해당 월의 경비 항목 수 계산
        month_item_count = ExpenseItem.joins(:expense_sheet)
                                     .where(expense_sheets: { user_id: all_user_ids })
                                     .where(expense_sheets: { year: month_date.year, month: month_date.month })
                                     .count
        
        @trend_item_counts << month_item_count
        
        @trend_data[month_date.strftime("%Y-%m")] = {
          total: month_expense_items.values.sum,
          by_code: month_expense_items,
          item_count: month_item_count
        }
      end
      
      # 전체 기간의 경비 코드 상위 10개 추출
      all_codes = {}
      @trend_data.each do |month, data|
        data[:by_code].each do |(code, name), amount|
          key = [code, name]
          all_codes[key] = (all_codes[key] || 0) + amount
        end
      end
      @top_expense_codes = all_codes.sort_by { |_, v| -v }.first(10).map(&:first)
    end
    
    respond_to do |format|
      format.html {
        if request.xhr?
          render partial: 'organization_details', locals: {
            organization: @organization,
            total_amount: @total_amount,
            total_by_code: @total_by_code,
            children_expenses: @children_expenses,
            item_count: @item_count,
            year: @year,
            month: @month,
            view_mode: @view_mode,
            trend_data: @trend_data,
            trend_months: @trend_months,
            top_expense_codes: @top_expense_codes,
            trend_item_counts: @trend_item_counts
          }
        else
          redirect_to organization_expenses_path
        end
      }
      format.json {
        render json: {
          organization: @organization.slice(:id, :name),
          total_amount: @total_amount,
          item_count: @item_count,
          total_by_code: @total_by_code,
          children_expenses: @children_expenses
        }
      }
    end
  end
  
  private
  
  def require_organization_manager
    unless current_user.managed_organizations.any?
      redirect_to root_path, alert: '조직장 권한이 필요합니다.'
    end
  end
  
  def can_view_organization?(organization)
    # 사용자가 해당 조직을 관리하거나, 상위 조직을 관리하는 경우 true
    current_user.managed_organizations.include?(organization) ||
    current_user.managed_organizations.any? { |managed_org| 
      organization.ancestors.include?(managed_org)
    }
  end
  
  def filter_viewable_organizations(organizations)
    # 사용자가 볼 수 있는 조직만 필터링
    organizations.select { |org| can_view_organization?(org) }
  end
  
  def set_date_params
    # 뷰 모드 설정 (monthly, yearly, trend)
    @view_mode = params[:view_mode] || 'monthly'
    
    if @view_mode == 'yearly'
      # 연도별 모드
      @year = params[:year]&.to_i || Date.current.year
      @month = nil  # 연도별 모드에서는 month 사용 안 함
    elsif @view_mode == 'trend'
      # 추이 모드 - 파라미터 또는 현재 날짜 기준으로 12개월
      @year = params[:year]&.to_i || Date.current.year
      @month = params[:month]&.to_i || Date.current.month
      @end_date = Date.new(@year, @month, 1)
      @start_date = @end_date - 11.months
    else
      # 월별 모드 (기존 로직)
      if params[:year].present? && params[:month].present?
        @year = params[:year].to_i
        @month = params[:month].to_i
      else
        @year = Date.current.year
        @month = Date.current.month
      end
      
      # 유효한 날짜인지 확인
      begin
        Date.new(@year, @month, 1)
      rescue ArgumentError
        @year = Date.current.year
        @month = Date.current.month
      end
    end
  end
end