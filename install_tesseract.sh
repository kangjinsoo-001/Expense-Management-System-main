#!/bin/bash

echo "Tesseract OCR 및 ImageMagick 설치 스크립트"
echo "========================================"

# OS 감지
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    echo "Linux 시스템 감지됨"
    
    # apt-get이 있는지 확인 (Ubuntu/Debian)
    if command -v apt-get &> /dev/null; then
        echo "Ubuntu/Debian 시스템으로 설치를 진행합니다..."
        sudo apt-get update
        sudo apt-get install -y tesseract-ocr tesseract-ocr-kor tesseract-ocr-eng imagemagick
        echo "설치 완료!"
        
    # yum이 있는지 확인 (CentOS/RHEL)
    elif command -v yum &> /dev/null; then
        echo "CentOS/RHEL 시스템으로 설치를 진행합니다..."
        sudo yum install -y tesseract tesseract-langpack-kor tesseract-langpack-eng ImageMagick
        echo "설치 완료!"
    else
        echo "지원되지 않는 Linux 배포판입니다."
        echo "수동으로 tesseract-ocr을 설치해주세요."
    fi
    
elif [[ "$OSTYPE" == "darwin"* ]]; then
    echo "macOS 시스템 감지됨"
    
    # Homebrew 확인
    if command -v brew &> /dev/null; then
        echo "Homebrew로 설치를 진행합니다..."
        brew install tesseract
        brew install tesseract-lang
        brew install imagemagick
        echo "설치 완료!"
    else
        echo "Homebrew가 설치되어 있지 않습니다."
        echo "먼저 Homebrew를 설치하거나 수동으로 Tesseract를 설치해주세요."
        echo "Homebrew 설치: /bin/bash -c \"\$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)\""
    fi
    
elif [[ "$OSTYPE" == "msys" ]] || [[ "$OSTYPE" == "cygwin" ]]; then
    echo "Windows 시스템 감지됨"
    echo "Windows에서는 다음 링크에서 Tesseract를 다운로드하여 설치해주세요:"
    echo "https://github.com/UB-Mannheim/tesseract/wiki"
else
    echo "알 수 없는 운영체제입니다: $OSTYPE"
fi

# 설치 확인
echo ""
echo "설치 확인 중..."
echo "-------------------"

# Tesseract 확인
if command -v tesseract &> /dev/null; then
    echo "✓ Tesseract가 성공적으로 설치되었습니다!"
    tesseract --version | head -1
    echo ""
    echo "사용 가능한 언어:"
    tesseract --list-langs 2>/dev/null | grep -E "kor|eng" || echo "언어 팩이 설치되지 않았습니다."
else
    echo "✗ Tesseract 설치를 확인할 수 없습니다."
fi

echo ""

# ImageMagick 확인
if command -v convert &> /dev/null; then
    echo "✓ ImageMagick이 성공적으로 설치되었습니다!"
    convert --version | head -1
else
    echo "✗ ImageMagick 설치를 확인할 수 없습니다."
fi

echo ""
echo "설치가 완료되지 않은 경우 수동으로 설치를 진행해주세요."