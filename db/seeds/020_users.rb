# 사용자 생성
puts "Creating users..."

# 조직 데이터 가져오기
org_data = Rails.cache.read('organization_data')

# 기본 비밀번호
default_password = "hcghcghcg"

# 통합된 사용자 데이터 (정확히 239명)
all_users_data = [
  # 경영진 및 주요 리더
  { employee_id: "102", name: "박재현", organization: "휴먼컨설팅그룹", is_manager: true, email: "jaypark@tlx.kr", role: "manager" },
  { employee_id: "113", name: "백승아", organization: "CPO & Consulting/SaaS COO", is_manager: true, email: "sabaek@tlx.kr", role: "manager" },
  { employee_id: "140", name: "김영만", organization: "hunel COO", is_manager: true, email: "ymkim@tlx.kr", role: "manager" },
  { employee_id: "801", name: "이현주", organization: "BSS CENTER", is_manager: true, email: "hjlee@tlx.kr", role: "admin" },
  { employee_id: "179", name: "최효진", organization: "talenx BU", is_manager: true, email: "hjchoi@tlx.kr", role: "manager" },
  
  # AI x HR R&D Center
  { employee_id: "239", name: "이하진", organization: "AI x HR R&D Center", is_manager: true, email: "hajin.lee@tlx.kr", role: "manager" },
  { employee_id: "240", name: "고한결", organization: "AI x HR R&D Center", is_manager: false, email: "hgko@tlx.kr" },
  { employee_id: "279", name: "안동준", organization: "AI x HR R&D Center", is_manager: false, email: "djahn@tlx.kr" },
  { employee_id: "226", name: "박태서", organization: "AI x HR R&D Center", is_manager: false, email: "tspark@tlx.kr" },
  { employee_id: "241", name: "박다함", organization: "AI x HR R&D Center", is_manager: false, email: "dhpark@tlx.kr" },
  { employee_id: "295", name: "류성훈", organization: "AI x HR R&D Center", is_manager: false, email: "shryu@tlx.kr" },
  { employee_id: "307", name: "최수환", organization: "AI x HR R&D Center", is_manager: false, email: "suhwanchoi@tlx.kr" },
  
  # talenx R&D센터 및 팀
  { employee_id: "250", name: "유천호", organization: "talenx R&D센터", is_manager: true, email: "chyoo@tlx.kr" },
  { employee_id: "227", name: "신승희", organization: "talenx R&D팀", is_manager: false, email: "shshin@tlx.kr" },
  { employee_id: "576", name: "김영남", organization: "talenx R&D팀", is_manager: false, email: "ynkim@tlx.kr" },
  { employee_id: "608", name: "문선주", organization: "talenx R&D팀", is_manager: false, email: "sjmun@tlx.kr" },
  { employee_id: "628", name: "최한울", organization: "talenx R&D팀", is_manager: false, email: "huchoi@tlx.kr" },
  { employee_id: "228", name: "백영재", organization: "talenx R&D팀", is_manager: false, email: "yjback@tlx.kr" },
  { employee_id: "236", name: "이경규", organization: "talenx R&D팀", is_manager: false, email: "gglee@tlx.kr" },
  { employee_id: "665", name: "박예진", organization: "talenx R&D팀", is_manager: false, email: "yjpark@tlx.kr" },
  { employee_id: "248", name: "임민영", organization: "talenx R&D팀", is_manager: false, email: "mylim@tlx.kr" },
  { employee_id: "677", name: "정종원", organization: "talenx R&D팀", is_manager: false, email: "jwjeong@tlx.kr" },
  { employee_id: "249", name: "홍찬기", organization: "talenx R&D팀", is_manager: false, email: "ckhong@tlx.kr" },
  { employee_id: "251", name: "최수호", organization: "talenx R&D팀", is_manager: false, email: "shchoi@tlx.kr" },
  { employee_id: "252", name: "이종현", organization: "talenx R&D팀", is_manager: false, email: "jonghyun.lee@tlx.kr" },
  { employee_id: "258", name: "박성민", organization: "talenx R&D팀", is_manager: false, email: "smpark@tlx.kr" },
  { employee_id: "699", name: "김보군", organization: "talenx R&D팀", is_manager: false, email: "bkkim@tlx.kr" },
  { employee_id: "702", name: "이영진", organization: "talenx R&D팀", is_manager: false, email: "leeyj@tlx.kr" },
  { employee_id: "704", name: "정영석", organization: "talenx R&D팀", is_manager: false, email: "ysjeong@tlx.kr" },
  { employee_id: "722", name: "홍영석", organization: "talenx R&D팀", is_manager: false, email: "ys.hong@tlx.kr" },
  { employee_id: "263", name: "김승훈", organization: "talenx R&D팀", is_manager: false, email: "shunkim@tlx.kr" },
  { employee_id: "265", name: "김우성", organization: "talenx R&D팀", is_manager: false, email: "wskim@tlx.kr" },
  { employee_id: "266", name: "김예랑", organization: "talenx R&D팀", is_manager: false, email: "yrkim@tlx.kr" },
  { employee_id: "267", name: "이하늘", organization: "talenx R&D팀", is_manager: false, email: "hnlee@tlx.kr" },
  { employee_id: "270", name: "김소희", organization: "talenx R&D팀", is_manager: false, email: "shkim@tlx.kr" },
  { employee_id: "271", name: "김형진", organization: "talenx R&D팀", is_manager: false, email: "hj.kim@tlx.kr" },
  { employee_id: "272", name: "송현우", organization: "talenx R&D팀", is_manager: false, email: "hwsong@tlx.kr" },
  { employee_id: "273", name: "안동현", organization: "talenx R&D팀", is_manager: false, email: "dhahn@tlx.kr" },
  { employee_id: "275", name: "이주호", organization: "talenx R&D팀", is_manager: false, email: "juholee@tlx.kr" },
  { employee_id: "280", name: "윤두현", organization: "talenx R&D팀", is_manager: false, email: "dhyoon@tlx.kr" },
  { employee_id: "281", name: "임성빈", organization: "talenx R&D팀", is_manager: false, email: "sblim@tlx.kr" },
  { employee_id: "282", name: "정소현", organization: "talenx R&D팀", is_manager: false, email: "shjung@tlx.kr" },
  { employee_id: "283", name: "주재민", organization: "talenx R&D팀", is_manager: false, email: "jmju@tlx.kr" },
  { employee_id: "284", name: "최주원", organization: "talenx R&D팀", is_manager: false, email: "jwchoi@tlx.kr" },
  { employee_id: "286", name: "한국인", organization: "talenx R&D팀", is_manager: false, email: "gihan@tlx.kr" },
  { employee_id: "288", name: "김경현", organization: "talenx R&D팀", is_manager: false, email: "ghkim@tlx.kr" },
  { employee_id: "293", name: "최서희", organization: "talenx R&D팀", is_manager: false, email: "seoheechoi@tlx.kr" },
  { employee_id: "294", name: "정찬양", organization: "talenx R&D팀", is_manager: false, email: "cyjung@tlx.kr" },
  { employee_id: "298", name: "송예은", organization: "talenx R&D팀", is_manager: false, email: "yesong@tlx.kr" },
  { employee_id: "299", name: "추헌재", organization: "talenx R&D팀", is_manager: false, email: "hjchu@tlx.kr" },
  { employee_id: "300", name: "변진상", organization: "talenx R&D팀", is_manager: false, email: "jsbyeon@tlx.kr" },
  { employee_id: "301", name: "윤서안", organization: "talenx R&D팀", is_manager: false, email: "sayoon@tlx.kr" },
  { employee_id: "302", name: "이원희", organization: "talenx R&D팀", is_manager: false, email: "whlee@tlx.kr" },
  { employee_id: "255", name: "김혜원", organization: "talenx R&D팀", is_manager: false, email: "hwkim@tlx.kr" },
  { employee_id: "256", name: "강진수", organization: "talenx R&D팀", is_manager: false, email: "jskang@tlx.kr" },
  { employee_id: "269", name: "정혜진", organization: "talenx R&D팀", is_manager: false, email: "hj.jeong@tlx.kr" },
  { employee_id: "277", name: "한윤석", organization: "talenx R&D팀", is_manager: false, email: "yshan@tlx.kr" },
  { employee_id: "278", name: "김민영", organization: "talenx R&D팀", is_manager: false, email: "mykim@tlx.kr" },
  { employee_id: "296", name: "박소정", organization: "talenx R&D팀", is_manager: false, email: "sj.park@tlx.kr" },
  { employee_id: "297", name: "배유나", organization: "talenx R&D팀", is_manager: false, email: "yunabae@tlx.kr" },
  { employee_id: "691", name: "이미경", organization: "talenx R&D팀", is_manager: false, email: "mk.lee@tlx.kr" },
  { employee_id: "285", name: "유승연", organization: "talenx R&D팀", is_manager: false, email: "syyoo@tlx.kr" },
  { employee_id: "290", name: "강은영", organization: "talenx R&D팀", is_manager: false, email: "eykang@tlx.kr" },
  { employee_id: "501", name: "변주환", organization: "talenx R&D팀", is_manager: false, email: "jhbyeon@tlx.kr" },
  
  # talenx BU
  { employee_id: "254", name: "백진주", organization: "talenx BU", is_manager: false, email: "jjbaek@tlx.kr" },
  { employee_id: "291", name: "임오경", organization: "talenx BU", is_manager: false, email: "oklim@tlx.kr" },
  { employee_id: "292", name: "박남동", organization: "talenx BU", is_manager: false, email: "ndpark@tlx.kr" },
  
  # Payroll R&D팀
  { employee_id: "786", name: "이민욱", organization: "Payroll R&D팀", is_manager: false, email: "mulee@tlx.kr" },
  { employee_id: "869", name: "홍동기", organization: "Payroll R&D팀", is_manager: false, email: "dkhong@tlx.kr" },
  { employee_id: "873", name: "권영환", organization: "Payroll R&D팀", is_manager: false, email: "yh-kwon@tlx.kr" },
  
  # 정보보호 R&D팀
  { employee_id: "750", name: "유예인", organization: "정보보호 R&D팀", is_manager: false, email: "yiyoo@tlx.kr" },
  { employee_id: "870", name: "정영진", organization: "정보보호 R&D팀", is_manager: false, email: "yjjung@tlx.kr" },
  
  # CISO/정보보호팀
  { employee_id: "798", name: "조양원", organization: "정보보호팀", is_manager: true, email: "yw.cho@tlx.kr" },
  { employee_id: "868", name: "유형석", organization: "정보보호팀", is_manager: false, email: "hsyoo@tlx.kr" },
  
  # hunel BU : Cha
  { employee_id: "535", name: "김지호", organization: "hunel BU : Cha", is_manager: true, email: "kimjh@tlx.kr" },
  
  # SA Chapter
  { employee_id: "609", name: "김영진", organization: "SA Chapter", is_manager: true, email: "yjkim@tlx.kr" },
  { employee_id: "548", name: "이상규", organization: "SA Chapter", is_manager: false, email: "sglee@tlx.kr" },
  { employee_id: "664", name: "이명진", organization: "SA Chapter", is_manager: false, email: "mjlee@tlx.kr" },
  { employee_id: "686", name: "최준빈", organization: "SA Chapter", is_manager: false, email: "jbchoi@tlx.kr" },
  { employee_id: "701", name: "정화진", organization: "SA Chapter", is_manager: false, email: "hjjeong@tlx.kr" },
  { employee_id: "746", name: "김민규", organization: "SA Chapter", is_manager: false, email: "mkkim@tlx.kr" },
  { employee_id: "779", name: "김연준", organization: "SA Chapter", is_manager: false, email: "yj.kim@tlx.kr" },
  { employee_id: "788", name: "정민규", organization: "SA Chapter", is_manager: false, email: "mkjung@tlx.kr" },
  { employee_id: "859", name: "김다예", organization: "SA Chapter", is_manager: false, email: "dayeakim@tlx.kr" },
  { employee_id: "865", name: "나큰솔", organization: "SA Chapter", is_manager: false, email: "ksna@tlx.kr" },
  
  # PPA Chapter
  { employee_id: "659", name: "최길남", organization: "PPA Chapter", is_manager: true, email: "knchoi@tlx.kr" },
  { employee_id: "588", name: "김준영", organization: "PPA Chapter", is_manager: false, email: "jykim@tlx.kr" },
  { employee_id: "590", name: "이진홍", organization: "PPA Chapter", is_manager: false, email: "jhlee@tlx.kr" },
  { employee_id: "679", name: "정권", organization: "PPA Chapter", is_manager: false, email: "kwon.jeong@tlx.kr" },
  { employee_id: "681", name: "전봉석", organization: "PPA Chapter", is_manager: false, email: "bsjeon@tlx.kr" },
  { employee_id: "717", name: "전영식", organization: "PPA Chapter", is_manager: false, email: "ysjeon@tlx.kr" },
  
  # hunel BU : Nel
  { employee_id: "510", name: "남해경", organization: "hunel BU : Nel", is_manager: true, email: "namhk@tlx.kr" },
  
  # PB Chapter
  { employee_id: "772", name: "이종백", organization: "PB Chapter", is_manager: true, email: "jblee@tlx.kr" },
  { employee_id: "633", name: "장태훈", organization: "PB Chapter", is_manager: false, email: "thjang@tlx.kr" },
  { employee_id: "647", name: "김도윤", organization: "PB Chapter", is_manager: false, email: "dykim@tlx.kr" },
  { employee_id: "674", name: "구자혁", organization: "PB Chapter", is_manager: false, email: "jhkoo@tlx.kr" },
  { employee_id: "732", name: "박희연", organization: "PB Chapter", is_manager: false, email: "hypark@tlx.kr" },
  { employee_id: "747", name: "조진우", organization: "PB Chapter", is_manager: false, email: "jwcho@tlx.kr" },
  { employee_id: "759", name: "최종오", organization: "PB Chapter", is_manager: false, email: "jochoi@tlx.kr" },
  { employee_id: "766", name: "길민규", organization: "PB Chapter", is_manager: false, email: "mggil@tlx.kr" },
  { employee_id: "776", name: "김도연", organization: "PB Chapter", is_manager: false, email: "dy.kim@tlx.kr" },
  { employee_id: "860", name: "임한나", organization: "PB Chapter", is_manager: false, email: "hnim@tlx.kr" },
  
  # TA Chapter
  { employee_id: "618", name: "홍경표", organization: "TA Chapter", is_manager: true, email: "kphong@tlx.kr" },
  { employee_id: "612", name: "김경신", organization: "TA Chapter", is_manager: false, email: "kskim@tlx.kr" },
  { employee_id: "719", name: "최민석", organization: "TA Chapter", is_manager: false, email: "mschoi@tlx.kr" },
  { employee_id: "751", name: "추인엽", organization: "TA Chapter", is_manager: false, email: "iychoo@tlx.kr" },
  { employee_id: "767", name: "최명수", organization: "TA Chapter", is_manager: false, email: "ms.choi@tlx.kr" },
  { employee_id: "785", name: "신혜진", organization: "TA Chapter", is_manager: false, email: "hjshin@tlx.kr" },
  { employee_id: "871", name: "김대홍", organization: "TA Chapter", is_manager: false, email: "dhkim@tlx.kr" },
  { employee_id: "879", name: "배근철", organization: "TA Chapter", is_manager: false, email: "gcbae@tlx.kr" },
  { employee_id: "880", name: "오우석", organization: "TA Chapter", is_manager: false, email: "wsoh@tlx.kr" },
  { employee_id: "887", name: "배상진", organization: "TA Chapter", is_manager: false, email: "sjbae@tlx.kr" },
  
  # hunel BU : Mén
  { employee_id: "574", name: "김찬호", organization: "hunel BU : Mén", is_manager: true, email: "chkim@tlx.kr" },
  
  # HC Chapter
  { employee_id: "518", name: "최영우", organization: "HC Chapter", is_manager: true, email: "ywchoi@tlx.kr" },
  { employee_id: "669", name: "박경선", organization: "HC Chapter", is_manager: false, email: "pks70ksp@tlx.kr" },
  { employee_id: "727", name: "김광수", organization: "HC Chapter", is_manager: false, email: "kskim1@tlx.kr" },
  { employee_id: "738", name: "조예영", organization: "HC Chapter", is_manager: false, email: "yyjo@tlx.kr" },
  { employee_id: "748", name: "장현섭", organization: "HC Chapter", is_manager: false, email: "hsjang@tlx.kr" },
  { employee_id: "752", name: "정명주", organization: "HC Chapter", is_manager: false, email: "neojmj@tlx.kr" },
  { employee_id: "778", name: "김수찬", organization: "HC Chapter", is_manager: false, email: "sckim@tlx.kr" },
  { employee_id: "782", name: "박수영", organization: "HC Chapter", is_manager: false, email: "sypark@tlx.kr" },
  { employee_id: "789", name: "최승협", organization: "HC Chapter", is_manager: false, email: "sh.choi@tlx.kr" },
  
  # TM Chapter
  { employee_id: "623", name: "이준섭", organization: "TM Chapter", is_manager: true, email: "leejs@tlx.kr" },
  { employee_id: "599", name: "김종수", organization: "TM Chapter", is_manager: false, email: "jskim@tlx.kr" },
  { employee_id: "688", name: "하헌진", organization: "TM Chapter", is_manager: false, email: "hjha@tlx.kr" },
  { employee_id: "693", name: "이원석", organization: "TM Chapter", is_manager: false, email: "wslee@tlx.kr" },
  { employee_id: "705", name: "정현승", organization: "TM Chapter", is_manager: false, email: "hs.jeong@tlx.kr" },
  { employee_id: "723", name: "홍준범", organization: "TM Chapter", is_manager: false, email: "jbhong@tlx.kr" },
  { employee_id: "731", name: "김유림", organization: "TM Chapter", is_manager: false, email: "yr.kim@tlx.kr" },
  { employee_id: "734", name: "성지혜", organization: "TM Chapter", is_manager: false, email: "jhsung@tlx.kr" },
  { employee_id: "758", name: "홍성협", organization: "TM Chapter", is_manager: false, email: "shhong@tlx.kr" },
  { employee_id: "775", name: "김경찬", organization: "TM Chapter", is_manager: false, email: "kckim@tlx.kr" },
  
  # hunel R&D센터
  { employee_id: "Z0012", name: "민주리", organization: "hunel R＆D센터", is_manager: false, email: "mjr0621@tlx.kr" },
  
  # Package R&D팀
  { employee_id: "556", name: "박영환", organization: "Package R&D팀", is_manager: true, email: "yhpark@tlx.kr" },
  { employee_id: "568", name: "윤영필", organization: "Package R&D팀", is_manager: false, email: "ypyoon@tlx.kr" },
  { employee_id: "605", name: "정대규", organization: "Package R&D팀", is_manager: false, email: "dgjeong@tlx.kr" },
  { employee_id: "629", name: "주진수", organization: "Package R&D팀", is_manager: false, email: "jsjoo@tlx.kr" },
  { employee_id: "632", name: "장대규", organization: "Package R&D팀", is_manager: false, email: "dg.jang@tlx.kr" },
  { employee_id: "646", name: "김기웅", organization: "Package R&D팀", is_manager: false, email: "kimko@tlx.kr" },
  { employee_id: "687", name: "최현수", organization: "Package R&D팀", is_manager: false, email: "choihs@tlx.kr" },
  { employee_id: "698", name: "우성빈", organization: "Package R&D팀", is_manager: false, email: "sbwoo@tlx.kr" },
  { employee_id: "707", name: "안승우", organization: "Package R&D팀", is_manager: false, email: "swan@tlx.kr" },
  { employee_id: "713", name: "문희웅", organization: "Package R&D팀", is_manager: false, email: "hwmoon@tlx.kr" },
  { employee_id: "743", name: "윤현규", organization: "Package R&D팀", is_manager: false, email: "hkyun@tlx.kr" },
  { employee_id: "783", name: "박희연", organization: "Package R&D팀", is_manager: false, email: "hy.park@tlx.kr" },
  { employee_id: "851", name: "김현구", organization: "Package R&D팀", is_manager: false, email: "hgkim@tlx.kr" },
  { employee_id: "857", name: "최수훈", organization: "Package R&D팀", is_manager: false, email: "choish@tlx.kr" },
  { employee_id: "872", name: "전민형", organization: "Package R&D팀", is_manager: false, email: "mhjeon@tlx.kr" },
  
  # CS BU
  { employee_id: "578", name: "정종근", organization: "CS BU", is_manager: true, email: "jkjeong@tlx.kr" },
  
  # hunel CS팀
  { employee_id: "531", name: "김정혜", organization: "hunel CS팀", is_manager: true, email: "jhkim@tlx.kr" },
  { employee_id: "690", name: "문진수", organization: "hunel CS팀", is_manager: false, email: "jsmun@tlx.kr" },
  { employee_id: "729", name: "이진아", organization: "hunel CS팀", is_manager: false, email: "jalee@tlx.kr" },
  { employee_id: "777", name: "김문종", organization: "hunel CS팀", is_manager: false, email: "mj.kim@tlx.kr" },
  { employee_id: "891", name: "김태성", organization: "hunel CS팀", is_manager: false, email: "tskim@tlx.kr" },
  { employee_id: "Z0075", name: "문광혁", organization: "hunel CS팀", is_manager: false, email: "moonkh@tlx.kr" },
  { employee_id: "Z0076", name: "전윤성", organization: "hunel CS팀", is_manager: false, email: "nobam@tlx.kr" },
  { employee_id: "Z0079", name: "허일", organization: "hunel CS팀", is_manager: false, email: "nice@tlx.kr" },
  { employee_id: "Z0169", name: "심두현", organization: "hunel CS팀", is_manager: false, email: "symdh@tlx.kr" },
  
  # JaDE CS팀
  { employee_id: "J20171101", name: "김성민", organization: "JaDE CS팀", is_manager: false, email: "kimsm@tlx.kr" },
  { employee_id: "J20180601", name: "이도원", organization: "JaDE CS팀", is_manager: false, email: "dwlee@tlx.kr" },
  { employee_id: "J20200201", name: "신홍규", organization: "JaDE CS팀", is_manager: false, email: "shin.hk@tlx.kr" },
  { employee_id: "J20201101", name: "유홍열", organization: "JaDE CS팀", is_manager: false, email: "yhy8936@tlx.kr" },
  { employee_id: "J20210101", name: "박하얀", organization: "JaDE CS팀", is_manager: false, email: "park.hy@tlx.kr" },
  { employee_id: "J20220101", name: "최영아", organization: "JaDE CS팀", is_manager: false, email: "choiyou7@tlx.kr" },
  { employee_id: "J20230202", name: "이재춘", organization: "JaDE CS팀", is_manager: false, email: "lee.jc@tlx.kr" },
  { employee_id: "861", name: "김동욱", organization: "JaDE CS팀", is_manager: false, email: "dw.kim@tlx.kr" },
  { employee_id: "864", name: "임정찬", organization: "JaDE CS팀", is_manager: false, email: "jclim@tlx.kr" },
  { employee_id: "882", name: "강태환", organization: "JaDE CS팀", is_manager: false, email: "thkang@tlx.kr" },
  { employee_id: "888", name: "손정운", organization: "JaDE CS팀", is_manager: false, email: "juson@tlx.kr" },
  { employee_id: "889", name: "김신영", organization: "JaDE CS팀", is_manager: false, email: "sykim@tlx.kr" },
  { employee_id: "J20210201", name: "김동현", organization: "JaDE CS팀", is_manager: false, email: "kim.dh@tlx.kr" },
  
  # 고도화 개발팀
  { employee_id: "666", name: "이지수", organization: "고도화 개발팀", is_manager: true, email: "sheismylife@tlx.kr" },
  { employee_id: "564", name: "진용인", organization: "고도화 개발팀", is_manager: false, email: "yijin@tlx.kr" },
  { employee_id: "736", name: "정올린", organization: "고도화 개발팀", is_manager: false, email: "oljung@tlx.kr" },
  { employee_id: "780", name: "김현지", organization: "고도화 개발팀", is_manager: false, email: "hjkim@tlx.kr" },
  { employee_id: "878", name: "강석훈", organization: "고도화 개발팀", is_manager: false, email: "shkang@tlx.kr" },
  
  # Package UX팀
  { employee_id: "552", name: "양혜진", organization: "Package UX팀", is_manager: true, email: "hjyang@tlx.kr" },
  { employee_id: "658", name: "윤영로", organization: "Package UX팀", is_manager: false, email: "yryoon@tlx.kr" },
  { employee_id: "692", name: "홍용섭", organization: "Package UX팀", is_manager: false, email: "yshong@tlx.kr" },
  { employee_id: "721", name: "김진군", organization: "Package UX팀", is_manager: false, email: "jgkim@tlx.kr" },
  { employee_id: "725", name: "안선혜", organization: "Package UX팀", is_manager: false, email: "shan@tlx.kr" },
  { employee_id: "754", name: "이혜원", organization: "Package UX팀", is_manager: false, email: "hwlee@tlx.kr" },
  { employee_id: "790", name: "최은영", organization: "Package UX팀", is_manager: false, email: "eychoi@tlx.kr" },
  { employee_id: "799", name: "박수휘", organization: "Package UX팀", is_manager: false, email: "sh.park@tlx.kr" },
  { employee_id: "874", name: "김진솔", organization: "Package UX팀", is_manager: false, email: "kimjs@tlx.kr" },
  { employee_id: "875", name: "조은지", organization: "Package UX팀", is_manager: false, email: "ejcho@tlx.kr" },
  { employee_id: "883", name: "김유진", organization: "Package UX팀", is_manager: false, email: "yujinkim@tlx.kr" },
  { employee_id: "884", name: "이혜원", organization: "Package UX팀", is_manager: false, email: "hyewonlee@tlx.kr" },
  
  # JaDE BU
  { employee_id: "505", name: "허욱", organization: "JaDE BU", is_manager: true, email: "ukhur@tlx.kr" },
  
  # JaDE Front Team
  { employee_id: "765", name: "김상원", organization: "JaDE Front Team", is_manager: true, email: "swkim@tlx.kr" },
  { employee_id: "638", name: "김준호", organization: "JaDE Front Team", is_manager: false, email: "jh.kim@tlx.kr" },
  { employee_id: "660", name: "강호식", organization: "JaDE Front Team", is_manager: false, email: "hskang@tlx.kr" },
  { employee_id: "676", name: "서기남", organization: "JaDE Front Team", is_manager: false, email: "knseo@tlx.kr" },
  { employee_id: "700", name: "이민아", organization: "JaDE Front Team", is_manager: false, email: "minalee@tlx.kr" },
  { employee_id: "708", name: "정경만", organization: "JaDE Front Team", is_manager: false, email: "jung.km@tlx.kr" },
  { employee_id: "730", name: "김민주", organization: "JaDE Front Team", is_manager: false, email: "mjkim@tlx.kr" },
  { employee_id: "745", name: "최준환", organization: "JaDE Front Team", is_manager: false, email: "jhchoi@tlx.kr" },
  { employee_id: "749", name: "김준", organization: "JaDE Front Team", is_manager: false, email: "junkim@tlx.kr" },
  { employee_id: "764", name: "황재윤", organization: "JaDE Front Team", is_manager: false, email: "jyhwang@tlx.kr" },
  { employee_id: "768", name: "이승준", organization: "JaDE Front Team", is_manager: false, email: "sjlee@tlx.kr" },
  { employee_id: "781", name: "박민수", organization: "JaDE Front Team", is_manager: false, email: "mspark@tlx.kr" },
  { employee_id: "787", name: "이주희", organization: "JaDE Front Team", is_manager: false, email: "juheelee@tlx.kr" },
  { employee_id: "863", name: "장진영", organization: "JaDE Front Team", is_manager: false, email: "jyjang@tlx.kr" },
  
  # PO BU / Payroll 전략팀
  { employee_id: "643", name: "마상희", organization: "Payroll 전략팀", is_manager: true, email: "shma@tlx.kr" },
  
  # Payroll 서비스팀
  { employee_id: "662", name: "안미옥", organization: "Payroll 서비스팀", is_manager: true, email: "moan@tlx.kr" },
  { employee_id: "661", name: "조은날", organization: "Payroll 서비스팀", is_manager: false, email: "encho@tlx.kr" },
  { employee_id: "715", name: "소이나", organization: "Payroll 서비스팀", is_manager: false, email: "linaso@tlx.kr" },
  { employee_id: "793", name: "조영원", organization: "Payroll 서비스팀", is_manager: false, email: "ywcho@tlx.kr" },
  { employee_id: "796", name: "김지영", organization: "Payroll 서비스팀", is_manager: false, email: "jy.kim@tlx.kr" },
  { employee_id: "858", name: "김남희", organization: "Payroll 서비스팀", is_manager: false, email: "nhkim@tlx.kr" },
  { employee_id: "866", name: "이주영", organization: "Payroll 서비스팀", is_manager: false, email: "juylee@tlx.kr" },
  { employee_id: "867", name: "김도희", organization: "Payroll 서비스팀", is_manager: false, email: "doheekim@tlx.kr" },
  { employee_id: "876", name: "장민애", organization: "Payroll 서비스팀", is_manager: false, email: "majang@tlx.kr" },
  { employee_id: "881", name: "조율미", organization: "Payroll 서비스팀", is_manager: false, email: "ymjo@tlx.kr" },
  { employee_id: "892", name: "이다솜", organization: "Payroll 서비스팀", is_manager: false, email: "dslee@tlx.kr" },
  
  # 마케팅본부
  { employee_id: "529", name: "목영빈", organization: "마케팅 MS Team", is_manager: true, email: "ybmok@tlx.kr" },
  { employee_id: "610", name: "유성현", organization: "마케팅 MS Team", is_manager: false, email: "shyu@tlx.kr" },
  { employee_id: "680", name: "이혜린", organization: "마케팅 MS Team", is_manager: false, email: "hrlee@tlx.kr" },
  { employee_id: "886", name: "이지현", organization: "마케팅 MS Team", is_manager: false, email: "jihyeonlee@tlx.kr" },
  
  { employee_id: "603", name: "김동운", organization: "마케팅 PF Team", is_manager: true, email: "dwkim@tlx.kr" },
  { employee_id: "595", name: "김장현", organization: "마케팅 PF Team", is_manager: false, email: "jhkim1@tlx.kr" },
  { employee_id: "792", name: "남재현", organization: "마케팅 PF Team", is_manager: false, email: "jhnam@tlx.kr" },
  
  # BSS CENTER
  { employee_id: "Z0230", name: "유승원", organization: "Admin Team", is_manager: false, email: "swyu@tlx.kr" },
  { employee_id: "Z0267", name: "노희원", organization: "Admin Team", is_manager: false, email: "hwroh@tlx.kr" },
  
  { employee_id: "803", name: "양인정", organization: "Design Team", is_manager: true, email: "ijyang@tlx.kr" },
  { employee_id: "808", name: "정다은", organization: "Design Team", is_manager: false, email: "dejung@tlx.kr" },
  
  # Consulting BU
  { employee_id: "171", name: "홍순원", organization: "Consulting BU", is_manager: true, email: "swhong@tlx.kr" },
  { employee_id: "205", name: "채덕성", organization: "Consulting BU", is_manager: false, email: "dschae@tlx.kr" },
  { employee_id: "231", name: "이주원", organization: "Consulting BU", is_manager: false, email: "jw.lee@tlx.kr" },
  { employee_id: "232", name: "홍전표", organization: "Consulting BU", is_manager: false, email: "jphong@tlx.kr" },
  { employee_id: "238", name: "최한얼", organization: "Consulting BU", is_manager: false, email: "hechoi@tlx.kr" },
  { employee_id: "247", name: "임태형", organization: "Consulting BU", is_manager: false, email: "thlim@tlx.kr" },
  { employee_id: "261", name: "구지은", organization: "Consulting BU", is_manager: false, email: "jekoo@tlx.kr" },
  { employee_id: "262", name: "엄채영", organization: "Consulting BU", is_manager: false, email: "cyeom@tlx.kr" },
  { employee_id: "276", name: "박창규", organization: "Consulting BU", is_manager: false, email: "cgpark@tlx.kr" },
  { employee_id: "289", name: "육민호", organization: "Consulting BU", is_manager: false, email: "mhyuk@tlx.kr" },
  { employee_id: "305", name: "이경훈", organization: "Consulting BU", is_manager: false, email: "khlee@tlx.kr" },
  { employee_id: "306", name: "김경우", organization: "Consulting BU", is_manager: false, email: "kwkim@tlx.kr" }
]

