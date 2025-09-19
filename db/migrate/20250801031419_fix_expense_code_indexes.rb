class FixExpenseCodeIndexes < ActiveRecord::Migration[8.0]
  def change
    # code의 unique 제약을 제거하고 code + version의 unique 제약만 유지
    remove_index :expense_codes, :code
    
    # code에 대한 일반 인덱스 추가 (검색 성능을 위해)
    add_index :expense_codes, :code
  end
end
