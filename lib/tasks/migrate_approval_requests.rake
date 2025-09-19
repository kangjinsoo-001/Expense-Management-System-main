namespace :approval do
  desc "기존 ApprovalRequest 데이터를 새로운 구조로 마이그레이션"
  task migrate_to_snapshot: :environment do
    puts "기존 승인 요청 데이터 마이그레이션 시작..."
    
    migrated_count = 0
    error_count = 0
    
    ApprovalRequest.includes(:approval_line => :approval_line_steps).find_each do |request|
      begin
        # 이미 마이그레이션된 경우 스킵
        if request.approval_request_steps.exists?
          puts "  - ApprovalRequest ##{request.id}는 이미 마이그레이션됨"
          next
        end
        
        # approval_line이 없는 경우 스킵
        unless request.approval_line
          puts "  - ApprovalRequest ##{request.id}는 결재선이 없음 (스킵)"
          next
        end
        
        ActiveRecord::Base.transaction do
          # 결재선 이름 저장
          request.update_column(:approval_line_name, request.approval_line.name)
          
          # 결재선 스텝 복제
          request.approval_line.approval_line_steps.each do |line_step|
            request.approval_request_steps.create!(
              approver_id: line_step.approver_id,
              step_order: line_step.step_order,
              role: line_step.role,
              approval_type: line_step.approval_type,
              status: 'pending'
            )
          end
          
          # JSON 데이터로도 저장 (백업용)
          steps_data = request.approval_line.approval_line_steps.map do |step|
            {
              approver_id: step.approver_id,
              approver_name: step.approver.name,
              step_order: step.step_order,
              role: step.role,
              approval_type: step.approval_type
            }
          end
          request.update_column(:approval_steps_data, steps_data)
          
          puts "  ✓ ApprovalRequest ##{request.id} 마이그레이션 완료"
          migrated_count += 1
        end
      rescue => e
        puts "  ✗ ApprovalRequest ##{request.id} 마이그레이션 실패: #{e.message}"
        error_count += 1
      end
    end
    
    puts "\n마이그레이션 완료!"
    puts "  - 성공: #{migrated_count}건"
    puts "  - 실패: #{error_count}건"
    
    if error_count > 0
      puts "\n실패한 항목이 있습니다. 로그를 확인해주세요."
    end
  end
  
  desc "마이그레이션 상태 확인"
  task check_migration_status: :environment do
    total = ApprovalRequest.count
    migrated = ApprovalRequest.joins(:approval_request_steps).distinct.count
    not_migrated = total - migrated
    
    puts "승인 요청 마이그레이션 상태:"
    puts "  - 전체: #{total}건"
    puts "  - 마이그레이션 완료: #{migrated}건"
    puts "  - 마이그레이션 필요: #{not_migrated}건"
    
    if not_migrated > 0
      puts "\n마이그레이션이 필요한 승인 요청 ID:"
      ApprovalRequest.left_joins(:approval_request_steps)
                    .where(approval_request_steps: { id: nil })
                    .pluck(:id)
                    .each { |id| puts "  - #{id}" }
    end
  end
end