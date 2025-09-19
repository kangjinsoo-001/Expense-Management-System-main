# frozen_string_literal: true

module OrganizationTreeLoadable
  extend ActiveSupport::Concern

  private

  # 재귀적으로 includes 해시 구성
  def build_recursive_includes(depth, current_level = 0, include_manager: true)
    if current_level >= depth
      return include_manager ? [:manager, :children] : [:children]
    end
    
    includes_hash = {
      children: build_recursive_includes(depth, current_level + 1, include_manager: include_manager)
    }
    
    includes_hash[:manager] = {} if include_manager
    includes_hash
  end
  
  # 조직 트리의 최대 깊이 계산
  def calculate_max_depth
    # 캐시를 사용하여 매번 계산하지 않도록 함
    Rails.cache.fetch('organization_max_depth', expires_in: 1.hour) do
      # SQL로 직접 계산하는 것이 더 효율적
      sql = <<-SQL
        WITH RECURSIVE org_depth AS (
          SELECT id, 0 as depth
          FROM organizations
          WHERE parent_id IS NULL
          
          UNION ALL
          
          SELECT o.id, od.depth + 1
          FROM organizations o
          JOIN org_depth od ON o.parent_id = od.id
        )
        SELECT MAX(depth) FROM org_depth
      SQL
      
      result = ActiveRecord::Base.connection.execute(sql)
      result.first['MAX(depth)'] || 0
    end
  end
end