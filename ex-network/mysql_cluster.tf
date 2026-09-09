# Lambda Function에서 사용할 보안 그룹
resource "aws_security_group" "std07_lambda_sg" {
  name        = "std07-lambda-sg"
  description = "Security group for Lambda Funtion access"
  vpc_id      = aws_vpc.std07_lab_vpc.id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "std07-lambda-sg"
  }

}

# ===========================================================================================
# 보안암호 생성
# ASM 생성
resource "aws_secretsmanager_secret" "mysql_password" {
  description = "RDS 비밀번호"
  name        = "project/db/password"
}

resource "aws_secretsmanager_secret_version" "mysql_password_value" {
  secret_id = aws_secretsmanager_secret.mysql_password.id
  secret_string = jsonencode({
    # 반드시아래 JSON형싱(KEY명 포함)을 유지할 것
    engine   = "mysql"
    host     = aws_rds_cluster.mysql_cluster.endpoint # DB 생성 완료 후 엔드포인트가 자동 주입 됨
    username = "std07"
    password = random_password.creat_random_password.result
    database = "testdb"
    port     = "3306"
  })
}

# # 랜덤한 비밀번호 생성: 반환속성(result)
resource "random_password" "creat_random_password" {
  length           = 16
  special          = true                   # 특수문자 사용 여부
  override_special = "!#$%&*()-_=+[]{}<>:?" # AWS에서 권장하는 특수문자
}

# 보안암호 삭제 필요 시 사용할 aws cli 명령어
# aws secretsmanager delete-secret
#     --secret-id "project/mysql/password"
#     --force-delete-without-recovery

# ===========================================================================================
# RDS Secrets Manager Automatic Rotation (00일 주기 자동 변경) - cloudFormation
# 1. CloudFormation의 스택을 배포하는 리소스 생성
resource "aws_serverlessapplicationrepository_cloudformation_stack" "mysql_rotation" {
  # CloudFormation의 스택 이름
  name = "rds-mysql-cluster-rotation-stack"
  # 비밀번호 변경에 사용할 원본(기준) 함수(애플리케이션)의 ARN(us-east-1로 arn 값 고정)
  application_id = "arn:aws:serverlessrepo:us-east-1:297356227824:applications/SecretsManagerRDSMySQLRotationSingleUser"

  # CloudFormation이 IAM 생성 및 리소스 정책을 정의 할 수 있도록 승인하는 권한 설정
  capabilities = ["CAPABILITY_IAM", "CAPABILITY_RESOURCE_POLICY"]

  # Lambda 함수 동작에 필요한 설정(Parameter)
  parameters = {
    # 람다함수 이름
    functionName = "std07-lab-rds-mysql-cluster-function-fn"
    # 보안 암호(secrets  Manager)의 Endpoint 정의
    endpoint = "https://secretsmanager.ap-southeast-1.amazonaws.com"

    # Lambda 함수가 접속해야할 데이터베이스가 포함된 서브넷의 ID정의
    vpcSubnetIds = join(",", [
      aws_subnet.std07_lab_priv_1a_subnet.id,
      aws_subnet.std07_lab_priv_1b_subnet.id,
      aws_subnet.std07_lab_priv_1c_subnet.id
    ])

    vpcSecurityGroupIds = aws_security_group.std07_lambda_sg.id
  }
}

# 2. Secrets Manager에 저장된 암호를 지정된 주기 및 람다 함수를 연결하는 리소스 생성
# 이걸하면 7일 주기로 바뀌는게 무엇 무엇인가요?
resource "aws_secretsmanager_secret_rotation" "mysql_secret_rotation" {
  # 바꿀 대상(보안 암호) 지정
  # 시크릿_id에는 이름만 명명해준건데 암호랑 다 들고오나 보네. 얘네 생각보다 유기적으로 연견된다?
  secret_id = aws_secretsmanager_secret.mysql_password.id

  # 사용할 람다 함수 정의
  rotation_lambda_arn = aws_serverlessapplicationrepository_cloudformation_stack.mysql_rotation.outputs.RotationLambdaARN

  # 규칙 정의
  rotation_rules {
    automatically_after_days = 7 # 7일
  }
}



# ===========================================================================================
# RDS Cluster 구성
# 1. 서브넷 그룹 생성

resource "aws_db_subnet_group" "std07_lab_db_subnet_group" {
  name = "std07-lab-db-subnet-group"
  subnet_ids = [
    aws_subnet.std07_lab_priv_1a_subnet.id,
    aws_subnet.std07_lab_priv_1b_subnet.id,
    aws_subnet.std07_lab_priv_1c_subnet.id
  ]
  #   subnet_ids = data.aws_subnets.subnet_ids.ids
  tags = { Name = "std07-lab-db-subnet-group" }
}

# 2. MySQL Cluster 생성: RDS Multi-AZ DB Cluster
# 주의 1: Engine의 버전은 반드시 콘솔 창 Cluster 구성에서 사용할 수 있는 버전으로 지정해야 함.
# 볼륨 Type(gp3/io1)
# 볼륨 타입을 gp3를 사용할 경우 400GiB 이하의 경우 iops를 주석처리
# 수정(업데이트)의 경우 변경하지 못하게 lifecycle 설정 필요(변경 설정 무시)

# 이거랑 aws_db_instance의 차이가 뭐야?
# 똑같이 RDS 만드는거아닌가?
# 콘솔 창에서는 배포 옵션으로 클러스터 개수를 지정할 수 있는데 이건 왜 지정 안해?
resource "aws_rds_cluster" "mysql_cluster" {
  cluster_identifier        = "rds-mysql-multi-az-cluster"
  engine                    = "mysql"
  engine_version            = "8.4.9"
  db_cluster_instance_class = "db.m5d.large"

  # 볼륨 설정
  storage_type      = "gp3"
  allocated_storage = 100
  # iops = 3000
  # throughput = 125

  # 왜 여기서는 위에 만든 ASM 안쓰고 random_password 리소스를 쓰지?
  database_name   = "tsetdb"
  master_username = "std07"
  master_password = random_password.creat_random_password.result

  db_subnet_group_name   = aws_db_subnet_group.std07_lab_db_subnet_group.name
  vpc_security_group_ids = [aws_security_group.std07_lab_mysql_sg.id]
  skip_final_snapshot    = true # 연습일 땐 생성하지 않기 위해 true / 실전에서는 False

  # 수정할 때 볼륨으로 인한 에러 발생
  # 이에 최초 생성 이외 apply 때 볼륨 변경을 무시하기 위한 설정
  lifecycle {
    ignore_changes = [
      storage_type,
      allocated_storage,
      iops
    ]
  }

  tags = { Name = "rds-mysql-multi-az-cluster" }
}
