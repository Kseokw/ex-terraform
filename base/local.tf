# 로컬 환경 설정 블록
# 정의된 값의 변경없이 사용하는 변수
# 밑에 보이는 것 처럼 local 안에 여러 개의 함수 지정이 가능
# ========================================
locals {
  tag_header   = "${var.default_name}-"
  azs          = data.aws_availability_zones.available_az.names
  instance_chk = true
}
