class AddDisplayOrderToExpenseCodes < ActiveRecord::Migration[8.0]
  def change
    add_column :expense_codes, :display_order, :integer, default: 0
    add_index :expense_codes, :display_order
    
    # 기존 데이터에 display_order 값 설정
    reversible do |dir|
      dir.up do
        execute <<-SQL
          UPDATE expense_codes 
          SET display_order = id * 10
          WHERE display_order IS NULL OR display_order = 0
        SQL
      end
    end
  end
end
