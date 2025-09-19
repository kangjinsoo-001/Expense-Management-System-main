class OrganizationsController < ApplicationController
  include TurboCacheControl
  include OrganizationTreeLoadable
  
  layout 'admin'
  
  before_action :require_login
  before_action :set_organization, only: [:show, :edit, :update, :destroy, :assign_manager, :remove_manager, :add_user, :remove_user, :manage_users]
  before_action :authorize_management!, only: [:edit, :update, :destroy, :assign_manager, :remove_manager, :add_user, :remove_user, :manage_users]
  before_action :authorize_creation!, only: [:new, :create]
  
  def index
    # 조직 트리의 최대 깊이를 계산하여 동적으로 includes 구성
    # 성능을 위해 최대 10단계로 제한
    max_depth = [calculate_max_depth, 10].min
    includes_hash = build_recursive_includes(max_depth)
    
    @organizations = Organization.includes(includes_hash)
                                .where(parent_id: nil)
                                .order(:name)
  end

  def show
    @children = @organization.children.includes(:manager)
    @users = @organization.users || []
  end

  def new
    @organization = Organization.new
    @organizations = Organization.includes(:manager, :children).order(:name)
    @users = User.all.order(:name)
  end

  def create
    @organization = Organization.new(organization_params)
    
    if @organization.save
      redirect_with_turbo_reload @organization, notice: '조직이 성공적으로 생성되었습니다.', status: :see_other
    else
      @organizations = Organization.includes(:manager, :children).order(:name)
      @users = User.all.order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    @organizations = Organization.includes(:manager, :children).where.not(id: @organization.id).order(:name)
    @users = User.all.order(:name)
  end

  def update
    if @organization.update(organization_params)
      redirect_with_turbo_reload @organization, notice: '조직이 성공적으로 수정되었습니다.', status: :see_other
    else
      @organizations = Organization.includes(:manager, :children).where.not(id: @organization.id).order(:name)
      @users = User.all.order(:name)
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @organization.soft_delete
    redirect_to organizations_url, notice: '조직이 성공적으로 삭제되었습니다.', status: :see_other
  end
  
  def assign_manager
    @user = User.find(params[:user_id])
    
    if @organization.assign_manager(@user)
      redirect_to @organization, notice: "#{@user.name}님이 조직장으로 지정되었습니다.", status: :see_other
    else
      redirect_to @organization, alert: '조직장 지정에 실패했습니다.', status: :see_other
    end
  end
  
  def remove_manager
    if @organization.remove_manager
      redirect_to @organization, notice: '조직장이 해제되었습니다.', status: :see_other
    else
      redirect_to @organization, alert: '조직장 해제에 실패했습니다.', status: :see_other
    end
  end
  
  def manage_users
    @users = @organization.users.includes(:organization).order(:name)
    @available_users = User.where.not(organization_id: @organization.id).order(:name)
  end
  
  def add_user
    @user = User.find(params[:user_id])
    
    if @user.update(organization: @organization)
      redirect_to manage_users_organization_path(@organization), notice: "#{@user.name}님이 조직에 추가되었습니다.", status: :see_other
    else
      redirect_to manage_users_organization_path(@organization), alert: '사용자 추가에 실패했습니다.', status: :see_other
    end
  end
  
  def remove_user
    @user = User.find(params[:user_id])
    
    # 조직장인 경우 먼저 조직장 해제
    if @organization.manager == @user
      @organization.remove_manager
    end
    
    if @user.update(organization: nil)
      redirect_to manage_users_organization_path(@organization), notice: "#{@user.name}님이 조직에서 제거되었습니다.", status: :see_other
    else
      redirect_to manage_users_organization_path(@organization), alert: '사용자 제거에 실패했습니다.', status: :see_other
    end
  end
  
  private
  
  def set_organization
    @organization = Organization.includes(:manager, :parent).find(params[:id])
  end
  
  def organization_params
    params.require(:organization).permit(:name, :code, :parent_id, :manager_id)
  end
  
  def authorize_management!
    authorize_organization_manager!(@organization)
  end
  
  def authorize_creation!
    unless current_user.admin? || current_user.manager?
      flash[:alert] = "조직을 생성할 권한이 없습니다."
      redirect_to organizations_path
    end
  end
  
end
