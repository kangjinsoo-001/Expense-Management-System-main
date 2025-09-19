require "test_helper"

class ApprovalLinesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = users(:one)
    @other_user = users(:two)
    @approval_line = approval_lines(:one)
    sign_in @user
  end
  
  # Index 테스트
  test "should get index" do
    get approval_lines_url
    assert_response :success
    assert_select "h1", "결재선 관리"
  end
  
  test "index should only show current user approval lines" do
    get approval_lines_url
    
    assert_match @approval_line.name, response.body
    # 다른 사용자의 결재선은 표시되지 않아야 함
    assert_no_match approval_lines(:two).name, response.body
  end
  
  # Show 테스트
  test "should show approval line" do
    get approval_line_url(@approval_line)
    assert_response :success
    assert_match @approval_line.name, response.body
  end
  
  test "should not show other user approval line" do
    other_line = approval_lines(:two)
    
    assert_raises(ActiveRecord::RecordNotFound) do
      get approval_line_url(other_line)
    end
  end
  
  # New 테스트
  test "should get new" do
    get new_approval_line_url
    assert_response :success
    assert_select "h1", "새 결재선 만들기"
  end
  
  # Create 테스트
  test "should create approval line" do
    assert_difference("ApprovalLine.count", 1) do
      post approval_lines_url, params: {
        approval_line: {
          name: "새 결재선",
          is_active: true,
          approval_line_steps_attributes: {
            "0" => {
              approver_id: users(:two).id,
              step_order: 1,
              role: "approve"
            }
          }
        }
      }
    end
    
    assert_redirected_to approval_line_url(ApprovalLine.last)
    follow_redirect!
    assert_match "결재선이 생성되었습니다", response.body
  end
  
  test "should not create approval line with invalid params" do
    assert_no_difference("ApprovalLine.count") do
      post approval_lines_url, params: {
        approval_line: {
          name: "", # 빈 이름
          is_active: true
        }
      }
    end
    
    assert_response :unprocessable_entity
    assert_select "div.error_explanation"
  end
  
  test "should create approval line with multiple steps" do
    assert_difference("ApprovalLine.count", 1) do
      assert_difference("ApprovalLineStep.count", 3) do
        post approval_lines_url, params: {
          approval_line: {
            name: "다단계 결재선",
            is_active: true,
            approval_line_steps_attributes: {
              "0" => {
                approver_id: users(:two).id,
                step_order: 1,
                role: "approve"
              },
              "1" => {
                approver_id: users(:three).id,
                step_order: 2,
                role: "approve"
              },
              "2" => {
                approver_id: users(:one).id,
                step_order: 3,
                role: "reference"
              }
            }
          }
        }
      end
    end
    
    approval_line = ApprovalLine.last
    assert_equal 3, approval_line.approval_line_steps.count
    assert_equal [1, 2, 3], approval_line.approval_line_steps.pluck(:step_order).sort
  end
  
  # Edit 테스트
  test "should get edit" do
    get edit_approval_line_url(@approval_line)
    assert_response :success
    assert_select "h1", "결재선 수정"
  end
  
  test "should not edit other user approval line" do
    other_line = approval_lines(:two)
    
    assert_raises(ActiveRecord::RecordNotFound) do
      get edit_approval_line_url(other_line)
    end
  end
  
  # Update 테스트
  test "should update approval line" do
    patch approval_line_url(@approval_line), params: {
      approval_line: {
        name: "수정된 결재선",
        is_active: false
      }
    }
    
    assert_redirected_to approval_line_url(@approval_line)
    follow_redirect!
    assert_match "결재선이 수정되었습니다", response.body
    
    @approval_line.reload
    assert_equal "수정된 결재선", @approval_line.name
    assert_not @approval_line.is_active
  end
  
  test "should not update approval line with invalid params" do
    original_name = @approval_line.name
    
    patch approval_line_url(@approval_line), params: {
      approval_line: {
        name: "" # 빈 이름
      }
    }
    
    assert_response :unprocessable_entity
    @approval_line.reload
    assert_equal original_name, @approval_line.name
  end
  
  test "should not update other user approval line" do
    other_line = approval_lines(:two)
    
    assert_raises(ActiveRecord::RecordNotFound) do
      patch approval_line_url(other_line), params: {
        approval_line: { name: "해킹 시도" }
      }
    end
  end
  
  # Destroy 테스트
  test "should destroy approval line without requests" do
    # 승인 요청이 없는 결재선 생성
    deletable_line = @user.approval_lines.create!(
      name: "삭제 가능한 결재선",
      is_active: true
    )
    
    assert_difference("ApprovalLine.count", -1) do
      delete approval_line_url(deletable_line)
    end
    
    assert_redirected_to approval_lines_url
    follow_redirect!
    assert_match "결재선이 삭제되었습니다", response.body
  end
  
  test "should not destroy approval line with requests" do
    # 승인 요청이 있는 결재선 (fixtures에서 설정됨)
    line_with_requests = approval_lines(:with_requests)
    sign_in line_with_requests.user
    
    assert_no_difference("ApprovalLine.count") do
      delete approval_line_url(line_with_requests)
    end
    
    assert_redirected_to approval_lines_url
    follow_redirect!
    assert_match "승인 요청이 있는 결재선은 삭제할 수 없습니다", response.body
  end
  
  test "should not destroy other user approval line" do
    other_line = approval_lines(:two)
    
    assert_raises(ActiveRecord::RecordNotFound) do
      delete approval_line_url(other_line)
    end
  end
  
  # Turbo Stream 응답 테스트
  test "should respond with turbo stream on create" do
    post approval_lines_url, params: {
      approval_line: {
        name: "Turbo 테스트 결재선",
        is_active: true
      }
    }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
    
    assert_match "turbo-stream", response.content_type
  end
  
  test "should respond with turbo stream on update" do
    patch approval_line_url(@approval_line), params: {
      approval_line: {
        name: "Turbo 업데이트"
      }
    }, headers: { "Accept" => "text/vnd.turbo-stream.html" }
    
    assert_match "turbo-stream", response.content_type
  end
  
  test "should respond with turbo stream on destroy" do
    deletable_line = @user.approval_lines.create!(
      name: "삭제용 결재선",
      is_active: true
    )
    
    delete approval_line_url(deletable_line), 
           headers: { "Accept" => "text/vnd.turbo-stream.html" }
    
    assert_match "turbo-stream", response.content_type
  end
  
  # 권한 없는 접근 테스트
  test "should redirect to login when not authenticated" do
    sign_out @user
    
    get approval_lines_url
    assert_redirected_to new_user_session_url
    
    get new_approval_line_url
    assert_redirected_to new_user_session_url
    
    post approval_lines_url, params: { approval_line: { name: "Test" } }
    assert_redirected_to new_user_session_url
  end
  
  # AJAX 요청 테스트
  test "should handle step reordering via AJAX" do
    step1 = @approval_line.approval_line_steps.create!(
      approver: users(:two),
      step_order: 1,
      role: "approve"
    )
    step2 = @approval_line.approval_line_steps.create!(
      approver: users(:three),
      step_order: 2,
      role: "approve"
    )
    
    # 순서 변경 요청 (컨트롤러에 해당 액션이 있다고 가정)
    patch reorder_approval_line_url(@approval_line), params: {
      steps: [
        { id: step2.id, step_order: 1 },
        { id: step1.id, step_order: 2 }
      ]
    }, as: :json
    
    assert_response :success
    
    step1.reload
    step2.reload
    assert_equal 2, step1.step_order
    assert_equal 1, step2.step_order
  end
end