class Admin::ApproverGroupsController < Admin::BaseController
  include TurboCacheControl
  
  before_action :set_approver_group, only: [:show, :edit, :update, :destroy, :toggle_active, :add_member, :remove_member, :update_members]
  
  def index
    @approver_groups = ApproverGroup.includes(:created_by)
                                    .order(priority: :desc, name: :asc)
                                    .page(params[:page]).per(20)
  end

  def show
    @members = @approver_group.approver_group_members
                             .includes(user: :organization, added_by: :organization)
                             .order('users.name')
    @available_users = User.includes(:organization)
                          .where.not(id: @approver_group.member_ids)
                          .order(:name)
  end

  def new
    @approver_group = ApproverGroup.new
  end

  def create
    @approver_group = ApproverGroup.new(approver_group_params)
    @approver_group.created_by = current_user
    
    if @approver_group.save
      redirect_to admin_approver_groups_path, notice: '승인자 그룹이 생성되었습니다.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @approver_group.update(approver_group_params)
      redirect_to admin_approver_groups_path, notice: '승인자 그룹이 수정되었습니다.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    if @approver_group.expense_code_approval_rules.exists?
      redirect_to admin_approver_groups_path, alert: '경비 코드 승인 규칙에서 사용 중인 그룹은 삭제할 수 없습니다.'
    else
      @approver_group.destroy
      redirect_to admin_approver_groups_path, notice: '승인자 그룹이 삭제되었습니다.'
    end
  end
  
  def toggle_active
    @approver_group.update(is_active: !@approver_group.is_active)
    
    respond_to do |format|
      format.html { redirect_to admin_approver_groups_path }
      format.turbo_stream {
        render turbo_stream: turbo_stream.replace(@approver_group,
          partial: "admin/approver_groups/approver_group",
          locals: { approver_group: @approver_group }
        )
      }
    end
  end
  
  def add_member
    # 멀티셀렉트 지원: user_ids[] 또는 user_id 둘 다 처리
    user_ids = params[:user_ids] || [params[:user_id]]
    user_ids = user_ids.compact.reject(&:blank?)
    
    if user_ids.empty?
      respond_to do |format|
        format.html { redirect_to admin_approver_group_path(@approver_group), alert: '사용자를 선택해주세요.' }
        format.turbo_stream { 
          render turbo_stream: turbo_stream.prepend("flash_container",
            partial: "shared/flash_message",
            locals: { type: :alert, message: '사용자를 선택해주세요.' }
          )
        }
      end
      return
    end
    
    # 선택된 사용자들 추가
    added_count = 0
    already_members = []
    
    user_ids.each do |user_id|
      user = User.find(user_id)
      if @approver_group.add_member(user, current_user)
        added_count += 1
      else
        already_members << user.name
      end
    end
    
    @approver_group.reload
    @members = @approver_group.approver_group_members
                             .includes(user: :organization, added_by: :organization)
                             .order('users.name')
    @available_users = User.includes(:organization)
                          .where.not(id: @approver_group.member_ids)
                          .order(:name)
    
    # 메시지 생성
    messages = []
    messages << "#{added_count}명의 멤버가 추가되었습니다." if added_count > 0
    messages << "다음 사용자는 이미 멤버입니다: #{already_members.join(', ')}" if already_members.any?
    
    respond_to do |format|
      format.html { 
        redirect_to admin_approver_group_path(@approver_group), 
        notice: messages.join(' ') 
      }
      format.turbo_stream {
        render turbo_stream: [
          turbo_stream.replace("members_list_wrapper", 
            partial: "admin/approver_groups/members_list_wrapper", 
            locals: { approver_group: @approver_group, members: @members }
          ),
          turbo_stream.replace("add_member_form",
            partial: "admin/approver_groups/add_member_form",
            locals: { approver_group: @approver_group, available_users: @available_users }
          ),
          messages.present? ? turbo_stream.prepend("flash_container",
            partial: "shared/flash_message",
            locals: { type: :notice, message: messages.join(' ') }
          ) : nil
        ].compact
      }
    end
  end
  
  def remove_member
    member = @approver_group.approver_group_members.find(params[:member_id])
    member.destroy
    
    @approver_group.reload
    @members = @approver_group.approver_group_members
                             .includes(user: :organization, added_by: :organization)
                             .order('users.name')
    @available_users = User.includes(:organization)
                          .where.not(id: @approver_group.member_ids)
                          .order(:name)
    
    respond_to do |format|
      format.html { redirect_to admin_approver_group_path(@approver_group), notice: '멤버가 제거되었습니다.' }
      format.turbo_stream {
        render turbo_stream: [
          turbo_stream.replace("members_list_wrapper", 
            partial: "admin/approver_groups/members_list_wrapper", 
            locals: { approver_group: @approver_group, members: @members }
          ),
          turbo_stream.replace("add_member_form",
            partial: "admin/approver_groups/add_member_form",
            locals: { approver_group: @approver_group, available_users: @available_users }
          )
        ]
      }
    end
  end
  
  def update_members
    new_user_ids = params[:user_ids]&.map(&:to_i) || []
    current_user_ids = @approver_group.member_ids
    
    # 추가할 사용자
    users_to_add = new_user_ids - current_user_ids
    # 제거할 사용자
    users_to_remove = current_user_ids - new_user_ids
    
    ActiveRecord::Base.transaction do
      # 사용자 추가
      users_to_add.each do |user_id|
        user = User.find(user_id)
        @approver_group.add_member(user, current_user)
      end
      
      # 사용자 제거
      @approver_group.approver_group_members
                     .joins(:user)
                     .where(users: { id: users_to_remove })
                     .destroy_all
    end
    
    @approver_group.reload
    @members = @approver_group.approver_group_members
                             .includes(user: :organization, added_by: :organization)
                             .order('users.name')
    
    respond_to do |format|
      format.html { 
        redirect_to admin_approver_group_path(@approver_group), 
        notice: '멤버가 성공적으로 업데이트되었습니다.' 
      }
      format.turbo_stream # update_members.turbo_stream.erb를 렌더링
    end
  end
  
  private
  
  def set_approver_group
    @approver_group = ApproverGroup.find(params[:id])
  end
  
  def approver_group_params
    params.require(:approver_group).permit(:name, :description, :priority, :is_active)
  end
end
