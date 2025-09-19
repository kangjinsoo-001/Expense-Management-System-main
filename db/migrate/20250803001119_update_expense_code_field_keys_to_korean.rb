class UpdateExpenseCodeFieldKeysToKorean < ActiveRecord::Migration[8.0]
  def up
    ExpenseCode.find_each do |expense_code|
      # 수식의 영어 필드명을 한글로 변경
      if expense_code.limit_amount.present?
        new_limit = expense_code.limit_amount.gsub('#participants', '#구성원')
        expense_code.update_column(:limit_amount, new_limit)
      end
      
      # validation_rules의 필드 키를 한글로 변경
      if expense_code.validation_rules.present? && expense_code.validation_rules['required_fields'].is_a?(Hash)
        new_required_fields = {}
        
        expense_code.validation_rules['required_fields'].each do |key, config|
          # 필드 키를 레이블과 동일하게 변경
          label = config['label'] || key
          new_required_fields[label] = config
          
          # 영어 키 제거하고 한글로 통일
          case key
          when 'participants'
            new_required_fields['구성원'] = config
          when 'overtime_reason'
            new_required_fields['사유'] = config
          when 'travel_reason'
            new_required_fields['이동사유'] = config
          when 'departure'
            new_required_fields['출발지'] = config
          when 'destination'
            new_required_fields['도착지'] = config
          when 'distance'
            new_required_fields['거리km'] = config
          when 'transportation'
            new_required_fields['이동수단'] = config
          when 'book_name'
            new_required_fields['사용내용'] = config
          when 'purchase_purpose'
            new_required_fields['사용목적'] = config.merge('label' => '사용목적')
          when 'item_name'
            new_required_fields['품목'] = config
          when 'dinner_reason'
            new_required_fields['사유'] = config
          when 'entertainment_purpose'
            new_required_fields['사유'] = config
          when 'details'
            new_required_fields['내역'] = config
          when 'usage_purpose'
            new_required_fields['사유'] = config
          else
            new_required_fields[label] = config
          end
        end
        
        expense_code.update_column(:validation_rules, expense_code.validation_rules.merge('required_fields' => new_required_fields))
      end
    end
  end
  
  def down
    # 복원은 지원하지 않음 (데이터 손실 방지)
    raise ActiveRecord::IrreversibleMigration
  end
end
