terraform {
    required_providers {
        aws = {
            source = "hashicorp/aws"
        }
    }
}
provider "aws" {
    region = "ap-south-1"
    profile = "default"
}
resource "aws_vpc" "asgvpc" {
    cidr_block = "172.68.0.0/16"
    tags = {
        Name = "scalingvpc"
    }
}
resource "aws_subnet" "asgprivatesub1" {
    vpc_id = "aws_vpc.asgvpc.vpc_id"
    availability_zone = "ap-south-1a"
    cidr_block = "172.68.1.0/24"
    }
resource "aws_subnet" "asgprivatesub2" {
    vpc_id = "aws_vpc.asgvpc.vpc_id"
    availability_zone = "ap-south-2a"
    cidr_block = "172.68.2.0/24"
}
resource "aws_security_group" "sshsg" {
    vpc_id = "aws_vpc.asgvpc.id"
    ingress {
        from_port = 22
        to_port = 22
        protocol = "ssh"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
}
resource "aws_security_group" "asgsg" {
    vpc_id = "aws_vpc.asgvpc.vpc_id"
    ingress {
        from_port =8080
        to_port = 8081
        protocol = "ssh"
        cidr_blocks = ["0.0.0.0/0"]
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }
    tags = {
        Name = "ASG_sg"
    }
}
resource "aws_internet_gateway" "AsgIg" {
    vpc_id = "aws_vpc.asgvpc.id"
    tags = {
        Name : "AsgIg"
    }

}
 resource "aws_route_table" "Asgrt" {
    vpc_id = "aws_vpc.Asgvpc.id"
    route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.AsgIg.id
    }
 }
 resource "aws_route_table_association" "Asgroute_association" {
    route_table_id = aws_route_table.Asgrt.id
    subnet_id = aws_subnet.asgprivatesub1.id 
 }
 resource "aws_instance" "Asgec2" {
    subnet_id = "aws_subnet.asgprivatesub1.id"
    instance_type = "t2.micro"
    ami = "ami-00af37d1144686454"
    vpc_security_group_ids = [aws_security_group.sshsg.id]
     }
resource "aws_lb_target_group" "AsgTg" {
  name     = "Asgtg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = "aws_vpc.Asgvpc.id"

}
resource "aws_lb" "Asglb" {
        name = "Asg-lb-tf"
        internal = true 
        load_balancer_type = "application"
        subnet_mapping {
            subnet_id            = aws_subnet.asgprivatesub1.id
       }
       subnet_mapping {
            subnet_id            = aws_subnet.asgprivatesub2.id
            }
  enable_deletion_protection = false
  }
  resource "aws_lb_listener" "Asglr" {
  load_balancer_arn = aws_lb.Asglb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.AsgTg.arn
  }
}
resource "aws_launch_configuration" "Asglc" {
  name_prefix     = "learn-terraform-aws-asg-"
  image_id        = data.aws_ami.myimage.id
  instance_type   = "t2.micro"
  security_groups = [aws_security_group.asgsg.id]

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_autoscaling_group" "Asg" {
  min_size             = 1
  max_size             = 3
  desired_capacity     = 1
  launch_configuration = aws_launch_configuration.Asglc.name
  vpc_zone_identifier  = aws_vpc.asgvpc.id 
}
data "aws_ami" "myimage" {
  most_recent = true

  owners = ["self"]
  tags = {
    Name   = "app-server"
    Tested = "true"
   }
}