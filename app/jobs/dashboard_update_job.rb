class DashboardUpdateJob < ApplicationJob
  queue_as :default
  
  # 스로틀링을 위한 최소 간격 (초)
  THROTTLE_INTERVAL = 5.seconds
  
  # 업데이트 타입별 처리
  def perform(update_type, resource_id = nil)
    # 스로틀링 체크
    return if recently_updated?(update_type, resource_id)
    
    case update_type
    when 'expense_sheet_update'
      handle_expense_sheet_update(resource_id)
    when 'approval_update'
      handle_approval_update(resource_id)
    when 'periodic_refresh'
      handle_periodic_refresh
    else
      Rails.logger.warn "Unknown dashboard update type: #{update_type}"
    end
    
    # 업데이트 시간 기록
    record_update_time(update_type, resource_id)
  end
  
  private
  
  def handle_expense_sheet_update(expense_sheet_id)
    expense_sheet = ExpenseSheet.find_by(id: expense_sheet_id)
    return unless expense_sheet
    
    DashboardBroadcastService.broadcast_expense_sheet_update(expense_sheet)
  end
  
  def handle_approval_update(approval_step_id)
    approval_step = ApprovalStep.find_by(id: approval_step_id)
    return unless approval_step
    
    DashboardBroadcastService.broadcast_approval_update(approval_step)
  end
  
  def handle_periodic_refresh
    # 주기적인 전체 대시보드 새로고침
    stats_service = ExpenseStatisticsService.new('this_month')
    
    # 캐시 무효화하여 최신 데이터 가져오기
    stats_service.invalidate_cache!
    
    # 전체 관리자에게 브로드캐스트
    ActionCable.server.broadcast(
      "admin_dashboard",
      {
        action: "refresh_section",
        section: "dashboard-main"
      }
    )
  end
  
  def recently_updated?(update_type, resource_id)
    cache_key = "dashboard_update:#{update_type}:#{resource_id || 'all'}"
    last_update = Rails.cache.read(cache_key)
    
    return false unless last_update
    
    Time.current - last_update < THROTTLE_INTERVAL
  end
  
  def record_update_time(update_type, resource_id)
    cache_key = "dashboard_update:#{update_type}:#{resource_id || 'all'}"
    Rails.cache.write(cache_key, Time.current, expires_in: 1.minute)
  end
end