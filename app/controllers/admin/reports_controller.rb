class Admin::ReportsController < Admin::BaseController
  before_action :set_report_template, only: [:show, :edit, :update, :destroy]
  
  def index
    @report_templates = current_user.admin? ? ReportTemplate.all : ReportTemplate.by_user(current_user)
    @recent_exports = ReportExport.by_user(current_user).recent.limit(10)
    
    # 빠른 리포트 생성을 위한 기본 필터
    @quick_filters = {
      periods: [
        { label: '이번 달', value: 'this_month' },
        { label: '지난 달', value: 'last_month' },
        { label: '이번 분기', value: 'this_quarter' },
        { label: '올해', value: 'this_year' }
      ],
      formats: [
        { label: 'Excel', value: 'excel' },
        { label: 'PDF', value: 'pdf' },
        { label: 'CSV', value: 'csv' }
      ]
    }
  end

  def show
    @exports = @report_template.report_exports.recent.limit(20)
  end

  def new
    @report_template = ReportTemplate.new
    @available_columns = available_report_columns
    @filter_options = build_filter_options
  end

  def create
    @report_template = ReportTemplate.new(report_template_params)
    @report_template.user = current_user
    
    if @report_template.save
      redirect_to admin_report_path(@report_template), notice: '리포트 템플릿이 생성되었습니다.'
    else
      @available_columns = available_report_columns
      @filter_options = build_filter_options
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @available_columns = available_report_columns
    @filter_options = build_filter_options
  end

  def update
    if @report_template.update(report_template_params)
      redirect_to admin_report_path(@report_template), notice: '리포트 템플릿이 수정되었습니다.'
    else
      @available_columns = available_report_columns
      @filter_options = build_filter_options
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @report_template.destroy
    redirect_to admin_reports_path, notice: '리포트 템플릿이 삭제되었습니다.'
  end

  # 리포트 생성 (export)
  def export
    # 템플릿 기반 또는 즉시 생성
    if params[:template_id].present?
      template = ReportTemplate.find(params[:template_id])
      filters = template.filters
    else
      template = nil
      filters = build_filters_from_params
    end
    
    # 리포트 생성 기록
    report_export = ReportExport.create!(
      report_template: template,
      user: current_user,
      status: 'pending'
    )
    
    # 백그라운드 Job으로 처리
    ReportExportJob.perform_later(report_export.id)
    
    respond_to do |format|
      format.html { redirect_to admin_reports_path, notice: '리포트 생성이 시작되었습니다. 완료되면 알려드리겠습니다.' }
      format.json { render json: { status: 'processing', export_id: report_export.id } }
    end
  end

  # 리포트 다운로드
  def download
    @report_export = ReportExport.find(params[:id])
    
    # 권한 확인
    unless @report_export.user == current_user || current_user.admin?
      redirect_to admin_reports_path, alert: '권한이 없습니다.'
      return
    end
    
    if @report_export.export_file.attached?
      redirect_to @report_export.export_file.url, allow_other_host: true
    else
      redirect_to admin_reports_path, alert: '파일을 찾을 수 없습니다.'
    end
  end

  # 리포트 생성 상태 확인 (AJAX)
  def status
    @report_export = ReportExport.find(params[:id])
    
    render json: {
      id: @report_export.id,
      status: @report_export.status,
      progress: calculate_progress(@report_export),
      download_url: @report_export.completed? ? download_admin_report_path(@report_export) : nil
    }
  end

  private

  def set_report_template
    @report_template = ReportTemplate.find(params[:id])
  end

  def report_template_params
    params.require(:report_template).permit(
      :name, 
      :description, 
      :export_format,
      filter_config: {},
      columns_config: []
    )
  end

  def available_report_columns
    [
      { id: 'date', label: '사용일', default: true },
      { id: 'user_name', label: '사용자', default: true },
      { id: 'organization_name', label: '조직', default: true },
      { id: 'expense_code', label: '경비 코드', default: true },
      { id: 'amount', label: '금액', default: true },
      { id: 'description', label: '설명', default: true },
      { id: 'status', label: '상태', default: true },
      { id: 'approved_at', label: '승인일시', default: false },
      { id: 'year_month', label: '귀속월', default: false },
      { id: 'remarks', label: '비고', default: false },
      { id: 'cost_center', label: 'Cost Center', default: false },
      { id: 'approver', label: '승인자', default: false },
      { id: 'rejection_reason', label: '반려 사유', default: false }
    ]
  end

  def build_filter_options
    {
      organizations: Organization.order(:name).pluck(:name, :id),
      users: User.order(:name).pluck(:name, :id),
      expense_codes: ExpenseCode.active.order(:name).pluck(:name, :id),
      cost_centers: CostCenter.active.order(:name).pluck(:name, :id),
      statuses: ExpenseSheet.statuses.map { |k, v| [I18n.t("expense_sheet.status.#{k}"), k] }
    }
  end

  def build_filters_from_params
    filters = {}
    
    # 기간 필터
    case params[:period]
    when 'this_month'
      filters['date_from'] = Date.current.beginning_of_month
      filters['date_to'] = Date.current.end_of_month
    when 'last_month'
      filters['date_from'] = 1.month.ago.beginning_of_month
      filters['date_to'] = 1.month.ago.end_of_month
    when 'this_quarter'
      filters['date_from'] = Date.current.beginning_of_quarter
      filters['date_to'] = Date.current.end_of_quarter
    when 'this_year'
      filters['date_from'] = Date.current.beginning_of_year
      filters['date_to'] = Date.current.end_of_year
    else
      filters['date_from'] = params[:date_from] if params[:date_from].present?
      filters['date_to'] = params[:date_to] if params[:date_to].present?
    end
    
    # 기타 필터
    filters['organization_id'] = params[:organization_id] if params[:organization_id].present?
    filters['user_id'] = params[:user_id] if params[:user_id].present?
    filters['expense_code_id'] = params[:expense_code_id] if params[:expense_code_id].present?
    filters['cost_center_id'] = params[:cost_center_id] if params[:cost_center_id].present?
    filters['status'] = params[:status] if params[:status].present?
    
    filters
  end

  def calculate_progress(report_export)
    case report_export.status
    when 'pending' then 0
    when 'processing' then 50
    when 'completed' then 100
    when 'failed' then 0
    else 0
    end
  end
end
