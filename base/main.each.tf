# ========================================================
# VPC 생성
resource "aws_vpc" "std07_vpc" {
  cidr_block           = "10.0.0.0/16"
  instance_tenancy     = "default"
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags = {
    Name = "${local.tag_header}vpc"
  }
}

# =======================================================
# Public Subnet 생성
# 자동
resource "aws_subnet" "std07_public_subnet" {
  for_each          = toset(local.azs)
  vpc_id            = aws_vpc.std07_vpc.id
  cidr_block        = var.subnet_cidr[0][each.key] # var.subnet_cidr [0]행 [each.key]의 값
  availability_zone = each.key                     # [each.key] 값 자체

  # Public Subnet 설정
  map_public_ip_on_launch                     = true # 퍼블릭 IPv4 주소 자동 할당
  enable_resource_name_dns_a_record_on_launch = true # 리소스 이름 DNS A 레코드

  tags = {
    Name = "${local.tag_header}public-${split("-", each.key)[length(split("-", each.key)) - 1]}-subnet"
  }
}

# =========================================================
# Private Subnet 생성
# 자동
resource "aws_subnet" "std07_private_subnet" {
  for_each          = toset(local.azs)
  vpc_id            = aws_vpc.std07_vpc.id
  cidr_block        = var.subnet_cidr[1][each.key] # var.subnet_cidr [0]행 [each.key]의 값(value)
  availability_zone = each.key                     # [each.key] 값 자체

  tags = {
    Name = "${local.tag_header}private-${split("-", each.key)[length(split("-", each.key)) - 1]}-subnet"
  }
}

# =========================================================
# Gateway 생성
# Internet Gateway 생성
resource "aws_internet_gateway" "std07_igw" {
  vpc_id = aws_vpc.std07_vpc.id

  tags = {
    Name = "${local.tag_header}igw"
  }
}

# NAT Gateway 생성을 위한 EIP 생성
resource "aws_eip" "std07_nat_eip" {
  domain = "vpc" # VPC용 EIP 생성, std07-nat-eip의 사용범위를 VPC로 제한

  tags = {
    Name = "${local.tag_header}nat-eip"
  }
}
# NAT Gateway 생성
resource "aws_nat_gateway" "std07_nat_gw" {
  allocation_id = aws_eip.std07_nat_eip.id
  # NAT Gateway를 생성할 Public Subnet 지정
  subnet_id  = aws_subnet.std07_public_subnet[local.azs[0]].id
  depends_on = [aws_internet_gateway.std07_igw] # NAT Gateway 생성 시점에 IGW가 생성되어 있으면 생성/의존성
  tags = {
    Name = "${local.tag_header}nat-gw"
  }
}
# =========================================================
# Route Table 생성
# public Route Table 생성
# 1. 생성
resource "aws_route_table" "std07_public_rt" {
  vpc_id = aws_vpc.std07_vpc.id

  tags = {
    Name = "${local.tag_header}pulic-rt"
  }
}

# 2. 서브넷 연결
resource "aws_route_table_association" "std07_public_rt_association" {
  for_each       = toset(local.azs)
  subnet_id      = aws_subnet.std07_public_subnet[each.key].id
  route_table_id = aws_route_table.std07_public_rt.id
}



# 3. 라우팅
resource "aws_route" "std07_public_rt_route" {
  route_table_id         = aws_route_table.std07_public_rt.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.std07_igw.id
}

# =========================================================
# # private Route Table 생성
resource "aws_route_table" "std07_private_rt" {
  for_each = toset(local.azs)
  vpc_id   = aws_vpc.std07_vpc.id

  tags = {
    Name = "${local.tag_header}private-${each.key}-rt"
  }
}


# 2. 서브넷 연결
resource "aws_route_table_association" "std07_private_rt_association" {
  for_each       = toset(local.azs)
  subnet_id      = aws_subnet.std07_private_subnet[each.key].id
  route_table_id = aws_route_table.std07_private_rt[each.key].id
}


# 3. 라우팅
resource "aws_route" "std07_private_rt_route" {
  for_each               = toset(local.azs)
  route_table_id         = aws_route_table.std07_private_rt[each.key].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_nat_gateway.std07_nat_gw.id
}


# =========================================================
# Security Group 생성

