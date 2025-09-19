namespace :room_categories do
  desc "기존 room의 category 필드를 room_category로 마이그레이션"
  task migrate: :environment do
    puts "회의실 카테고리 마이그레이션 시작..."
    
    # 기본 카테고리 생성
    categories = {
      '강남' => '강남 지점 회의실',
      '판교' => '판교 지점 회의실',
      '서초' => '서초 지점 회의실'
    }
    
    categories.each_with_index do |(name, description), index|
      category = RoomCategory.find_or_create_by(name: name) do |c|
        c.description = description
        c.display_order = index
        c.is_active = true
      end
      
      # 해당 카테고리의 회의실 업데이트
      Room.where(category: name).update_all(room_category_id: category.id)
      
      puts "- #{name} 카테고리 생성 및 회의실 #{Room.where(room_category_id: category.id).count}개 연결"
    end
    
    puts "마이그레이션 완료!"
  end
end