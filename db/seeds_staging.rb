# 스테이징 환경용 시드 데이터 로드
# 경비 신청 내역 없이 기본 데이터만 로드
puts "Loading STAGING seed data..."
puts "=" * 50

# 프로덕션 환경에서만 실행 (스테이징은 production 모드로 실행)
if Rails.env.production?
  # 시드 로드 플래그 설정
  ENV['SEEDING'] = 'true'
  
  # 기존 데이터 정리 (순서 중요 - 종속성 역순)
  puts "Cleaning existing data..."
  
  # 콜백 비활성화하여 정리
  ApprovalLineStep.skip_callback(:destroy, :after, :reorder_subsequent_steps)
  
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
  
  # 스테이징용 시드 파일들만 로드 (경비 신청 데이터 제외)
  staging_seeds = [
    '001_organizations.rb',    # 조직 구조
    '002_users.rb',            # 사용자
    '003_approver_groups.rb',  # 승인자 그룹
    '004_cost_centers.rb',     # 코스트 센터
    '006_expense_codes.rb'     # 경비 코드
    # 005_approval_lines.rb 제외 (결재선은 사용자가 직접 설정)
    # 007_approval_sample_data.rb 제외 (경비 신청 샘플 데이터)
    # 008_sample_expense_data.rb 제외 (경비 신청 샘플 데이터)
  ]
  
  staging_seeds.each do |seed_file|
    file_path = Rails.root.join('db/seeds', seed_file)
    if File.exist?(file_path)
      puts "\nLoading #{seed_file}..."
      load file_path
    else
      puts "\nWarning: #{seed_file} not found, skipping..."
    end
  end
  
  puts "\n" + "=" * 50
  puts "STAGING seed data loaded successfully!"
  puts "=" * 50
  
  # 생성된 데이터 요약
  puts "\nData Summary (Staging):"
  puts "- Organizations: #{Organization.count}"
  puts "- Users: #{User.count}"
  puts "- Expense Codes: #{ExpenseCode.count}"
  puts "- Cost Centers: #{CostCenter.count}"
  puts "- Approver Groups: #{ApproverGroup.count}"
  puts "- Approval Lines: #{ApprovalLine.count}"
  puts "- Expense Sheets: #{ExpenseSheet.count} (should be 0)"
  puts "- Expense Items: #{ExpenseItem.count} (should be 0)"
  
  puts "\nSample login credentials:"
  puts "- 대표이사: jaypark@tlx.kr / hcghcghcg"
  puts "- CPO: sabaek@tlx.kr / hcghcghcg"  
  puts "- hunel COO: ymkim@tlx.kr / hcghcghcg"
  puts "- Admin: hjlee@tlx.kr / hcghcghcg"
  puts "- talenx BU 직원: jjbaek@tlx.kr / hcghcghcg"
  
  puts "\n스테이징 환경 초기 데이터 로드 완료!"
  puts "경비 신청 내역은 실제 테스트를 통해 생성하세요."
  
  # 시드 로드 플래그 제거
  ENV.delete('SEEDING')
else
  puts "This seed file is for staging environment only (production mode)."
  puts "Use 'rails db:seed' for development environment."
end