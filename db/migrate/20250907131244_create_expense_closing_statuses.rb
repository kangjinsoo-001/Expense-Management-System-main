class CreateExpenseClosingStatuses < ActiveRecord::Migration[8.0]
  def change
    create_table :expense_closing_statuses do |t|
      t.references :user, null: false, foreign_key: true
      t.references :organization, null: false, foreign_key: true
      t.integer :year, null: false
      t.integer :month, null: false
      t.integer :status, null: false, default: 0
      t.datetime :closed_at
      t.references :closed_by, null: true, foreign_key: { to_table: :users }
      t.text :notes
      t.decimal :total_amount, precision: 12, scale: 2, default: 0
      t.integer :item_count, default: 0
      t.integer :expense_sheet_id

      t.timestamps
    end

    # 복합 인덱스: 사용자-연월 조합은 유니크해야 함
    add_index :expense_closing_statuses, [:user_id, :year, :month], unique: true, name: 'idx_expense_closing_user_year_month'
    # 조직-연월 조회용 인덱스
    add_index :expense_closing_statuses, [:organization_id, :year, :month], name: 'idx_expense_closing_org_year_month'
    # 상태별 조회용 인덱스
    add_index :expense_closing_statuses, :status
    # 경비 시트 참조
    add_index :expense_closing_statuses, :expense_sheet_id
  end
end
