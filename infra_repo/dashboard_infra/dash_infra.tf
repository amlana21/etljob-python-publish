terraform {
  required_providers {
    aws = {
      source = "hashicorp/aws"
    }
  }

  backend "s3" {
    bucket = "<state_file_name>"
    key    = "etlinfrastate"
    region = "us-east-1"
  }
}

provider "aws" {
  region = "us-east-1"
}




resource "aws_vpc" "etlvpc" {
  cidr_block = "10.0.0.0/16"
  enable_dns_hostnames = true

  tags = {
    Name = "etlvpc"
  }
}

resource "aws_internet_gateway" "etl_gw" {
  vpc_id = resource.aws_vpc.etlvpc.id

  tags = {
    Name = "etl_gw"
  }

}

resource "aws_network_acl" "etl_public_nacl" {
  vpc_id = resource.aws_vpc.etlvpc.id

  subnet_ids =[resource.aws_subnet.etl_subnet.id]

  egress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 22
    to_port    = 22
  }

  egress {
    protocol   = "tcp"
    rule_no    = 200
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  egress {
    protocol   = "tcp"
    rule_no    = 300
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  egress {
    protocol   = "-1"
    rule_no    = 400
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 0
    to_port    = 0
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 100
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 22
    to_port    = 22
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 200
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 80
    to_port    = 80
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 300
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 443
    to_port    = 443
  }

  ingress {
    protocol   = "tcp"
    rule_no    = 400
    action     = "allow"
    cidr_block = "0.0.0.0/0"
    from_port  = 1024
    to_port    = 65535
  }

  tags = {
    Name = "etl_nacl"
  }

  
}

resource "aws_security_group" "etl_sg" {
  name        = "etl_sg"
  description = "sg for etl dashboard"
  vpc_id      = resource.aws_vpc.etlvpc.id

  ingress {
    protocol   = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    from_port  = 22
    to_port    = 22
  }

  ingress {
    protocol   = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    from_port  = 80
    to_port    = 80
  }

  ingress {
    protocol   = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
    from_port  = 443
    to_port    = 443
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "etl_sg"
  }
}

resource "aws_route_table" "etl_rt" {
  vpc_id = resource.aws_vpc.etlvpc.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = resource.aws_internet_gateway.etl_gw.id
  }

  tags = {
    Name = "etl_rt"
  }
}

resource "aws_subnet" "etl_subnet" {
  vpc_id     = resource.aws_vpc.etlvpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true

  tags = {
    Name = "etl_subnet"
  }
}

resource "aws_subnet" "etl_subnet_2" {
  vpc_id     = resource.aws_vpc.etlvpc.id
  cidr_block = "10.0.2.0/24"
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = true

  tags = {
    Name = "etl_subnet_2"
  }
}

resource "aws_route_table_association" "etl_subnet_assoc" {
  subnet_id      = resource.aws_subnet.etl_subnet.id
  route_table_id = resource.aws_route_table.etl_rt.id
}

resource "aws_route_table_association" "etl_subnet_assoc_2" {
  subnet_id      = resource.aws_subnet.etl_subnet_2.id
  route_table_id = resource.aws_route_table.etl_rt.id
}

resource "aws_key_pair" "deployer" {
  key_name   = "etl-dash-instance-key"
  public_key = "key_content"
}

resource "aws_network_interface" "etl_instance_eni" {
  subnet_id       = resource.aws_subnet.etl_subnet.id
  security_groups = [resource.aws_security_group.etl_sg.id]


  
}

resource "aws_instance" "etl_dash_instance" {
  ami           = "ami-0e472ba40eb589f49" # us-east-1
  instance_type = "t2.small"

  network_interface {
    network_interface_id = resource.aws_network_interface.etl_instance_eni.id
    device_index         = 0
  }

  availability_zone = "us-east-1a"
  key_name = resource.aws_key_pair.deployer.key_name

  provisioner "file" {
    source      = "./setu_script.sh"
    destination = "/tmp/setu_script.sh"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod +x /tmp/setu_script.sh",
      "sudo /tmp/setu_script.sh",
    ]
  }

  # Login to the ec2-user with the aws key.
  connection {
    type        = "ssh"
    user        = "ubuntu"
    password    = ""
    private_key = file("key_file")
    host        = self.public_ip
  }



}


//load baancer deploy

resource "aws_acm_certificate" "etl_cert" {
  domain_name       = "<custom_domain>"
  validation_method = "DNS"

  tags = {
    APP = "ETL_JOB"
  }
}


resource "aws_lb_target_group" "etl_lb_tg" {
  name     = "etllbtg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = resource.aws_vpc.etlvpc.id

  health_check{
    path = "/setup"
    port  = 80    
  }
}

resource "aws_lb_target_group_attachment" "etl_lb_tg_targets" {
  target_group_arn = aws_lb_target_group.etl_lb_tg.arn
  target_id        = resource.aws_instance.etl_dash_instance.id
  port             = 80
}

resource "aws_lb" "etl_alb" {
  name               = "etlalb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [resource.aws_security_group.etl_sg.id]
  subnets            = [resource.aws_subnet.etl_subnet.id,resource.aws_subnet.etl_subnet_2.id]

  enable_deletion_protection = true
}

resource "aws_lb_listener" "etl_listener_1" {
  load_balancer_arn = resource.aws_lb.etl_alb.arn
  port              = "443"
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = resource.aws_acm_certificate.etl_cert.arn

  default_action {
    type             = "forward"
    target_group_arn = resource.aws_lb_target_group.etl_lb_tg.arn
  }
}

resource "aws_lb_listener" "etl_listener_2" {
  load_balancer_arn = resource.aws_lb.etl_alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = resource.aws_lb_target_group.etl_lb_tg.arn
  }
}



resource "aws_ami_from_instance" "etl_inst_ami" {
  name               = "etl_inst_ami"
  source_instance_id = resource.aws_instance.etl_dash_instance.id
}

resource "aws_launch_configuration" "etl_launch_conf" {
  name_prefix   = "etl_launch_conf-"
  image_id      = resource.aws_ami_from_instance.etl_inst_ami.id
  instance_type = "t2.small"
  key_name = resource.aws_key_pair.deployer.key_name
  security_groups = [resource.aws_security_group.etl_sg.id]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "etl_asg" {
  name                 = "etl_asg"
  launch_configuration = resource.aws_launch_configuration.etl_launch_conf.name
  min_size             = 1
  max_size             = 3
  desired_capacity          = 2
  vpc_zone_identifier       = [resource.aws_subnet.etl_subnet.id, resource.aws_subnet.etl_subnet_2.id]

  target_group_arns =[resource.aws_lb_target_group.etl_lb_tg.arn]
  health_check_type = "ELB"

 
}


