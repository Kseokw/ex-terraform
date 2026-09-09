# 서브넷 그룹 생성
data "aws_subnets" "subnet_ids" {
  #   filter {
  #     name = "vpc-id"
  #     value = [<"vpc_id">]
  #   }

  filter {
    name = "tag:Name"
    values = [
      "std07-lab-priv-1a-subnet",
      "std07-lab-priv-1b-subnet",
      "std07-lab-priv-1c-subnet"
    ]
  }
}

# resource "aws_db_subnet_group" "std07_lab_db_subnet_group" {
#   name = "std07-lab-db-subnet-group"
#   subnet_ids = [
#     aws_subnet.std07_lab_priv_1a_subnet.id,
#     aws_subnet.std07_lab_priv_1b_subnet.id,
#     aws_subnet.std07_lab_priv_1c_subnet.id
#   ]
#   #   subnet_ids = data.aws_subnets.subnet_ids.ids
#   tags = { Name = "std07-lab-db-subnet-group" }
# }

# output "choice_subnets" {
#   value = data.aws_subnets.subnet_ids.ids
# }

# MySQL Instance 생성
# 이거랑 클러스터의 차이가 뭐야? 이거 만들어도 단일 클러스터로 RDS 생성 하더만
resource "aws_db_instance" "std07_lab_mysql_instance" {
  identifier        = "std07-mysql-instance"
  engine            = "mysql"
  engine_version    = "8.0"
  instance_class    = "db.t3.micro"
  allocated_storage = 20

  db_name  = jsondecode(aws_secretsmanager_secret_version.mysql_password_value.secret_string)["database"]
  username = jsondecode(aws_secretsmanager_secret_version.mysql_password_value.secret_string)["username"]
  password = jsondecode(aws_secretsmanager_secret_version.mysql_password_value.secret_string)["password"]

  db_subnet_group_name = aws_db_subnet_group.std07_lab_db_subnet_group.name
  availability_zone    = local.azs[0]
  # availability_zone = data.aws_availability_zones.available_az[0].name
  vpc_security_group_ids = [
    aws_security_group.std07_lab_mysql_sg.id
  ]
  # 백업(최소 7일)
  backup_retention_period = 7
  # instance를 삭제할 때 마지막 백업 스냅샷의 생성 여부
  skip_final_snapshot = true

  tags = { Name = "std07-mysql-instance" }
}
