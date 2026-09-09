# 대상그룹 생성
resource "aws_lb_target_group" "sta07_lab_lb_nginx_tg" {
  name     = "std07-lab-nginx-tg"
  protocol = "HTTP"
  port     = 80 # 내부 웹서버의 실행 포트번호
  vpc_id   = aws_vpc.std07_lab_vpc.id

  # 인스턴스 연결 대시 시간 정의
  slow_start = 30 # 초
  # 인스턴스 종료(삭제)시 연결 유지 시간
  deregistration_delay = 60

  # 헬스 체크
  health_check {
    protocol = "HTTP"
    path     = "/"
    port     = "traffic-port" # 기본값으로 위 서비스의 포트번호를 따라감.

    healthy_threshold   = 3  # 3번 연속 성공하면 '정상'
    unhealthy_threshold = 3  # 3번 연속 실패하면 '비정상'
    timeout             = 5  # 제한 시간
    interval            = 15 # 간격


  }
  tags = {
    Name = "std07-lab-nginx-tg"
  }
}

# # 대상그룹에 대한 (인스턴스)등록: aws_lb_target_group_attachment
# resource "aws_lb_target_group_attachment" "std07_lab_tg_atta1" {
#   target_group_arn = <타겟그룹 arn>
#   target_id = <인스턴스_id>
#   port = <port_number>
# }

# ===================================================================
# ALB
# alb 생성
resource "aws_lb" "std07_lab_alb" {
  load_balancer_type = "application" # application / network / gateway

  name     = "std07-lab-alb"
  internal = "false" # 내부false / 외부 true
  subnets = [
    aws_subnet.std07_lab_public_1a_subnet.id,
    aws_subnet.std07_lab_public_1b_subnet.id
  ]
  security_groups = [
    aws_security_group.std07_lab_external_alb_sg.id
  ]
  tags = { Name = "std07-lab-alb" }
}

# 로드밸런서에 리스너 생성 및 추가
resource "aws_lb_listener" "std07_lab_lb_http_lis" {
  load_balancer_arn = aws_lb.std07_lab_alb.arn
  protocol          = "HTTP"
  port              = 80 # 사용자(외부/브라우저) 포트번호
  default_action {
    type             = "forward" # 전달/승계(대상그룹), redirect, fixed-respons(erroe 대응 페이지)
    target_group_arn = aws_lb_target_group.sta07_lab_lb_nginx_tg.arn
  }
  # # 에러 유형에 대한 대응 페이지로 리다이렉트
  # default_action {
  #   type = "fixed-response"
  #   fixed_response {
  #     content_type = "text/html"
  #     status_code  = "503"
  #     message_body = <<-EOF
  #       ~ HTML TAG ~
  #     EOF
  #   }
  # }
}
# 리스너에 경로 규칙 추가
resource "aws_lb_listener_rule" "std07_lab_lb_http_lis_rule" {
  listener_arn = aws_lb_listener.std07_lab_lb_http_lis.arn
  # 1~50, 000사이의 규칙 우선순위 지정, 낮을수록 우선순위가 높음
  priority = 100
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.sta07_lab_lb_nginx_tg.arn
  }
  # URL 경로 변환
  transform {
    type = "url-rewrite"
    url_rewrite_config {
      rewrite {
        regex   = "^/api/?(.*)" # 이미지의 정규식
        replace = "/$1"         # 교체 값
      }
    }
  }

  # [라우팅 조건] URL경로 정의
  condition {
    path_pattern {
      values = ["/api", "apt/*"]
    }
  }
  tags = { Name = "std07-lab-lb-http-lis-rule" }
}

resource "aws_lb_listener" "std07_lab_lb_https_lis" {
  load_balancer_arn = aws_lb.std07_lab_alb.arn
  protocol          = "HTTPS"
  port              = 443 # 사용자(외부/브라우저) 포트번호

  ssl_policy      = "ELBSecurityPolicy-TLS13-1-2-Res-PQ-2025-09"                                               # 권장 SSL 보안 정책
  certificate_arn = "arn:aws:acm:ap-southeast-1:925047940866:certificate/4fc0890f-787e-4e98-9ee4-19efc2fda5ad" # data로 가져오는 방식으로 수정 필요

  default_action {
    type             = "forward" # 전달/승계(대상그룹), redirect, fixed-respons(erroe 대응 페이지)
    target_group_arn = aws_lb_target_group.sta07_lab_lb_nginx_tg.arn
  }
}

