class CleanUpOrphanedRequestFormApprovals < ActiveRecord::Migration[8.0]
  def up
    ActiveRecord::Base.transaction do
      # RequestForm 관련 고아 ApprovalRequest 찾기
      orphaned_requests = ApprovalRequest
        .where(approvable_type: 'RequestForm')
        .where.not(approvable_id: RequestForm.select(:id))
      
      puts "RequestForm 고아 ApprovalRequest 수: #{orphaned_requests.count}"
      
      if orphaned_requests.any?
        orphaned_ids = orphaned_requests.pluck(:id)
        
        # 관련 레코드 카운트
        history_count = ApprovalHistory.where(approval_request_id: orphaned_ids).count
        step_count = ApprovalRequestStep.where(approval_request_id: orphaned_ids).count
        
        # 관련 데이터 삭제
        ApprovalHistory.where(approval_request_id: orphaned_ids).destroy_all
        ApprovalRequestStep.where(approval_request_id: orphaned_ids).destroy_all
        orphaned_requests.destroy_all
        
        puts "삭제 완료:"
        puts "  - ApprovalRequest: #{orphaned_ids.length}개"
        puts "  - ApprovalHistory: #{history_count}개"
        puts "  - ApprovalRequestStep: #{step_count}개"
      end
      
      puts "RequestForm 관련 데이터 정리가 완료되었습니다."
    end
  end
  
  def down
    puts "이 마이그레이션은 되돌릴 수 없습니다 (데이터 삭제 작업)."
  end
end
