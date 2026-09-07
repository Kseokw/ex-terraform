resource "aws_instance" "std07_lab_instance" {
  # ami
  ami = "ami-03acbba64aef9bf5c"
  # instance type
  instance_type = "t3.nano"
  # key pair, key_name
  key_name = "std07-key"
  # volume
  root_block_device {
    volume_size           = 20    # 단위 GB
    volume_type           = "gp3" # 볼륨 타입(최신 가성비 타입인 gp3 권장)
    delete_on_termination = true  # 인스턴스 삭제 시 볼륨도 함께 삭제(안정성을 고려하면 Flase 부여)
    tags = {
      Name = "std07-lab-volume"
    }
  }
  # subnet
  subnet_id = aws_subnet.std07_lab_public_1a_subnet.id
  # 보안그룹
  vpc_security_group_ids = [
    aws_security_group.std07_lab_external_alb_sg.id
  ]
  # User Data
  user_data = <<-EOF
    #!/bin/bash
    apt update -y
    apt install -y nginx
    systemctl enable nginx
    systemctl restart nginx
    echo "<h1>Hello from EC2 First Nginx</h1>" > /var/www/html/index.html
    EOF

  tags = {
    Name = "std07-lab-instance"
  }
}

output "instance_pubilc_id" {
  value = aws_instance.std07_lab_instance.public_ip
}


# AMI 생성
resource "aws_ami_from_instance" "std07_lab_nginx_ami" {
  name               = "std07-lab-instance-ami"
  source_instance_id = aws_instance.std07_lab_instance.id

  # 재부팅하여 이미지 생성(권장): false
  snapshot_without_reboot = false

  tags = { Name = "std07-lab-nginx-ami" }
}