# SSH 접속용
resource "aws_security_group" "std07_ssh_sg" {
  name        = "${local.tag_header}ssh-sg"
  description = "Allow SSH inbound traffic" # 설명란
  vpc_id      = aws_vpc.std07_vpc.id

  ingress {          # inbound 규칙
    from_port   = 22 # 시작포트 번호
    to_port     = 22 # 종료포트 번호 (22~22)
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress { # outbound 규칙
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # 모든 프로토콜 허용
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${local.tag_header}ssh-sg"
  }
}

# alb 접속용
resource "aws_security_group" "std07_external_alb_sg" {
  name        = "${local.tag_header}external-alb-sg"
  description = "Allow External ALB inbound traffic"
  vpc_id      = aws_vpc.std07_vpc.id

  ingress { # inbound 규칙
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress { # inbound 규칙
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress { # outbound 규칙
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # 모든 프로토콜 허용
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${local.tag_header}external-alb-sg"
  }
}

# 프라이빗 웹 인스턴스용 보안그룹
resource "aws_security_group" "std07_internal_alb_sg" {
  name        = "${local.tag_header}internal-alb-sg"
  description = "Allow Internal ALB inbound traffic"
  vpc_id      = aws_vpc.std07_vpc.id

  egress { # outbound 규칙
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # 모든 프로토콜 허용
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${local.tag_header}internal-alb-sg"
  }
}

# MySQL 접속용
resource "aws_security_group" "std07_mysql_sg" {
  name        = "${local.tag_header}mysql-sg"
  description = "Allow MySQL inbound traffic"
  vpc_id      = aws_vpc.std07_vpc.id

  ingress { # inbound 규칙
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress { # outbound 규칙
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # 모든 프로토콜 허용
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${local.tag_header}mysql-sg"
  }
}

# 내부만 허용하는 Mysql 보안그룹 생성
resource "aws_security_group" "std07_internal_mysql_sg" {
  name        = "${local.tag_header}internal-mysql-sg"
  description = "Allow internal MySQL inbound traffic"
  vpc_id      = aws_vpc.std07_vpc.id

  egress { # outbound 규칙
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # 모든 프로토콜 허용
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "${local.tag_header}internal-mysql-sg"
  }
}

# 내부 ALB에서 MySQL로 트래픽 허용 규칙 추가
resource "aws_security_group_rule" "std07_internal_mysql_rule" {
  type      = "ingress"
  from_port = 3306
  to_port   = 3306
  protocol  = "tcp"
  # 규칙을 추가할 보안 그룹의 아이디
  security_group_id = aws_security_group.std07_internal_mysql_sg.id
  # 소스로 어떤 보안 그룹을 추가할지 추가할 보안 그룹의 아이디
  source_security_group_id = aws_security_group.std07_internal_alb_sg.id
}

# =====================================================
# 테라폼은 선언형 언어, IF 문이 없다.
# if문을 대체하는 삼항연산자를 통해 간단히 제어만 가능
# 조건 ? 참 표현값 : 거짓 표현값
# 조건1 ? 조건1 참 표현값 : (
#        조건 2 ? 조건2 참 표현값 : 조건 2 거짓 표현값)

resource "aws_instance" "std07-instance" {
  count     = local.instance_chk ? 1 : 0
  subnet_id = aws_subnet.std07_public_subnet[local.azs[0]].id
  # subnet_id = aws_subnet.std07_public_subnet[local.azs[count.index % length(local.azs)]].id
  ami           = "ami-03acbba64aef9bf5c"
  instance_type = "t3.nano"
  tags = {
    Name = "test${count.index + 1}_instance" # terrform은 0번부터 시작
  }
}

# ======================================================
# 중첩 삼항 연산자
locals {
  instance_type = "default" # "nano, micro, small"
}

resource "aws_instance" "test-instance" {
  subnet_id = aws_subnet.std07_public_subnet[local.azs[0]].id
  ami       = "ami-03acbba64aef9bf5c"
  instance_type = local.instance_type == "default" ? "t3.nano" : (
  local.instance_type == "micro" ? "t3.micro" : "t3.small")
  tags = {
    Name = "test_instance" # terrform은 0번부터 시작
  }
}

# ======================================================
# 문자열 함수
output "zfunc_string" {
  value = "ABcd"
}
output "zfunc_string_upper" {
  value = upper("ABcd")
}
output "zfunc_string_lower" {
  value = lower("ABcd")
}
output "zfunc_string_replace" {
  value = replace("abcdb", "bc", "k") # 값, 찾을 값, 변경 값
}

# 문자열 나누기
# 전체 문자열에서 특정 문자를 기준으로 나누어 리스트로 변환
output "zfunc_string_split" {
  value = split("-", "ap-southeast-a1")[length(split("-", "ap-southeast-a1")) - 1]
}

# 리스트의 각 요소를 지정 문자를 이용하여 연결
output "zfunc_string_join" {
  value = join("*", ["ap", "south", "1a"])
}

output "zfunc_string_join2" {
  value = join("*", split("-", "ap-southeast-1a"))
}

# for 표현식
output "for" {
  value = [for num in [1, 2, 23, 4, 5, 6, 7, 9] : num if num % 2 == 0]
}