# 리스너에 경로 규칙 추가
resource "aws_lb_listener_rule" "std07_lab_lb_https_lis_rule" {
  listener_arn = aws_lb_listener.std07_lab_lb_https_lis.arn
  # 1~50, 000사이의 규칙 우선순위 지정, 낮을수록 우선순위가 높음
  priority = 100
  action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.sta07_lab_lb_nginx_tg.arn
  }
  # URL 경로 변환
  transform {
    type = "url-rewrite"
    url_rewrite_config {
      rewrite {
        regex   = "^/api/?(.*)" # 이미지의 정규식
        replace = "/$1"         # 교체 값
      }
    }
  }

  # [라우팅 조건] URL경로 정의
  condition {
    path_pattern {
      values = ["/api", "apt/*"]
    }
  }
  tags = { Name = "std07-lab-lb-https-lis-rule" }
}

# ============================================================
# AutoScaling Group
# ASG 생성: aws_autoscaling_group
resource "aws_autoscaling_group" "std07_lab_nginx_asg" {
  name             = "std07-lab-nginx-tg"
  min_size         = 1
  max_size         = 3
  desired_capacity = 1

  #네트워크 
  vpc_zone_identifier = [
    aws_subnet.std07_lab_public_1a_subnet.id,
    aws_subnet.std07_lab_public_1b_subnet.id
  ]

  # 대상 그룹
  target_group_arns = [aws_lb_target_group.sta07_lab_lb_nginx_tg.arn]

  # 시작 템플릿 구성
  launch_template {
    id      = aws_launch_template.std07_lab_lt.id
    version = "$Latest"
  }

  # 헬스 체크
  health_check_type         = "EC2" # ELB
  health_check_grace_period = 300


  # tags = {Name = "std07-lab-nginx-asg"}
  tag {
    key                 = "Name"
    value               = "std07-lab-nginx-asg"
    propagate_at_launch = false # EC2 인스턴스에도 동일한 태그를 적용하는지?
  }
}

# ASG Policy 생성: aws_autoscaling_policy
# 인스턴스 수량 조정 기준
resource "aws_autoscaling_policy" "std07_asg_policy" {
  name                   = "std07-asg-policy"
  autoscaling_group_name = aws_autoscaling_group.std07_lab_nginx_asg.name

  policy_type = "TargetTrackingScaling" # 대상 추적 방식

  target_tracking_configuration {
    predefined_metric_specification {
      predefined_metric_type = "ASGAverageCPUUtilization" # CPU 사용률 기준
    }
    target_value = 50.0 # 인스턴스 조정 시 CPU 사용률 기준(50~70 권장)
  }
}

# ASG 예약 정책
# 1. 평일 아침 8시 30분: 인스턴스 확장(Scale-out)
resource "aws_autoscaling_schedule" "scale_out_moring" {
  scheduled_action_name  = "std07-scale-out-moring"
  autoscaling_group_name = aws_autoscaling_group.std07_lab_nginx_asg.name

  # 인스턴스 수량 설정
  min_size         = 2
  max_size         = 5
  desired_capacity = 4

  # 실행주기 (Cron 표현식: 분 시 일 월 요일)
  # KST(UTC+9)
  recurrence = "08 13 * * 1-5" # 월금 KST 12:35
  time_zone  = "Asia/Seoul"
}

resource "aws_autoscaling_schedule" "scale_in_moring" {
  scheduled_action_name  = "std07-scale-in-moring"
  autoscaling_group_name = aws_autoscaling_group.std07_lab_nginx_asg.name

  # 인스턴스 수량 설정
  min_size         = 1
  max_size         = 2
  desired_capacity = 1

  # 실행주기 (Cron 표현식: 분 시 일 월 요일)
  # KST(UTC+9)
  recurrence = "15 12 * * 1-5" # 월금 KST 12:35
  time_zone  = "Asia/Seoul"

}
