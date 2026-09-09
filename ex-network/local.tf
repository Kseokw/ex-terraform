locals {
  # 수정됨: 올바른 타입(aws_availability_zones), 올바른 이름(available_az), 올바른 속성(.names)
  azs    = data.aws_availability_zones.available_az.names
  ami_id = data.aws_ami.std07_lab_search_ami.id
}

data "aws_availability_zones" "available_az" {
  state = "available"
}
