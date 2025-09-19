class RemoveUniqueIndexFromApprovalHistories < ActiveRecord::Migration[8.0]
  def change
    # 기존 유니크 인덱스 제거
    remove_index :approval_histories, name: 'idx_unique_approval_history', if_exists: true
    
    # 일반 인덱스로 재생성 (검색 성능을 위해)
    add_index :approval_histories, [:approval_request_id, :approver_id, :step_order], 
              name: 'idx_approval_history_composite'
  end
end
