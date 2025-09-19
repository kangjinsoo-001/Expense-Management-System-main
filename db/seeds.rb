# 시드 데이터 로드
puts "Loading seed data..."
puts "=" * 50

# 개발 환경에서만 전체 시드 데이터 로드
# 스테이징(production)은 seeds_staging.rb 사용
if Rails.env.development?
  # 시드 로드 플래그 설정
  ENV['SEEDING'] = 'true'
  
  # 기존 데이터 정리 (순서 중요 - 종속성 역순)
  puts "Cleaning existing data..."
  
  # 콜백 비활성화하여 정리
  ApprovalLineStep.skip_callback(:destroy, :after, :reorder_subsequent_steps)
  
  # SQLite 외래 키 제약 일시 비활성화
  ActiveRecord::Base.connection.execute('PRAGMA foreign_keys = OFF')
  
  # 신청서 관련 데이터 삭제 (역순으로 삭제)
  if defined?(RequestFormAttachment)
    RequestFormAttachment.destroy_all
  end
  if defined?(RequestForm)
    RequestForm.destroy_all
  end
  if defined?(RequestTemplateField)
    RequestTemplateField.destroy_all
  end
  if defined?(RequestTemplateApprovalRule)
    RequestTemplateApprovalRule.destroy_all
  end
  if defined?(RequestTemplate)
    RequestTemplate.destroy_all
  end
  if defined?(RequestCategory)
    RequestCategory.destroy_all
  end
  
  # 첨부파일 관련 데이터 삭제
  ExpenseAttachment.destroy_all if defined?(ExpenseAttachment)
  ExpenseSheetAttachment.destroy_all if defined?(ExpenseSheetAttachment)
  AttachmentValidationRule.destroy_all if defined?(AttachmentValidationRule)
  AttachmentAnalysisRule.destroy_all if defined?(AttachmentAnalysisRule)
  AttachmentRequirement.destroy_all if defined?(AttachmentRequirement)
  
  # 승인 관련 데이터 삭제
  ApprovalHistory.destroy_all
  ApprovalRequest.destroy_all
  ApprovalLineStep.destroy_all
  ApprovalLine.destroy_all
  
  # 경비 관련 데이터 삭제
  ExpenseItem.destroy_all
  ExpenseSheet.destroy_all
  
  # 경비 코드 승인 규칙 삭제
  ExpenseCodeApprovalRule.destroy_all
  
  # 승인자 그룹 관련 삭제
  ApproverGroupMember.destroy_all
  ApproverGroup.destroy_all
  
  # 경비 코드와 비용 센터 삭제
  ExpenseCode.destroy_all
  CostCenter.destroy_all
  
  # 사용자와 조직 삭제
  Organization.update_all(manager_id: nil)  # 매니저 참조 먼저 제거
  User.destroy_all
  Organization.destroy_all
  
  # 콜백 다시 활성화
  ApprovalLineStep.set_callback(:destroy, :after, :reorder_subsequent_steps)
  
  # SQLite 외래 키 제약 다시 활성화
  ActiveRecord::Base.connection.execute('PRAGMA foreign_keys = ON')
  
  # 000-199번대 시드 파일들을 순서대로 로드 (기본 설정 + 샘플 데이터)
  # 900번대 특수 목적 파일은 제외
  #
  # === 900번대 시드 파일 실행 방법 ===
  # 900번대 파일은 성능 테스트용 대량 데이터를 포함하므로 수동으로 실행해야 합니다.
  #
  # 예시:
  #   # 성능 테스트 데이터 생성 (약 180만건)
  #   ALLOW_PERFORMANCE_SEED=true rails runner "load 'db/seeds/900_performance_test_data.rb'"
  #
  # 또는 rails console에서:
  #   load Rails.root.join('db/seeds/900_performance_test_data.rb')
  #
  Dir[Rails.root.join('db/seeds/[0-1][0-9][0-9]*.rb')].sort.each do |file|
    puts "\nLoading #{File.basename(file)}..."
    load file
  end
  
  puts "\n" + "=" * 50
  puts "Seed data loaded successfully!"
  puts "=" * 50
  
  # 생성된 데이터 요약
  puts "\nData Summary:"
  puts "- Organizations: #{Organization.count}"
  puts "- Users: #{User.count}"
  puts "- Expense Codes: #{ExpenseCode.count}"
  puts "- Cost Centers: #{CostCenter.count}"
  puts "- Expense Sheets: #{ExpenseSheet.count}"
  puts "- Expense Items: #{ExpenseItem.count}"
  puts "- Approval Lines: #{ApprovalLine.count}"
  puts "- Approval Line Steps: #{ApprovalLineStep.count}"
  puts "- Approval Requests: #{ApprovalRequest.count}"
  puts "- Approval Histories: #{ApprovalHistory.count}"
  puts "- Rooms: #{Room.count}"
  puts "- Room Reservations: #{RoomReservation.count}"
  puts "- Request Categories: #{RequestCategory.count}"
  puts "- Request Templates: #{RequestTemplate.count}"
  puts "- Request Template Fields: #{RequestTemplateField.count}"
  
  puts "\nSample login credentials:"
  puts "- 대표이사: jaypark@tlx.kr / hcghcghcg"
  puts "- CPO: sabaek@tlx.kr / hcghcghcg"
  puts "- hunel COO: ymkim@tlx.kr / hcghcghcg"
  puts "- Admin: hjlee@tlx.kr / hcghcghcg"
  puts "- talenx BU 직원: jjbaek@tlx.kr / hcghcghcg"
  
  # 시드 로드 플래그 제거
  ENV.delete('SEEDING')
end