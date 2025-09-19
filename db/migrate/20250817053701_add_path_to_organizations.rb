class AddPathToOrganizations < ActiveRecord::Migration[8.0]
  def change
    add_column :organizations, :path, :string
    add_index :organizations, :path
    
    # 기존 데이터에 대한 path 설정
    reversible do |dir|
      dir.up do
        execute <<-SQL
          WITH RECURSIVE org_paths AS (
            -- 루트 조직들
            SELECT id, parent_id, CAST(id AS VARCHAR) as path
            FROM organizations
            WHERE parent_id IS NULL
            
            UNION ALL
            
            -- 하위 조직들
            SELECT o.id, o.parent_id, CONCAT(op.path, '.', o.id) as path
            FROM organizations o
            JOIN org_paths op ON o.parent_id = op.id
          )
          UPDATE organizations
          SET path = org_paths.path
          FROM org_paths
          WHERE organizations.id = org_paths.id;
        SQL
      end
    end
  end
end