# 사용자 생성 통계
created_count = 0
updated_count = 0
skipped_count = 0
errors = []

puts "총 #{all_users_data.length}명의 사용자 데이터 처리 시작..."

all_users_data.each_with_index do |user_data, index|
  begin
    # 조직 찾기 또는 생성
    org = Organization.find_or_create_by!(name: user_data[:organization]) do |o|
      o.code = "ORG_#{SecureRandom.hex(4).upcase}"
      puts "  새 조직 생성: #{o.name}"
    end
    
    # 사용자 찾기 또는 생성 (이메일로 중복 체크)
    user = User.find_by(email: user_data[:email])
    
    if user
      # 이미 존재하는 사용자 - 업데이트하지 않음
      skipped_count += 1
      print "."
    else
      # 새 사용자 생성
      user = User.create!(
        email: user_data[:email],
        password: default_password,
        password_confirmation: default_password,
        name: user_data[:name],
        employee_id: user_data[:employee_id],
        role: user_data[:role] || :employee,
        organization: org
      )
      created_count += 1
      print "+"
    end
    
    # 조직장 설정 (Organization 모델의 assign_manager 메서드 사용)
    if user_data[:is_manager] && org.manager != user
      org.assign_manager(user)
      puts "\n  #{user.name}을(를) #{org.name}의 조직장으로 설정"
    end
    
    # 50명마다 진행 상황 출력
    if (index + 1) % 50 == 0
      puts " [#{index + 1}/#{all_users_data.length}]"
    end
    
  rescue => e
    errors << "Error processing #{user_data[:name]} (#{user_data[:email]}): #{e.message}"
    print "x"
  end
end

puts "\n\n=== 사용자 생성 완료 ==="
puts "  신규 생성: #{created_count}명"
puts "  기존 사용자 스킵: #{skipped_count}명"
puts "  전체 사용자 수: #{User.count}명"

if errors.any?
  puts "\n처리 중 오류 발생:"
  errors.each { |error| puts "  - #{error}" }
end

puts "\n=== 전체 사용자 통계 ==="
puts "총 사용자 수: #{User.count}명"
puts "조직장 수: #{User.manager.count}명"
puts "관리자 수: #{User.admin.count}명"
puts "일반 직원 수: #{User.employee.count}명"

# 주요 로그인 계정 안내
puts "\n=== 주요 로그인 계정 ==="
puts "대표이사: jaypark@tlx.kr / #{default_password}"
puts "CPO: sabaek@tlx.kr / #{default_password}"
puts "hunel COO: ymkim@tlx.kr / #{default_password}"
puts "BSS CENTER 리더(Admin): hjlee@tlx.kr / #{default_password}"
puts "talenx BU 리더: hjchoi@tlx.kr / #{default_password}"
puts "AI x HR R&D Center 리더: hajin.lee@tlx.kr / #{default_password}"
puts "\n모든 계정 비밀번호: #{default_password}"