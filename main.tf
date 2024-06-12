#create vpc
resource "aws_vpc" "terraform-test-vpc" {
  cidr_block = var.cidr
}

#create 02 public subnets and attach with the vpc "terraform-test-vpc"
#subnet 1
resource "aws_subnet" "terraform-subnet-1" {
  vpc_id = aws_vpc.terraform-test-vpc.id
  cidr_block = "10.0.0.0/24"
  availability_zone = "us-east-1a"
  map_public_ip_on_launch = true

}
#subnet 2
resource "aws_subnet" "terraform-subnet-2" {
  vpc_id = aws_vpc.terraform-test-vpc.id
  cidr_block = "10.0.1.0/24"
  availability_zone = "us-east-1b"
  map_public_ip_on_launch = true

}
#create internet gateway

resource "aws_internet_gateway" "terraform-internet-gateway" {
    vpc_id = aws_vpc.terraform-test-vpc.id
}
#crete route tables to give access to subnets
resource "aws_route_table" "terraform-route-tables" {
  vpc_id = aws_vpc.terraform-test-vpc.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.terraform-internet-gateway.id
  }
}
#creat route table association with subnets
resource "aws_route_table_association" "terraform-route-table-association-1" {
    subnet_id = aws_subnet.terraform-subnet-1.id
    route_table_id = aws_route_table.terraform-route-tables.id
}
resource "aws_route_table_association" "terraform-route-table-association-2" {
    subnet_id = aws_subnet.terraform-subnet-2.id
    route_table_id = aws_route_table.terraform-route-tables.id  
}

#create security groups for ec2
resource "aws_security_group" "terraform-SG1" {
  name        = "terraform-SG1"
  description = "Allow TLS inbound traffic and all outbound traffic"
  vpc_id      = aws_vpc.terraform-test-vpc.id
  ingress {
    description = "HTTP from VPC"
    from_port = "80"
    to_port = "80"
    protocol = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
    }
  ingress {
    description = "SSH"
    from_port = "22"
    to_port = "22"
    protocol = "tcp"
    cidr_blocks = [ "0.0.0.0/0" ]
    ipv6_cidr_blocks = [ "::/0" ]
    }
  egress {
    from_port = 0
    to_port = 0
    protocol = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    ipv6_cidr_blocks = [ "::/0" ]
    }
    tags = {
        name = "Websg"
    }
}
#create s3 bucket
resource "aws_s3_bucket" "terraform-mehmood-s3-test-bucket" {
    bucket = "terraform-mehmood-s3-test-bucket"  
}

#create ec2 instances instance 1
resource "aws_instance" "terraform-ec2-instances-1" {
    ami = "ami-04b70fa74e45c3917"
    instance_type = "t2.micro"
    vpc_security_group_ids = [aws_security_group.terraform-SG1.id]
    subnet_id = aws_subnet.terraform-subnet-1.id
    user_data = base64encode(file("userdata.sh")) 
}
#create ec2 instances instance 2
resource "aws_instance" "terraform-ec2-instances-2" {
    ami = "ami-04b70fa74e45c3917"
    instance_type = "t2.micro"
    vpc_security_group_ids = [aws_security_group.terraform-SG1.id]
    subnet_id = aws_subnet.terraform-subnet-2.id
    user_data = base64encode(file("userdata2.sh")) 
}
#create app load balancer alb
resource "aws_lb" "terraform-alb" {
    name = "terraform-alb"
    internal = "false"
    load_balancer_type = "application"

    security_groups = [aws_security_group.terraform-SG1.id]
    subnets = [ aws_subnet.terraform-subnet-1.id, aws_subnet.terraform-subnet-2.id ]
   
}
#create target groups
resource "aws_lb_target_group" "terraform-target-groups" {
    name = "terraform-target-groups"
    port = 80
    protocol = "HTTP"
    vpc_id = aws_vpc.terraform-test-vpc.id

    health_check {
      path = "/"
      port = "traffic-port"
    }
}
#target group attacehment what is inside taget group
resource "aws_lb_target_group_attachment" "terraform-tg-attacehment" {
    target_group_arn = aws_lb_target_group.terraform-target-groups.id
    target_id = aws_instance.terraform-ec2-instances-1.id
    port = 80
}

#add listner
resource "aws_lb_listener" "terraform-tg-listner" {
    load_balancer_arn = aws_lb.terraform-alb.arn
    port = 80
    protocol = "HTTP"  
    default_action {
      target_group_arn = aws_lb_target_group.terraform-target-groups.arn
      type = "forward"
    }
}
output "loadbalancerdns" {
    value = aws_lb.terraform-alb.dns_name
  
}
