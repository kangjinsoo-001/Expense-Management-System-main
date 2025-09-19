module CacheInvalidation
  extend ActiveSupport::Concern
  
  included do
    after_commit :invalidate_related_caches
  end
  
  private
  
  def invalidate_related_caches
    case self.class.name
    when 'ExpenseSheet'
      invalidate_expense_sheet_caches
    when 'ExpenseItem'
      invalidate_expense_item_caches
    when 'ApprovalFlow'
      invalidate_approval_caches
    when 'User'
      invalidate_user_caches
    when 'Organization'
      invalidate_organization_caches
    end
  end
  
  def invalidate_expense_sheet_caches
    # SolidCache는 delete_matched를 지원하지 않으므로 개별 키 삭제
    # 경비 시트 관련 캐시 무효화
    delete_cache_keys([
      "expense_sheets/user-#{user_id}/index",
      "expense_sheets/user-#{user_id}/recent",
      "dashboard_stats/overview",
      "admin_dashboard_stats/main"
    ])
    
    # 조직별 캐시 무효화
    if organization_id
      delete_cache_keys([
        "organization_stats/#{organization_id}/summary",
        "organization_stats/#{organization_id}/trends"
      ])
    end
    
    # 기간별 통계 캐시 무효화
    delete_cache_keys([
      "expense_statistics/monthly/#{year}-#{month}",
      "expense_statistics/summary/#{year}-#{month}"
    ])
  end
  
  def invalidate_expense_item_caches
    # 경비 항목 관련 캐시 무효화
    if expense_sheet
      delete_cache_keys([
        "expense_sheet/#{expense_sheet.id}/items",
        "expense_sheet/#{expense_sheet.id}/summary"
      ])
      expense_sheet.touch # 경비 시트도 업데이트하여 캐시 무효화
    end
    
    # 통계 캐시 무효화
    delete_cache_keys([
      "expense_code_stats/#{expense_code_id}",
      "expense_code_stats/summary"
    ])
    
    if cost_center_id
      delete_cache_keys([
        "cost_center_stats/#{cost_center_id}",
        "cost_center_stats/summary"
      ])
    end
  end
  
  def invalidate_approval_caches
    # 승인 관련 캐시 무효화
    delete_cache_keys([
      "pending_approvals/all",
      "pending_approvals/count",
      "approval_stats/summary"
    ])
    
    if expense_sheet
      expense_sheet.touch
    end
  end
  
  def invalidate_user_caches
    # 사용자 관련 캐시 무효화
    delete_cache_keys([
      "user-#{id}/profile",
      "user-#{id}/settings",
      "pending_approvals/user-#{id}"
    ])
  end
  
  def invalidate_organization_caches
    # 조직 관련 캐시 무효화
    delete_cache_keys([
      "organization-#{id}/info",
      "organization-#{id}/users",
      "organization_stats/#{id}/summary"
    ])
  end
  
  private
  
  def delete_cache_keys(keys)
    keys.each { |key| Rails.cache.delete(key) }
  end
end