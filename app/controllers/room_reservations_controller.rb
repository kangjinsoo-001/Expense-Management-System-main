class RoomReservationsController < ApplicationController
  # before_action :require_login은 ApplicationController에서 이미 적용됨
  before_action :set_reservation, only: [:edit, :update, :destroy]
  before_action :check_owner, only: [:edit, :update, :destroy]
  
  def index
    @reservations = current_user.room_reservations.includes(:room)
    @upcoming_reservations = @reservations.upcoming
    @past_reservations = @reservations.past.limit(10)
  end

  def new
    @reservation = current_user.room_reservations.build
    @reservation.reservation_date = params[:date] if params[:date]
    @reservation.room_id = params[:room_id] if params[:room_id]
    @reservation.start_time = params[:start_time] if params[:start_time]
    @reservation.end_time = params[:end_time] if params[:end_time]
    @rooms = Room.order(:id)  # 시드 등록 순서대로 (강남→판교→서초)
    
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def create
    @reservation = current_user.room_reservations.build(reservation_params)
    
    respond_to do |format|
      if @reservation.save
        format.html { 
          redirect_to calendar_room_reservations_path(date: @reservation.reservation_date), 
                      notice: '예약이 성공적으로 등록되었습니다.' 
        }
        format.turbo_stream { 
          # 캘린더 데이터 다시 로드
          @date = @reservation.reservation_date
          @highlight_reservation_id = @reservation.id  # 하이라이트용 ID 설정
          # 세션에서 필터 상태 복원
          saved_location = session[:calendar_filter_location]
          params[:location] = saved_location unless saved_location.blank?
          load_calendar_data
        }
      else
        @rooms = Room.order(:id)  # 시드 등록 순서대로 (강남→판교→서초)
        format.html { render :new, status: :unprocessable_entity }
        format.turbo_stream { 
          # 모달에서 호출된 경우 params[:modal]을 유지
          params[:modal] = "true" if request.headers["Turbo-Frame"] == "reservation_form"
          render :new, status: :unprocessable_entity 
        }
      end
    end
  end

  def edit
    @rooms = Room.order(:id)  # 시드 등록 순서대로 (강남→판교→서초)
    
    respond_to do |format|
      format.html
      format.turbo_stream
    end
  end

  def update
    Rails.logger.info "🔄 RoomReservationsController#update: 예약 업데이트 시작"
    Rails.logger.info "📋 업데이트 파라미터: #{reservation_params.inspect}"
    Rails.logger.info "📋 기존 예약 정보: ID=#{@reservation.id}, 시간=#{@reservation.start_time}-#{@reservation.end_time}, 방=#{@reservation.room_id}"
    Rails.logger.info "🔍 필터 파라미터: current_location=#{params[:current_location]}, location=#{params[:location]}"
    
    respond_to do |format|
      if @reservation.update(reservation_params)
        Rails.logger.info "✅ 예약 업데이트 성공!"
        format.html { redirect_to room_reservations_path, notice: '예약이 수정되었습니다.' }
        format.json { render json: @reservation, status: :ok }
        format.turbo_stream { 
          # 캘린더 데이터 다시 로드
          @date = @reservation.reservation_date
          @highlight_reservation_id = @reservation.id  # 하이라이트용 ID 설정
          # 세션에서 필터 상태 복원
          saved_location = session[:calendar_filter_location]
          params[:location] = saved_location unless saved_location.blank?
          Rails.logger.info "🔄 update 액션 - 세션에서 필터 복원: #{saved_location.inspect} -> params[:location]=#{params[:location].inspect}"
          load_calendar_data
          render :update
        }
      else
        Rails.logger.error "❌ 예약 업데이트 실패: #{@reservation.errors.full_messages}"
        format.html do
          @rooms = Room.order(:id)  # 시드 등록 순서대로 (강남→판교→서초)
          render :edit, status: :unprocessable_entity
        end
        format.json { 
          render json: { 
            errors: @reservation.errors.full_messages,
            error: @reservation.errors.full_messages.join(', ')
          }, status: :unprocessable_entity 
        }
        format.turbo_stream {
          render json: { 
            errors: @reservation.errors.full_messages,
            error: @reservation.errors.full_messages.join(', ')
          }, status: :unprocessable_entity
        }
      end
    end
  end

  def destroy
    @date = @reservation.reservation_date
    @reservation.destroy
    
    respond_to do |format|
      format.html { redirect_to room_reservations_path, notice: '예약이 취소되었습니다.' }
      format.turbo_stream {
        # 캘린더 데이터 다시 로드
        # 세션에서 필터 상태 복원
        saved_location = session[:calendar_filter_location]
        params[:location] = saved_location unless saved_location.blank?
        load_calendar_data
        # destroy.turbo_stream.erb 파일 사용하여 렌더링
      }
    end
  end

  def calendar
    @date = params[:date] ? Date.parse(params[:date]) : Date.today
    
    # 필터 상태를 세션에 저장
    # 필터 링크를 클릭했을 때만 세션 업데이트 (드래그 액션 제외)
    if request.get?
      # "전체" 링크는 location 파라미터 없이 오므로 nil로 저장
      # 특정 필터는 location 파라미터와 함께 오므로 해당 값 저장
      session[:calendar_filter_location] = params[:location].presence
      Rails.logger.info "📌 세션에 필터 저장: #{session[:calendar_filter_location].inspect} (nil=전체)"
    end
    
    # 모든 회의실 (모달용 - ID 순서대로)
    @all_rooms = Room.order(:id)
    
    # DB에서 실제 카테고리 목록 가져오기 (생성 순서대로)
    @available_categories = Room.select(:category).distinct.where.not(category: nil).order(:id).pluck(:category)
    
    # 지점별 필터링 (카테고리 기반)
    @filtered_rooms = if params[:location].present?
      Room.by_category(params[:location]).ordered_by_category
    else
      Room.ordered_by_category
    end
    
    @reservations = RoomReservation.for_date(@date).includes(:user)
    
    # 시간별 예약 데이터 구성
    @time_slots = {}
    (9..18).each do |hour|
      @time_slots[hour] = {}
      @filtered_rooms.each do |room|
        reservation = @reservations.find do |r| 
          r.room_id == room.id && 
          r.start_time.hour <= hour && 
          r.end_time.hour > hour
        end
        @time_slots[hour][room.id] = reservation
      end
    end
  end
  
  private
  
  def set_reservation
    @reservation = RoomReservation.find(params[:id])
  end
  
  def check_owner
    unless @reservation.user == current_user || current_user.admin?
      redirect_to room_reservations_path, alert: '권한이 없습니다.'
    end
  end
  
  def reservation_params
    params.require(:room_reservation).permit(:room_id, :reservation_date, :start_time, :end_time, :purpose)
  end
  
  def load_calendar_data
    # 캘린더 뷰에서 사용하는 데이터 로드
    @all_rooms = Room.ordered_by_category
    @available_categories = Room.select(:category).distinct.where.not(category: nil).order(:id).pluck(:category)
    
    Rails.logger.info "🔍 load_calendar_data 필터: params[:location]=#{params[:location]}"
    
    # 현재 필터에 따른 회의실 목록
    @filtered_rooms = if params[:location].present?
      Room.by_category(params[:location]).ordered_by_category.includes(:room_reservations)
    else
      Room.ordered_by_category.includes(:room_reservations)
    end
    
    Rails.logger.info "📊 필터링된 회의실: #{@filtered_rooms.count}개 - #{@filtered_rooms.map(&:name).join(', ')}"
    
    @reservations = RoomReservation.for_date(@date).includes(:room, :user)
    
    # 시간별 예약 데이터 구성
    @time_slots = {}
    (9..18).each do |hour|
      @time_slots[hour] = {}
      @filtered_rooms.each do |room|
        reservation = @reservations.find do |r| 
          r.room_id == room.id && 
          r.start_time.hour <= hour && 
          r.end_time.hour > hour
        end
        @time_slots[hour][room.id] = reservation
      end
    end
  end
end
