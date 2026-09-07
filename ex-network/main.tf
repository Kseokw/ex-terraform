resource "aws_vpc" "std07_lab_vpc" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true
  instance_tenancy     = "default"

  tags = {
    Name = "std07-lab-vpc"
  }
}

# 퍼블릭 서브넷 생성
resource "aws_subnet" "std07_lab_public_1a_subnet" {
  vpc_id            = aws_vpc.std07_lab_vpc.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "ap-southeast-1a"

  # Public Subnet 설정
  map_public_ip_on_launch                     = true # 퍼블릭 IPv4 주소 자동 할당
  enable_resource_name_dns_a_record_on_launch = true # 리소스 이름 DNS A 레코드

  tags = {
    Name = "std07-lab-public-1a-subnet"
  }
}

# Internet Gateway 생성
resource "aws_internet_gateway" "std07_lab_igw" {
  vpc_id = aws_vpc.std07_lab_vpc.id

  tags = {
    Name = "std07-lab-igw"
  }
}

# NAT Gateway 생성을 위한 EIP 생성
resource "aws_eip" "std07_lab_nat_eip" {
  domain = "vpc" # VPC용 EIP 생성, std07-nat-eip의 사용범위를 VPC로 제한
  # instance = "인스턴스용으로 사용할 경우 인스턴스의 ID"
  tags = {
    Name = "std07-lab-nat-eip"
  }
}
# NAT Gateway 생성
resource "aws_nat_gateway" "std07_lab_nat_gw" {
  allocation_id = aws_eip.std07_lab_nat_eip.id
  # NAT Gateway를 생성할 Public Subnet 지정
  subnet_id  = aws_subnet.std07_lab_public_1a_subnet.id
  depends_on = [aws_internet_gateway.std07_lab_igw] # NAT Gateway 생성 시점에 IGW가 생성되어 있으면 생성/의존성
  tags = {
    Name = "std07-lab-nat-gw"
  }
}

# 라우팅 테이블 생성
resource "aws_route_table" "std07_lab_public_rt" {
  vpc_id = aws_vpc.std07_lab_vpc.id
  route { # 라우팅테이블 생성하면서 라우팅 지정
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.std07_lab_igw.id
  }
  tags = {
    Name = "std07-lab-pulic-rt"
  }
}

# 2. 서브넷 연결
resource "aws_route_table_association" "std07_lab_public_rt_association" {
  subnet_id      = aws_subnet.std07_lab_public_1a_subnet.id
  route_table_id = aws_route_table.std07_lab_public_rt.id
}

# 보안그룹 생성
resource "aws_security_group" "std07_lab_external_alb_sg" {
  name        = "std07-lab-external-alb-sg"
  description = "Allow External ALB inbound traffic"
  vpc_id      = aws_vpc.std07_lab_vpc.id

  dynamic "ingress" {
    for_each = [22, 80, 443]
    content { # inbound 규칙
      from_port   = ingress.value
      to_port     = ingress.value
      protocol    = "tcp"
      cidr_blocks = ["0.0.0.0/0"]
    }
  }

  egress { # outbound 규칙
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # 모든 프로토콜 허용
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "std07-lab-external-alb-sg"
  }
}

# NACL
# 서브넷 전용 방화벽
# - 서브넷 단위로 규칙 적용
# - 규칙 번호 기반 순위 평가: 100번에서 막고 200번에서 열어주면 결론은 막힘
# - 상태를 기억하지 않음: inbound 를 허용해도 outbound 규칙이 없으면 못나감
resource "aws_network_acl" "std07_lab_nacl" {
  vpc_id = aws_vpc.std07_lab_vpc.id
  ingress {
    rule_no    = 103 # rule_no는 중복되지 않게 작성
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 22
    to_port    = 22
  }
  ingress {
    rule_no    = 100 # rule_no는 중복되지 않게 작성
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }
  ingress {
    rule_no    = 101 # rule_no는 중복되지 않게 작성
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }
  # [추가] 돌아오는 응답을 받기 위한 임시 포트 허용
  ingress {
    rule_no    = 102
    protocol   = "tcp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }
  # ICMP (Ping 등) 허용 규칙
  ingress {
    rule_no    = 104
    protocol   = "icmp"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
    # 포트 대신 ICMP 타입과 코드 지정 (전체 허용은 -1)
    icmp_type = -1
    icmp_code = -1
  }
  egress {
    rule_no    = 100 # rule_no는 중복되지 않게 작성(ingress, egress 규칙번호 중첩 가능, 따로 적용됨)
    protocol   = "-1"
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }
  tags = {
    Name = "std07-lab-nacl"
  }
}

# NACL - subnet 연결
resource "aws_network_acl_association" "std07_lab_nacl_assoc" {
  subnet_id      = aws_subnet.std07_lab_public_1a_subnet.id
  network_acl_id = aws_network_acl.std07_lab_nacl.id
}
