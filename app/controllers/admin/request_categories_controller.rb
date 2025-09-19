class Admin::RequestCategoriesController < Admin::BaseController
  before_action :set_request_category, only: [:show, :edit, :update, :destroy, :toggle_active]
  
  def index
    @request_categories = RequestCategory.ordered
    @breadcrumbs = [
      { name: '홈', path: root_path },
      { name: '관리자', path: admin_root_path },
      { name: '신청서 카테고리 관리' }
    ]
  end
  
  def show
    @request_templates = @request_category.request_templates.ordered
  end
  
  def new
    @request_category = RequestCategory.new
    @breadcrumbs = [
      { name: '홈', path: root_path },
      { name: '관리자', path: admin_root_path },
      { name: '신청서 카테고리 관리', path: admin_request_categories_path },
      { name: '새 카테고리' }
    ]
  end
  
  def create
    @request_category = RequestCategory.new(request_category_params)
    
    if @request_category.save
      redirect_to admin_request_categories_path, notice: '카테고리가 생성되었습니다.', status: :see_other
    else
      render :new, status: :unprocessable_entity
    end
  end
  
  def edit
    @breadcrumbs = [
      { name: '홈', path: root_path },
      { name: '관리자', path: admin_root_path },
      { name: '신청서 카테고리 관리', path: admin_request_categories_path },
      { name: @request_category.name }
    ]
  end
  
  def update
    if @request_category.update(request_category_params)
      redirect_to admin_request_categories_path, notice: '카테고리가 수정되었습니다.', status: :see_other
    else
      render :edit, status: :unprocessable_entity
    end
  end
  
  def destroy
    if @request_category.request_templates.any?
      redirect_to admin_request_categories_path, alert: '템플릿이 있는 카테고리는 삭제할 수 없습니다.', status: :see_other
    else
      @request_category.destroy
      redirect_to admin_request_categories_path, notice: '카테고리가 삭제되었습니다.', status: :see_other
    end
  end
  
  def toggle_active
    @request_category.update(is_active: !@request_category.is_active)
    redirect_to admin_request_categories_path, notice: '카테고리 상태가 변경되었습니다.', status: :see_other
  end
  
  def update_order
    params[:order].each_with_index do |id, index|
      RequestCategory.find(id).update(display_order: index)
    end
    
    head :ok
  end
  
  private
  
  def set_request_category
    @request_category = RequestCategory.find(params[:id])
  end
  
  def request_category_params
    params.require(:request_category).permit(:name, :description, :display_order, :is_active)
  end
end