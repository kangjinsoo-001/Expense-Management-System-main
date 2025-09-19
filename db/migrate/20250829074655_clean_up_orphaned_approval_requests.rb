class CleanUpOrphanedApprovalRequests < ActiveRecord::Migration[8.0]
  def up
    # 트랜잭션 내에서 실행
    ActiveRecord::Base.transaction do
      # 1. 고아 ApprovalRequest 찾기 (expense_item이 없는 경우)
      orphaned_approval_requests = ApprovalRequest
        .left_joins(:expense_item)
        .where(expense_items: { id: nil })
        .where.not(expense_item_id: nil)  # expense_item_id가 있지만 실제 레코드가 없는 경우
      
      puts "고아 ApprovalRequest 수: #{orphaned_approval_requests.count}"
      
      if orphaned_approval_requests.any?
        # 관련 ApprovalHistory 먼저 삭제
        orphaned_ids = orphaned_approval_requests.pluck(:id)
        
        # 관련 레코드 삭제 카운트
        history_count = ApprovalHistory.where(approval_request_id: orphaned_ids).count
        step_count = ApprovalRequestStep.where(approval_request_id: orphaned_ids).count
        
        # 관련 데이터 삭제
        ApprovalHistory.where(approval_request_id: orphaned_ids).destroy_all
        ApprovalRequestStep.where(approval_request_id: orphaned_ids).destroy_all
        
        # ApprovalRequest 삭제
        orphaned_approval_requests.destroy_all
        
        puts "삭제 완료:"
        puts "  - ApprovalRequest: #{orphaned_ids.length}개"
        puts "  - ApprovalHistory: #{history_count}개"
        puts "  - ApprovalRequestStep: #{step_count}개"
      end
      
      # 2. Polymorphic 관계의 고아 레코드도 정리
      polymorphic_orphans = ApprovalRequest
        .where(approvable_type: 'ExpenseItem')
        .where.not(approvable_id: ExpenseItem.select(:id))
      
      if polymorphic_orphans.any?
        count = polymorphic_orphans.count
        
        # 관련 레코드 ID들
        orphan_ids = polymorphic_orphans.pluck(:id)
        
        # 관련 데이터 삭제
        ApprovalHistory.where(approval_request_id: orphan_ids).destroy_all
        ApprovalRequestStep.where(approval_request_id: orphan_ids).destroy_all
        
        # ApprovalRequest 삭제
        polymorphic_orphans.destroy_all
        
        puts "Polymorphic 고아 레코드 #{count}개를 삭제했습니다."
      end
      
      puts "데이터 정리가 완료되었습니다."
    end
  end
  
  def down
    # 되돌릴 수 없는 작업
    puts "이 마이그레이션은 되돌릴 수 없습니다 (데이터 삭제 작업)."
  end
end
