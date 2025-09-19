class ReportExportJob < ApplicationJob
  queue_as :reports

  def perform(report_export_id)
    report_export = ReportExport.find(report_export_id)
    
    # 리포트 생성
    ReportGeneratorService.new(report_export).generate
    
    # 완료 알림 (이메일 또는 알림)
    if report_export.completed?
      ReportMailer.export_completed(report_export).deliver_later
    end
  rescue ActiveRecord::RecordNotFound
    Rails.logger.error "ReportExport not found: #{report_export_id}"
  rescue => e
    Rails.logger.error "리포트 생성 실패: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")
    
    # 실패 알림
    report_export&.update!(status: 'failed') if report_export
    ReportMailer.export_failed(report_export).deliver_later if report_export
  end
end