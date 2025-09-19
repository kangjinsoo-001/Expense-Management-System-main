module CacheHelper
  # 사용자별 캐시 키 생성
  def user_cache_key(prefix, user = current_user)
    "#{prefix}/user-#{user.id}/#{user.updated_at.to_i}"
  end
  
  # 조직별 캐시 키 생성
  def organization_cache_key(prefix, organization)
    "#{prefix}/org-#{organization.id}/#{organization.updated_at.to_i}"
  end
  
  # 기간별 캐시 키 생성
  def period_cache_key(prefix, year, month)
    "#{prefix}/#{year}-#{month}"
  end
  
  # 경비 시트 목록 캐시 키
  def expense_sheets_cache_key(user = current_user)
    count = user.expense_sheets.count
    max_updated_at = user.expense_sheets.maximum(:updated_at)
    "expense_sheets/user-#{user.id}/count-#{count}/updated-#{max_updated_at.to_i}"
  end
  
  # 대시보드 통계 캐시 키
  def dashboard_stats_cache_key(period)
    "dashboard_stats/#{period}/#{Date.current}"
  end
  
  # 승인 대기 목록 캐시 키
  def pending_approvals_cache_key(user = current_user)
    count = user.pending_approval_steps.count
    "pending_approvals/user-#{user.id}/count-#{count}"
  end
end