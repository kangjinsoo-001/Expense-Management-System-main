class AddApprovalLineDataToApprovalRequests < ActiveRecord::Migration[8.0]
  def change
    # approval_requests 테이블에 결재선 정보 저장을 위한 컬럼 추가
    add_column :approval_requests, :approval_line_name, :string
    add_column :approval_requests, :approval_steps_data, :json, default: []
    
    # 기존 approval_line_id는 nullable로 변경 (나중에 제거 예정)
    change_column_null :approval_requests, :approval_line_id, true
    
    # 승인 스텝 정보를 저장할 새로운 테이블 생성
    create_table :approval_request_steps do |t|
      t.references :approval_request, null: false, foreign_key: true
      t.references :approver, null: false, foreign_key: { to_table: :users }
      t.integer :step_order, null: false
      t.string :role, null: false, default: 'approve'
      t.string :approval_type
      t.string :status, default: 'pending'
      t.text :comment
      t.datetime :actioned_at
      
      t.timestamps
    end
    
    add_index :approval_request_steps, [:approval_request_id, :step_order], name: 'idx_approval_request_steps_on_request_and_order'
    add_index :approval_request_steps, :status
  end
end
