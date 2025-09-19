module ExpenseValidation
  class ConditionParser
    class ParseError < StandardError; end
    
    # 지원하는 연산자
    OPERATORS = {
      '>' => :gt,
      '<' => :lt,
      '>=' => :gte,
      '<=' => :lte,
      '==' => :eq,
      '!=' => :neq,
      '=' => :eq  # == 대신 = 도 허용
    }.freeze
    
    # 연산자 정규식
    OPERATOR_REGEX = />=|<=|==|!=|>|<|=/
    
    # 필드 정규식 (# 으로 시작)
    FIELD_REGEX = /#([a-zA-Z가-힣_0-9]+)/
    
    # 숫자 정규식
    NUMBER_REGEX = /\d+(\.\d+)?/
    
    # 문자열 정규식
    STRING_REGEX = /"([^"]*)"|'([^']*)'/
    
    def initialize(condition)
      @condition = condition.to_s.strip
      @tokens = []
      @errors = []
    end
    
    # 조건식 파싱 및 토큰화
    def parse
      return nil if @condition.blank?
      
      # 간단한 조건식 파싱 (예: #금액 > 300000)
      # 복잡한 논리 연산자는 추후 확장
      tokenize
      build_ast
    end
    
    # 조건식 평가
    def evaluate(context = {})
      ast = parse
      return true if ast.nil?
      
      evaluate_node(ast, context)
    rescue ParseError => e
      @errors << e.message
      false
    end
    
    # 조건식이 유효한지 검증
    def valid?
      parse
      true
    rescue ParseError
      false
    end
    
    # 조건식에서 사용된 필드 목록 추출
    def required_fields
      @condition.scan(FIELD_REGEX).flatten.uniq
    end
    
    private
    
    # 토큰화
    def tokenize
      remaining = @condition.dup
      
      while remaining.length > 0
        remaining = remaining.strip
        
        # 필드 토큰
        if match = remaining.match(/\A#([a-zA-Z가-힣_0-9]+)/)
          @tokens << { type: :field, value: match[1] }
          remaining = match.post_match
          
        # 연산자 토큰
        elsif match = remaining.match(/\A#{OPERATOR_REGEX}/)
          @tokens << { type: :operator, value: OPERATORS[match[0]] }
          remaining = match.post_match
          
        # 숫자 토큰
        elsif match = remaining.match(/\A#{NUMBER_REGEX}/)
          @tokens << { type: :number, value: match[0].to_f }
          remaining = match.post_match
          
        # 문자열 토큰
        elsif match = remaining.match(/\A#{STRING_REGEX}/)
          @tokens << { type: :string, value: match[1] || match[2] }
          remaining = match.post_match
          
        # 괄호 (추후 확장용)
        elsif match = remaining.match(/\A[()]/)
          @tokens << { type: match[0] == '(' ? :lparen : :rparen, value: match[0] }
          remaining = match.post_match
          
        # AND/OR 연산자 (추후 확장용)
        elsif match = remaining.match(/\A(AND|OR|&&|\|\|)/i)
          @tokens << { type: :logical, value: match[1].upcase }
          remaining = match.post_match
          
        else
          raise ParseError, "알 수 없는 토큰: #{remaining[0..10]}..."
        end
      end
      
      @tokens
    end
    
    # AST(Abstract Syntax Tree) 구성
    def build_ast
      # 현재는 단순 비교만 지원
      # 추후 복잡한 논리식 지원을 위해 확장 가능
      
      # 토큰이 없으면 nil 반환
      return nil if @tokens.empty?
      
      # 단순 비교 조건식
      if @tokens.length == 3 && 
         @tokens[0][:type] == :field && 
         @tokens[1][:type] == :operator && 
         [:number, :string].include?(@tokens[2][:type])
        
        return {
          type: :comparison,
          left: @tokens[0],
          operator: @tokens[1][:value],
          right: @tokens[2]
        }
      end
      
      # 복잡한 조건식은 추후 구현
      raise ParseError, "지원하지 않는 조건식 형식입니다: #{@condition} (토큰: #{@tokens.inspect})"
    end
    
    # AST 노드 평가
    def evaluate_node(node, context)
      case node[:type]
      when :comparison
        evaluate_comparison(node, context)
      else
        raise ParseError, "알 수 없는 노드 타입: #{node[:type]}"
      end
    end
    
    # 비교 연산 평가
    def evaluate_comparison(node, context)
      # 왼쪽 값 (필드) 가져오기
      field_name = node[:left][:value]
      left_value = get_field_value(field_name, context)
      
      # 오른쪽 값
      right_value = node[:right][:value]
      
      # 타입 변환
      left_value, right_value = coerce_values(left_value, right_value)
      
      # 연산자에 따른 비교
      case node[:operator]
      when :gt
        left_value > right_value
      when :lt
        left_value < right_value
      when :gte
        left_value >= right_value
      when :lte
        left_value <= right_value
      when :eq
        left_value == right_value
      when :neq
        left_value != right_value
      else
        raise ParseError, "지원하지 않는 연산자: #{node[:operator]}"
      end
    end
    
    # 필드 값 가져오기
    def get_field_value(field_name, context)
      # 컨텍스트에서 값 찾기
      value = nil
      
      # 1. 직접 매칭 (예: context[:금액])
      if context.key?(field_name.to_sym)
        value = context[field_name.to_sym]
      elsif context.key?(field_name)
        value = context[field_name]
      end
      
      # 2. expense_item 객체의 속성 확인
      if value.nil? && context[:expense_item]
        item = context[:expense_item]
        
        # 기본 필드
        case field_name
        when '금액', 'amount'
          # 금액이 없으면 0으로 처리
          value = item.amount || 0
        when '날짜', 'expense_date'
          value = item.expense_date
        when '설명', 'description'
          value = item.description
        else
          # 커스텀 필드 확인
          if item.custom_fields.present?
            value = item.custom_fields[field_name]
          end
        end
      end
      
      # 3. 직접 전달된 값
      if value.nil? && context[:values]
        value = context[:values][field_name] || context[:values][field_name.to_sym]
      end
      
      value
    end
    
    # 값 타입 맞추기
    def coerce_values(left, right)
      # 둘 다 숫자로 변환 가능한 경우
      if numeric?(left) && numeric?(right)
        return [to_numeric(left), to_numeric(right)]
      end
      
      # 날짜 비교
      if date?(left) || date?(right)
        return [to_date(left), to_date(right)]
      end
      
      # 문자열 비교
      [left.to_s, right.to_s]
    end
    
    def numeric?(value)
      return true if value.is_a?(Numeric)
      return false if value.nil?
      
      # 문자열이 숫자인지 확인
      value.to_s.match?(/\A-?\d+(\.\d+)?\z/)
    end
    
    def to_numeric(value)
      return value if value.is_a?(Numeric)
      value.to_s.to_f
    end
    
    def date?(value)
      return true if value.is_a?(Date) || value.is_a?(Time) || value.is_a?(DateTime)
      return false if value.nil?
      
      # 날짜 형식 확인
      Date.parse(value.to_s) rescue false
    end
    
    def to_date(value)
      return value if value.is_a?(Date)
      return value.to_date if value.is_a?(Time) || value.is_a?(DateTime)
      
      Date.parse(value.to_s) rescue nil
    end
  end
end