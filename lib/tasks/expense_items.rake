namespace :expense_items do
  desc "기존 경비 항목들의 generated_description 필드를 업데이트"
  task update_generated_descriptions: :environment do
    puts "경비 항목의 generated_description 업데이트 시작..."
    
    updated_count = 0
    skipped_count = 0
    
    ExpenseItem.includes(:expense_code, :cost_center).find_each do |item|
      # 이미 직접 입력한 설명이 있으면 건너뛰기
      if item.description.present?
        skipped_count += 1
        next
      end
      
      # 템플릿이 없으면 건너뛰기
      unless item.expense_code&.description_template.present?
        skipped_count += 1
        next
      end
      
      # generated_description 생성 및 저장
      item.send(:generate_and_save_description)
      if item.save(validate: false)
        updated_count += 1
        puts "  [#{updated_count}] ExpenseItem ##{item.id} 업데이트 완료: #{item.generated_description}"
      else
        puts "  [오류] ExpenseItem ##{item.id} 업데이트 실패"
      end
    end
    
    puts "\n완료!"
    puts "- 업데이트된 항목: #{updated_count}개"
    puts "- 건너뛴 항목: #{skipped_count}개"
  end
end