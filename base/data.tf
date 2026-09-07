# 현재 리전의 가용영역을 문자열 형태의 리스트로 반환
data "aws_availability_zones" "available_az" {
  state = "available"
}

# data.aws_availability_zones.available_az.names
# https://docs.aws.amazon.com/cli/latest/reference/
# https://docs.aws.amazon.com/cli/latest/reference/ec2/describe-vpcs.html -옵션
