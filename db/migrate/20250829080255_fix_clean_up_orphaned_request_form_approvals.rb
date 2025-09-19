class FixCleanUpOrphanedRequestFormApprovals < ActiveRecord::Migration[8.0]
  def up
    ActiveRecord::Base.transaction do
      # RequestForm이 삭제되었지만 ApprovalRequest가 남아있는 고아 레코드 찾기
      # approvable_type이 'RequestForm'이면서 해당 RequestForm이 존재하지 않는 경우
      orphaned_requests = ApprovalRequest
        .where(approvable_type: 'RequestForm')
        .where.not(approvable_id: RequestForm.select(:id))
      
      puts "="*60
      puts "RequestForm이 삭제된 고아 ApprovalRequest 찾기"
      puts "="*60
      puts "고아 ApprovalRequest 수: #{orphaned_requests.count}"
      
      if orphaned_requests.any?
        orphaned_ids = orphaned_requests.pluck(:id)
        
        # 상세 정보 출력
        puts "\n삭제할 ApprovalRequest ID들: #{orphaned_ids.join(', ')}"
        
        # 관련 레코드 카운트
        history_count = ApprovalHistory.where(approval_request_id: orphaned_ids).count
        step_count = ApprovalRequestStep.where(approval_request_id: orphaned_ids).count
        
        puts "\n관련 레코드 수:"
        puts "  - ApprovalHistory: #{history_count}개"
        puts "  - ApprovalRequestStep: #{step_count}개"
        
        # 관련 데이터 삭제
        ApprovalHistory.where(approval_request_id: orphaned_ids).destroy_all
        ApprovalRequestStep.where(approval_request_id: orphaned_ids).destroy_all
        orphaned_requests.destroy_all
        
        puts "\n삭제 완료:"
        puts "  - ApprovalRequest: #{orphaned_ids.length}개 삭제"
        puts "  - ApprovalHistory: #{history_count}개 삭제"
        puts "  - ApprovalRequestStep: #{step_count}개 삭제"
      else
        puts "고아 레코드가 없습니다."
      end
      
      puts "\nRequestForm 고아 레코드 정리가 완료되었습니다."
      puts "="*60
    end
  end
  
  def down
    puts "이 마이그레이션은 되돌릴 수 없습니다 (데이터 삭제 작업)."
  end
end
