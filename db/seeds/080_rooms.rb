# 회의실 데이터 생성
puts "Creating rooms..."

# 회의실 데이터 (강남/판교/서초 순서)
rooms_data = [
  # 강남 오피스
  { name: "파이(Φ) 대회의실", category: "강남" },
  { name: "베타(Β)", category: "강남" },
  { name: "카파(Κ)", category: "강남" },
  { name: "알파(α)", category: "강남" },
  
  # 판교 오피스
  { name: "대회의실", category: "판교" },
  { name: "소회의실 1", category: "판교" },
  { name: "소회의실 2", category: "판교" },
  
  # 서초 오피스
  { name: "#1 대회의실", category: "서초" },
  { name: "#2 소회의실", category: "서초" },
  { name: "#3 소회의실", category: "서초" },
  { name: "#4 소회의실", category: "서초" }
]

rooms_data.each do |room_data|
  Room.find_or_create_by!(name: room_data[:name]) do |room|
    room.category = room_data[:category]
  end
end

puts "Created #{Room.count} rooms"