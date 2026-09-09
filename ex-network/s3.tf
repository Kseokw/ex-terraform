# 테라폼을 통해 버킷을 만들고 정적 웹사이트 호스팅이 가능하도록 설정을 변경하는 내용
# s3 bucket 생성
resource "aws_s3_bucket" "std07_lab_bucket" {
  bucket = "std07-lab-bucket"

  # 버킷에 객체가 존재하더라도 강제 삭제 허용(기본값: false)
  force_destroy = false

  # 객체 잠금
  object_lock_enabled = false # default(false)

  tags = { Name = "std07-lab-bucket" }
}

# bucket 버전관리
resource "aws_s3_bucket_versioning" "std07_lab_bucket_versioning" {
  bucket = aws_s3_bucket.std07_lab_bucket.id
  versioning_configuration {
    status = "Disabled" # Enabled
  }
}

# bucket Public Access 관리
resource "aws_s3_bucket_public_access_block" "std07_lab_bucket_access" {
  bucket = aws_s3_bucket.std07_lab_bucket.id
  # 1. 새로운 퍼블릭 ACL(권한 리스트) 추가를 막습니다. 누구나 들어오는 권한 추가 Lock
  block_public_acls = false

  # 2. 기존에 설정된 모든 퍼블릭 ACL을 무시합니다. 이미 부여된 외부 노출 권한이 있다면 취소
  ignore_public_acls = false

  # 3. 버킷 정책(Bucket Policy)을 통해 외부인이 접근하는 것을 차단합니다.
  block_public_policy = false

  # 4. 퍼블릭 정책이 걸려있는 버킷에 대한 익명 접근을 엄격히 제한합니다.
  restrict_public_buckets = false
}

# 정적 웹사이트 호스팅 활성화
# 이건 넣으면 활성화/ 안넣으면 비활성화
resource "aws_s3_bucket_website_configuration" "std07_lab_bucket_web" {
  bucket = aws_s3_bucket.std07_lab_bucket.id
  index_document {
    suffix = "index.html"
  }
  error_document {
    key = "error.html"
  }
}

# Public 사용자에게 객체 액세스 권한 부여
resource "aws_s3_bucket_policy" "std07_lab_bucket_policy" {
  bucket = aws_s3_bucket.std07_lab_bucket.id

  # Bucket Public Access 설정이 우선되어야 함.
  depends_on = [
    aws_s3_bucket_public_access_block.std07_lab_bucket_access
  ]

  # 정책 생성
  policy = jsonencode({
    Version = "2012-10-17"
    Statement : [
      {
        Sid : "PublicReadGetObject"
        Effect    = "Allow"
        Principal = "*"
        Action    = "s3:GetObject"
        Resource  = "${aws_s3_bucket.std07_lab_bucket.arn}/*"
      }
    ]
  })
}
