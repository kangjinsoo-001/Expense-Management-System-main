require "test_helper"

class ApplicationJobTest < ActiveSupport::TestCase
  test "should have proper queue adapter configured" do
    assert_equal "test", ActiveJob::Base.queue_adapter_name.to_s
  end
  
  test "ApplicationJob exists and can be instantiated" do
    assert_nothing_raised do
      ApplicationJob.new
    end
  end
  
  test "ApplicationJob inherits from ActiveJob::Base" do
    assert ApplicationJob < ActiveJob::Base
  end
end