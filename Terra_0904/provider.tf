# [파일명].tf
# provider.tf: 클라우드 공급자(AWS, GCP, Azure 등), 버전, 리전 설정
# variables.tf: 변수 정의
# terraform.tfvars: 변수 값 설정
# local.tf: 로컬 변수
# data.tf: 기존 리소스 정의(조회)
# outputs.tf: 출력값 및 모듈로 기존 리소스 연결
# main.tf: 리소스 정의 및 모듈 호출

# ##########################################################
# provider.tf
# ========================================================
# 1. 테라폼 실행 환경 설정 블록
terraform {
  required_providers {
    aws = {
      # 프로바이더 라이브러리 다운로드 경로
      source = "hashicorp/aws"

      # 사용할 버전 정의
      version = "~> 6.0" # 5.0 이상 6.0 미만 버전 중 최신 버전사용
    }
  }

  # 협업을 위한 상태 값 공유 저장소 설정
  # backend "s3" {
  #   bucket         = "bipa17-std07-bucket"                             # S3 버킷 이름
  #   key            = "TerraformState/Lab/create-vpc/terraform.tfstate" # 버킷 내 저장할 위치
  #   region         = "ap-southeast-1"                                  # S3 버킷 리전
  #   dynamodb_table = "std07-terraform-lock-table"                      # 상태 잠금 테이블 이름
  #   encrypt        = true                                              # 상태 파일 암호화 여부
  # }

  #   required_providers {
  #     google = {
  #       source  = "hashicorp/google"
  #       version = "~> 6.0"
  #     }
  #   }
}

provider "aws" {
  region = "ap-southeast-1" # AWS 리전 설정
  default_tags {            # 모든 리소스에 공통 태그 적용
    tags = {
      Class = "bipa17"
    }
  }
}


