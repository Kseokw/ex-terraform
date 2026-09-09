# 이미지 만들 인스턴스 생성
# resource "aws_instance" "std07_lab_instance" {
#   # ami
#   ami = "ami-03acbba64aef9bf5c"
#   # instance type
#   instance_type = "t3.nano"
#   # key pair, key_name
#   key_name = "std07-key"
#   # volume
#   root_block_device {
#     volume_size           = 20    # 단위 GB
#     volume_type           = "gp3" # 볼륨 타입(최신 가성비 타입인 gp3 권장)
#     delete_on_termination = true  # 인스턴스 삭제 시 볼륨도 함께 삭제(안정성을 고려하면 Flase 부여)
#     tags = {
#       Name = "std07-lab-volume"
#     }
#   }
#   # subnet
#   subnet_id = aws_subnet.std07_lab_public_1a_subnet.id
#   # 보안그룹
#   vpc_security_group_ids = [
#     aws_security_group.std07_lab_external_alb_sg.id
#   ]
#   # User Data
#   user_data = <<-EOF
#     #!/bin/bash
#     apt update -y
#     apt install -y nginx
#     systemctl enable nginx
#     systemctl restart nginx
#     echo "<h1>Hello from EC2 First Nginx</h1>" > /var/www/html/index.html
#     EOF

#   tags = {
#     Name = "std07-lab-instance"
#   }
# }

# output "instance_pubilc_id" {
#   value = aws_instance.std07_lab_instance.public_ip
# }


# # AMI 생성
# resource "aws_ami_from_instance" "std07_lab_nginx_ami" {
#   name               = "std07-lab-instance-ami"
#   source_instance_id = aws_instance.std07_lab_instance.id

#   # 재부팅하여 이미지 생성(권장): false
#   snapshot_without_reboot = false

#   tags = { Name = "std07-lab-nginx-ami" }
# }

# AMI 이미지 선택:

data "aws_ami" "std07_lab_search_ami" {
  most_recent = true
  owners      = ["self"] # 본인 AWS 계정에서 생성한 AMI를 검색할 경우 ("self")

  filter {
    name   = "tag:Name"
    values = ["std07-lab-nginx-ami"]
  }

  filter {
    name   = "tag:Class"
    values = ["bipa17"]
  }

  filter {
    name   = "tag:Owner"
    values = ["std07"]
  }
}

# 만든 이미지로 인스턴스 생성
# resource "aws_instance" "std07_lab_ami_instance" {
#   # ami
#   ami = data.aws_ami.std07_lab_search_ami.id
#   # instance type
#   instance_type = "t3.nano"
#   # key pair, key_name
#   key_name = "std07-key"
#   # volume
#   root_block_device {
#     volume_size           = 20    # 단위 GB
#     volume_type           = "gp3" # 볼륨 타입(최신 가성비 타입인 gp3 권장)
#     delete_on_termination = true  # 인스턴스 삭제 시 볼륨도 함께 삭제(안정성을 고려하면 Flase 부여)
#     tags = {
#       Name = "std07-lab-volume"
#     }
#   }
#   # subnet
#   subnet_id = aws_subnet.std07_lab_public_1a_subnet.id
#   # 보안그룹
#   vpc_security_group_ids = [
#     aws_security_group.std07_lab_external_alb_sg.id
#   ]
#   tags = {
#     Name = "std07-lab-ami-instance"
#   }
# }


# 시작 템플릿(Launch Template)
resource "aws_launch_template" "std07_lab_lt" {
  name_prefix   = "std07-lab-lt"
  image_id      = data.aws_ami.std07_lab_search_ami.id #local.azs
  instance_type = "t3.nano"

  vpc_security_group_ids = [
    aws_security_group.std07_lab_external_alb_sg.id
  ]

  # 이미 Nginx가 설치되어 있다면 서비스 시작 명령어만 넣어주면 안전합니다.
  # 인스턴스 생성할 때와 달리 base64code()를 통해 암호화 해야 합니다.
  user_data = base64encode(<<-EOF
    #!/bin/bash
    systemctl start nginx
    systemctl enable nginx
    EOF
  )

  tag_specifications {
    resource_type = "instance"
    tags          = { Name = "std07-lab-asg-instance" }
  }

  tag_specifications {
    resource_type = "volume"
    tags          = { Name = "std07-lab-asg-instance-vol" }
  }

  tags = { Name = "std07-lab-asg-lt" }
}
