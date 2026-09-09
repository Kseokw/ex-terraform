# secret-manager를 통한 보안 암호 생성
# - 기본 생성(Plain Text) / JSON형식으로 생성 / 랜덤 비밀번호로 생성
# 이렇게 생성하니까 JSON 형식인데 비밀번호만 띡 적혀있고 끝이네
# =========================================================================================
# # 보안 암호 생성
# resource "aws_secretsmanager_secret" "mysql_password" {
#   name = "project/db/password"
# }

# # 보안 암호에 실제 사용할 암호 정의
# resource "aws_secretsmanager_secret_version" "mysql_password_value" {
#   secret_id     = aws_secretsmanager_secret.mysql_password.id
#   secret_string = "12345678"
# }

# # JSON 형식으로 여러값 저장
# resource "aws_secretsmanager_secret_version" "mysql_password_value" {
#   secret_id = aws_secretsmanager_secret.mysql_password.id
#   secret_string = jsonencode({
#     username = "std07"
#     password = random_password.creat_random_password.result
#     database = "testdb"
#     port     = "3306"
#   })
# }

# # 랜덤한 비밀번호 생성: 반환속성(result)
# resource "random_password" "creat_random_password" {
#   length           = 16
#   special          = true                   # 특수문자 사용 여부
#   override_special = "!#$%&*()-_=+[]{}<>:?" # AWS에서 권장하는 특수문자
# }

# # 보안 암호 반환
# # sensitive = true 이 옵션을 넣어야 secret-manager 패스워드를 반환 받을 수 있음
# output "secret_db_password" {
#   # value     = aws_secretsmanager_secret_version.mysql_password_value.secret_string["password"]
#   # value     = jsondecode(aws_secretsmanager_secret_version.mysql_password_value.secret_string)["password"]
#   value     = random_password.creat_random_password.result
#   sensitive = true
# }
