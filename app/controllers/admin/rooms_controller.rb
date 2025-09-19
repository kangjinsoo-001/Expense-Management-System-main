class Admin::RoomsController < Admin::BaseController
  before_action :set_room, only: [:edit, :update, :destroy]
  
  def index
    @rooms = Room.ordered_by_category.includes(:room_reservations, :room_category)
  end

  def new
    @room = Room.new
  end

  def create
    @room = Room.new(room_params)
    
    if @room.save
      redirect_to admin_rooms_path, notice: '회의실이 생성되었습니다.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @room.update(room_params)
      redirect_to admin_rooms_path, notice: '회의실이 수정되었습니다.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @room.destroy
    redirect_to admin_rooms_path, notice: '회의실이 삭제되었습니다.'
  end
  
  private
  
  def set_room
    @room = Room.find(params[:id])
  end
  
  def room_params
    params.require(:room).permit(:name, :category, :room_category_id)
  end
end
