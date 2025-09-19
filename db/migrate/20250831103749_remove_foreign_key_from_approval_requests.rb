class RemoveForeignKeyFromApprovalRequests < ActiveRecord::Migration[8.0]
  def change
    # Foreign key 제약 제거 - 결재선은 템플릿이므로 삭제 가능해야 함
    remove_foreign_key :approval_requests, :approval_lines
    
    # approval_line_id는 참조용으로만 유지 (실제 데이터는 복제되어 저장됨)
    # 이미 nullable이므로 추가 변경 불필요
  end
end
