require 'test_helper'

module ExpenseValidation
  class ConditionParserTest < ActiveSupport::TestCase
    
    test "숫자 비교 조건 파싱" do
      parser = ConditionParser.new("#금액 > 300000")
      assert parser.valid?
      
      assert parser.evaluate(금액: 400000)
      assert_not parser.evaluate(금액: 200000)
    end
    
    test "다양한 연산자 지원" do
      # 초과
      parser = ConditionParser.new("#금액 > 100")
      assert parser.evaluate(금액: 150)
      assert_not parser.evaluate(금액: 50)
      
      # 미만
      parser = ConditionParser.new("#금액 < 100")
      assert parser.evaluate(금액: 50)
      assert_not parser.evaluate(금액: 150)
      
      # 이상
      parser = ConditionParser.new("#금액 >= 100")
      assert parser.evaluate(금액: 100)
      assert parser.evaluate(금액: 150)
      assert_not parser.evaluate(금액: 50)
      
      # 이하
      parser = ConditionParser.new("#금액 <= 100")
      assert parser.evaluate(금액: 100)
      assert parser.evaluate(금액: 50)
      assert_not parser.evaluate(금액: 150)
      
      # 같음
      parser = ConditionParser.new("#금액 == 100")
      assert parser.evaluate(금액: 100)
      assert_not parser.evaluate(금액: 150)
      
      # 다름
      parser = ConditionParser.new("#금액 != 100")
      assert parser.evaluate(금액: 150)
      assert_not parser.evaluate(금액: 100)
    end
    
    test "expense_item 객체로 평가" do
      item = ExpenseItem.new(amount: 500000)
      
      parser = ConditionParser.new("#금액 > 300000")
      assert parser.evaluate(expense_item: item)
      
      parser = ConditionParser.new("#금액 <= 300000")
      assert_not parser.evaluate(expense_item: item)
    end
    
    test "커스텀 필드 평가" do
      item = ExpenseItem.new
      item.custom_fields = { "참석인원" => "15" }
      
      parser = ConditionParser.new("#참석인원 > 10")
      assert parser.evaluate(expense_item: item)
      
      parser = ConditionParser.new("#참석인원 <= 10")
      assert_not parser.evaluate(expense_item: item)
    end
    
    test "필드 목록 추출" do
      parser = ConditionParser.new("#금액 > 300000")
      assert_equal ["금액"], parser.required_fields
      
      parser = ConditionParser.new("#참석인원 > 10")
      assert_equal ["참석인원"], parser.required_fields
    end
    
    test "잘못된 조건식 처리" do
      parser = ConditionParser.new("invalid condition")
      assert_not parser.valid?
      
      # 평가 시 false 반환
      assert_not parser.evaluate(금액: 100)
    end
    
    test "빈 조건식 처리" do
      parser = ConditionParser.new("")
      assert parser.valid?
      assert parser.evaluate(금액: 100)  # 빈 조건은 항상 true
      
      parser = ConditionParser.new(nil)
      assert parser.valid?
      assert parser.evaluate(금액: 100)  # nil 조건도 항상 true
    end
    
    test "타입 변환" do
      # 문자열 숫자를 숫자로 변환
      parser = ConditionParser.new("#금액 > 100")
      assert parser.evaluate(금액: "150")
      assert_not parser.evaluate(금액: "50")
      
      # 소수점 지원
      parser = ConditionParser.new("#금액 > 100.5")
      assert parser.evaluate(금액: 100.6)
      assert_not parser.evaluate(금액: 100.4)
    end
  end
end