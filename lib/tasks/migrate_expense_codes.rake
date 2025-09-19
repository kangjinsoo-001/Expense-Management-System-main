namespace :expense_codes do
  desc "경비 코드 validation_rules를 새로운 형식으로 마이그레이션"
  task migrate_validation_rules: :environment do
    puts "경비 코드 validation_rules 마이그레이션 시작..."
    
    migrated_count = 0
    skipped_count = 0
    
    ExpenseCode.find_each do |expense_code|
      if expense_code.validation_rules.present? && expense_code.validation_rules['required_fields'].is_a?(Array)
        old_fields = expense_code.validation_rules['required_fields']
        
        # 새로운 Hash 구조로 변환
        new_required_fields = {}
        
        old_fields.each_with_index do |field_name, index|
          # 필드 타입 추론
          field_type = case field_name
                      when /시간|일자|날짜/
                        'text'
                      when /인원|명수|수량/
                        'number'
                      when /참석자|구성원|직원/
                        'participants'
                      when /조직|부서|팀/
                        'organization'
                      when /승인|상태|결과/
                        'select'
                      else
                        'text'
                      end
          
          # 필드 키 생성 (영문 변환)
          field_key = case field_name
                     when '참석자명', '참석자'
                       'participants'
                     when '근무시간'
                       'working_hours'
                     when '출발지'
                       'departure'
                     when '도착지'
                       'destination'
                     when '이동사유'
                       'travel_reason'
                     when '방문처'
                       'visit_location'
                     when '미팅목적', '목적'
                       'meeting_purpose'
                     when '교육명'
                       'training_name'
                     when '교육기관'
                       'training_institution'
                     else
                       "field_#{index + 1}"
                     end
          
          new_required_fields[field_key] = {
            'label' => field_name,
            'type' => field_type,
            'required' => true,
            'order' => index + 1
          }
        end
        
        # 업데이트
        expense_code.update_column(:validation_rules, {
          'required_fields' => new_required_fields
        })
        
        puts "✓ #{expense_code.code} - #{expense_code.name}: #{old_fields.size}개 필드 마이그레이션 완료"
        migrated_count += 1
      else
        puts "- #{expense_code.code} - #{expense_code.name}: 이미 새로운 형식이거나 필드가 없음"
        skipped_count += 1
      end
    end
    
    puts "\n마이그레이션 완료!"
    puts "마이그레이션됨: #{migrated_count}개"
    puts "건너뜀: #{skipped_count}개"
    puts "총: #{ExpenseCode.count}개"
  end
  
  desc "경비 코드 validation_rules 상태 확인"
  task check_validation_rules: :environment do
    puts "경비 코드 validation_rules 현재 상태:"
    puts "=" * 80
    
    ExpenseCode.find_each do |expense_code|
      puts "\n#{expense_code.code} - #{expense_code.name}:"
      
      if expense_code.validation_rules.blank?
        puts "  필수 필드 없음"
      elsif expense_code.validation_rules['required_fields'].is_a?(Array)
        puts "  [구형식] 배열 타입:"
        expense_code.validation_rules['required_fields'].each do |field|
          puts "    - #{field}"
        end
      elsif expense_code.validation_rules['required_fields'].is_a?(Hash)
        puts "  [신형식] Hash 타입:"
        expense_code.validation_rules['required_fields'].each do |key, config|
          puts "    - #{key}: #{config['label']} (#{config['type']}, 순서: #{config['order']})"
        end
      end
    end
    
    puts "\n" + "=" * 80
  end
  
  desc "participants 타입을 '참석자'에서 '구성원'으로 업데이트"
  task update_participants_label: :environment do
    puts "participants 타입 라벨 업데이트 시작..."
    
    updated_count = 0
    
    ExpenseCode.find_each do |expense_code|
      if expense_code.validation_rules.present? && expense_code.validation_rules['required_fields'].is_a?(Hash)
        updated = false
        
        expense_code.validation_rules['required_fields'].each do |key, field_config|
          # participants 타입인데 라벨이 '참석자' 관련인 경우 업데이트
          if field_config['type'] == 'participants' && field_config['label'] =~ /참석자/
            old_label = field_config['label']
            new_label = field_config['label'].gsub('참석자', '구성원')
            field_config['label'] = new_label
            updated = true
            puts "  #{expense_code.code}: '#{old_label}' → '#{new_label}'"
          end
        end
        
        if updated
          expense_code.update_column(:validation_rules, expense_code.validation_rules)
          updated_count += 1
        end
      end
    end
    
    puts "\n업데이트 완료!"
    puts "업데이트된 경비 코드: #{updated_count}개"
  end
end