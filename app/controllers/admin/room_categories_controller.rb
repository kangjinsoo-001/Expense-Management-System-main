class Admin::RoomCategoriesController < Admin::BaseController
  before_action :set_room_category, only: [:show, :edit, :update, :destroy, :toggle_active]
  
  def index
    @room_categories = RoomCategory.ordered
    @breadcrumbs = [
      { name: '홈', path: root_path },
      { name: '관리자', path: admin_root_path },
      { name: '회의실 카테고리 관리' }
    ]
  end
  
  def show
    @rooms = @room_category.rooms.ordered
  end
  
  def new
    @room_category = RoomCategory.new
    @breadcrumbs = [
      { name: '홈', path: root_path },
      { name: '관리자', path: admin_root_path },
      { name: '회의실 카테고리 관리', path: admin_room_categories_path },
      { name: '새 카테고리' }
    ]
  end
  
  def create
    @room_category = RoomCategory.new(room_category_params)
    
    if @room_category.save
      redirect_to admin_room_categories_path, notice: '카테고리가 생성되었습니다.'
    else
      render :new, status: :unprocessable_entity
    end
  end
  
  def edit
    @breadcrumbs = [
      { name: '홈', path: root_path },
      { name: '관리자', path: admin_root_path },
      { name: '회의실 카테고리 관리', path: admin_room_categories_path },
      { name: @room_category.name }
    ]
  end
  
  def update
    if @room_category.update(room_category_params)
      redirect_to admin_room_categories_path, notice: '카테고리가 수정되었습니다.'
    else
      render :edit, status: :unprocessable_entity
    end
  end
  
  def destroy
    if @room_category.rooms.any?
      redirect_to admin_room_categories_path, alert: '회의실이 있는 카테고리는 삭제할 수 없습니다.'
    else
      @room_category.destroy
      redirect_to admin_room_categories_path, notice: '카테고리가 삭제되었습니다.'
    end
  end
  
  def toggle_active
    @room_category.update(is_active: !@room_category.is_active)
    redirect_to admin_room_categories_path, notice: '카테고리 상태가 변경되었습니다.'
  end
  
  def update_order
    params[:order].each_with_index do |id, index|
      RoomCategory.find(id).update(display_order: index)
    end
    
    head :ok
  end
  
  private
  
  def set_room_category
    @room_category = RoomCategory.find(params[:id])
  end
  
  def room_category_params
    params.require(:room_category).permit(:name, :description, :display_order, :is_active)
  end
end