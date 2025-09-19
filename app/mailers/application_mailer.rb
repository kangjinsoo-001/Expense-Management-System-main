class ApplicationMailer < ActionMailer::Base
  default from: "from@example.com"
  layout "mailer"
  
  # ApplicationHelper를 포함하여 format_currency 등의 헬퍼 메서드 사용 가능
  helper :application
end
