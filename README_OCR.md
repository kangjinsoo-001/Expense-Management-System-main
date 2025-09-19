# 영수증 OCR 기능 설정 가이드

## 개요
이 프로젝트는 영수증 이미지나 PDF 파일에서 텍스트를 자동으로 추출하는 OCR 기능을 제공합니다.

## 필요한 시스템 패키지

OCR 기능을 사용하려면 다음 시스템 패키지가 필요합니다:
- **Tesseract OCR**: 이미지에서 텍스트를 추출
- **ImageMagick**: PDF를 이미지로 변환

## 자동 설치

프로젝트 루트에서 다음 스크립트를 실행하세요:

```bash
./install_tesseract.sh
```

## 수동 설치

### Ubuntu/Debian
```bash
sudo apt-get update
sudo apt-get install tesseract-ocr tesseract-ocr-kor tesseract-ocr-eng imagemagick
```

### macOS
```bash
brew install tesseract
brew install tesseract-lang
brew install imagemagick
```

### CentOS/RHEL
```bash
sudo yum install tesseract tesseract-langpack-kor tesseract-langpack-eng ImageMagick
```

## 설치 확인

```bash
# Tesseract 확인
tesseract --version

# 한국어 언어팩 확인
tesseract --list-langs | grep kor

# ImageMagick 확인
convert --version
```

## Ruby Gem 설치

Gemfile에 이미 포함되어 있지만, 수동으로 설치하려면:

```bash
gem install pdf-reader rtesseract mini_magick
```

또는 Bundle 사용:

```bash
bundle install
```

## 사용 방법

1. 경비 항목 페이지에서 "영수증 업로드" 버튼 클릭
2. PDF, JPG, PNG 형식의 영수증 파일 선택
3. 자동으로 텍스트 추출 진행
4. 추출된 텍스트 확인 후 저장

## 지원 파일 형식

- **PDF**: 텍스트 기반 PDF는 직접 추출, 스캔 PDF는 OCR 처리
- **이미지**: JPG, JPEG, PNG 형식 지원

## 문제 해결

### "Tesseract OCR이 설치되어 있지 않습니다" 오류
- 위의 설치 가이드를 따라 Tesseract를 설치하세요
- 설치 후 Rails 서버를 재시작하세요

### 한국어 인식이 안 되는 경우
- 한국어 언어팩이 설치되었는지 확인: `tesseract --list-langs | grep kor`
- 없다면 언어팩 추가 설치 필요

### PDF 처리 오류
- ImageMagick이 설치되었는지 확인: `convert --version`
- PDF 처리 권한 문제가 있을 수 있으니 ImageMagick 정책 파일 확인

## 성능 고려사항

- OCR은 CPU 집약적인 작업입니다
- 대용량 파일은 처리 시간이 오래 걸릴 수 있습니다
- Background Job으로 처리되므로 즉시 결과가 나타나지 않을 수 있습니다

## 개선 계획

현재는 로컬 OCR을 사용하지만, 더 나은 인식률을 위해 다음 서비스 통합을 고려할 수 있습니다:
- Google Vision API
- AWS Textract
- Azure Computer Vision
- Naver Clova OCR (한국어 특화)