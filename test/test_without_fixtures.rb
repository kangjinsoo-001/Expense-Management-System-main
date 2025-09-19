# fixture를 사용하지 않는 테스트용 헬퍼
ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"
require "minitest/autorun"

# Test 환경 초기화
ActiveRecord::Base.transaction do
  # 모든 데이터 삭제
  ActiveRecord::Base.connection.tables.each do |table|
    next if table == 'schema_migrations' || table == 'ar_internal_metadata'
    ActiveRecord::Base.connection.execute("DELETE FROM #{table}")
  end
end

class ActiveSupport::TestCase
  # fixtures 비활성화
  self.use_transactional_tests = true
  
  # 각 테스트 전 데이터베이스 초기화
  setup do
    ActiveRecord::Base.connection.tables.each do |table|
      next if table == 'schema_migrations' || table == 'ar_internal_metadata'
      ActiveRecord::Base.connection.execute("DELETE FROM #{table}")
    end
  end
end