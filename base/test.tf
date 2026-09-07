# ==============================================================
# count 반복문
# resource "aws_instance" "this" {
#   count         = 2
#   subnet_id     = aws_subnet.std07_public_1a_subnet.id
#   ami           = "ami-03acbba64aef9bf5c"
#   instance_type = "t3.nano"
#   tags = {
#     Name = "test${count.index + 1}_instance" # terrform은 0번부터 시작
#   }
# }
# # 만약 인스턴스가 1개 있는 상태로 실행하면 총 2대가 될수있게 1대만 추가 생성됨

# output "prt_instance" {
#   value = aws_instance.this[1].tags

# }
# # 실행결과
# # prt_instance = tomap({
# #   "Name" = "test2_instance"
# # })

# ==============================================================
# for_each
# set과 map만 가능 / set(set()) 불가능

# for_each문의 list/set 형태의 반복
# resource "aws_instance" "this" {
#   for_each      = toset(["logs", "media", "backups"])
#   subnet_id     = aws_subnet.std07_public_1a_subnet.id
#   ami           = "ami-03acbba64aef9bf5c"
#   instance_type = "t3.nano"
#   tags = {
#     Name = "test-${each.key}_instance"
#   }
# }

# output "prt_instance" {
#   value = aws_instance.this["media"].tags

# }
# 실행결과
# prt_instance = tomap({
#   "Name" = "test-media_instance"
# })

# output "prt_instance" {
#   value = { for k, v in aws_instance.this : k => v.tags["Name"] }
# }
# 실행결과
# prt_instance = {
#   "backups" = "test-backups_instance"
#   "logs" = "test-logs_instance"
#   "media" = "test-media_instance"
# }


# #=========================================
# #for_each문의 map형태의 반복
# resource "aws_instance" "this" {
#   for_each = {
#     "a" = "logs"
#     "b" = "media"
#     "c" = "backups"
#   }
#   subnet_id     = aws_subnet.std07_public_1a_subnet.id
#   ami           = "ami-03acbba64aef9bf5c"
#   instance_type = "t3.nano"
#   tags = {
#     Name = "test-${each.key}_instance" # each.value
#   }
# }

# output "prt_instance" {
#   value = aws_instance.this["b"].tags
# }
# #실행결과
# #prt_instance = tomap({
# #  "Name" = "test-b_instance"
# #})
