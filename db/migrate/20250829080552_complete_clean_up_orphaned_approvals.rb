class CompleteCleanUpOrphanedApprovals < ActiveRecord::Migration[8.0]
  def up
    ActiveRecord::Base.transaction do
      puts "="*80
      puts "완전한 고아 ApprovalRequest 정리"
      puts "실행 시간: #{Time.current}"
      puts "="*80
      
      all_orphan_ids = []
      
      # 1. expense_item_id를 사용하는 고아 레코드 (레거시 방식)
      puts "\n[1] expense_item_id 기반 고아 레코드 확인..."
      
      # LEFT JOIN으로 expense_item이 없는 경우 찾기
      orphaned_by_expense_item = ApprovalRequest
        .where.not(expense_item_id: nil)
        .left_joins(:expense_item)
        .where(expense_items: { id: nil })
      
      count1 = orphaned_by_expense_item.count
      puts "  expense_item_id가 있지만 ExpenseItem이 없는 경우: #{count1}개"
      
      if count1 > 0
        ids = orphaned_by_expense_item.pluck(:id)
        all_orphan_ids.concat(ids)
        puts "  IDs: #{ids.join(', ')}"
      end
      
      # 2. Polymorphic ExpenseItem 고아 레코드
      puts "\n[2] Polymorphic ExpenseItem 고아 레코드 확인..."
      
      orphaned_polymorphic = ApprovalRequest
        .where(approvable_type: 'ExpenseItem')
        .where.not(approvable_id: ExpenseItem.select(:id))
      
      count2 = orphaned_polymorphic.count
      puts "  Polymorphic ExpenseItem 고아: #{count2}개"
      
      if count2 > 0
        ids = orphaned_polymorphic.pluck(:id)
        all_orphan_ids.concat(ids)
        puts "  IDs: #{ids.join(', ')}"
      end
      
      # 3. RequestForm 고아 레코드
      puts "\n[3] RequestForm 고아 레코드 확인..."
      
      orphaned_request_forms = ApprovalRequest
        .where(approvable_type: 'RequestForm')
        .where.not(approvable_id: RequestForm.select(:id))
      
      count3 = orphaned_request_forms.count
      puts "  RequestForm 고아: #{count3}개"
      
      if count3 > 0
        ids = orphaned_request_forms.pluck(:id)
        all_orphan_ids.concat(ids)
        puts "  IDs: #{ids.join(', ')}"
      end
      
      # 4. 고아 레코드 삭제
      all_orphan_ids.uniq!
      
      if all_orphan_ids.any?
        puts "\n[4] 관련 데이터 삭제 중..."
        
        # ApprovalHistory 삭제
        history_count = ApprovalHistory.where(approval_request_id: all_orphan_ids).count
        ApprovalHistory.where(approval_request_id: all_orphan_ids).delete_all
        puts "  ApprovalHistory: #{history_count}개 삭제"
        
        # ApprovalRequestStep 삭제
        step_count = ApprovalRequestStep.where(approval_request_id: all_orphan_ids).count
        ApprovalRequestStep.where(approval_request_id: all_orphan_ids).delete_all
        puts "  ApprovalRequestStep: #{step_count}개 삭제"
        
        # ApprovalRequest 삭제
        ApprovalRequest.where(id: all_orphan_ids).delete_all
        puts "  ApprovalRequest: #{all_orphan_ids.length}개 삭제"
        
        puts "\n" + "="*80
        puts "✅ 정리 완료!"
        puts "="*80
        puts "삭제 요약:"
        puts "  - expense_item_id 기반 고아: #{count1}개"
        puts "  - Polymorphic ExpenseItem 고아: #{count2}개"
        puts "  - RequestForm 고아: #{count3}개"
        puts "  - 총 ApprovalRequest 삭제: #{all_orphan_ids.length}개"
      else
        puts "\n✅ 고아 레코드가 없습니다."
      end
      
      puts "="*80
    end
  end
  
  def down
    puts "이 마이그레이션은 되돌릴 수 없습니다 (데이터 삭제 작업)."
  end
end
