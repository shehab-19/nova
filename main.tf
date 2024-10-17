provider "aws" {
  region = "us-east-1"  # Changed to your desired region
}

# Create a VPC
resource "aws_vpc" "Nova_VPC" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "Nova_VPC"
  }
}

# Create a public subnet
resource "aws_subnet" "Nova_Public_Subnet_1" {
  vpc_id            = aws_vpc.Nova_VPC.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"  
  map_public_ip_on_launch = true

  tags = {
    Name = "Nova_Public_Subnet_1"
  }
}

# Create another public subnet
resource "aws_subnet" "Nova_Public_Subnet_2" {
  vpc_id            = aws_vpc.Nova_VPC.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"  
  map_public_ip_on_launch = true

  tags = {
    Name = "Nova_Public_Subnet_2"
  }
}

# Create an Internet Gateway
resource "aws_internet_gateway" "Nova_IGW" {
  vpc_id = aws_vpc.Nova_VPC.id

  tags = {
    Name = "Nova_InternetGateway"
  }
}

# Create a route table and associate it with the subnet
resource "aws_route_table" "Nova_Public_Route_Table" {
  vpc_id = aws_vpc.Nova_VPC.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.Nova_IGW.id
  }

  tags = {
    Name = "Nova_Public_Route_Table"
  }
}

resource "aws_route_table_association" "Nova_Public_Subnet_Association_1" {
  subnet_id      = aws_subnet.Nova_Public_Subnet_1.id
  route_table_id = aws_route_table.Nova_Public_Route_Table.id
}

resource "aws_route_table_association" "Nova_Public_Subnet_Association_2" {
  subnet_id      = aws_subnet.Nova_Public_Subnet_2.id
  route_table_id = aws_route_table.Nova_Public_Route_Table.id
}

# Create a security group to allow HTTP, HTTPS, and SSH traffic
resource "aws_security_group" "Nova_frontend_sg" {
  vpc_id = aws_vpc.Nova_VPC.id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Nova_frontend_sg"
  }
}

resource "aws_security_group" "Nova_backend_sg" {
  vpc_id = aws_vpc.Nova_VPC.id
 
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  
  }

  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"  
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "Nova_backend_sg"
  }
}

# Create Backend (Laravel) EC2 Instance with Docker
resource "aws_instance" "Nova_Backend_Instance" {
  ami           = "ami-005fc0f236362e99f"  # Ubuntu 22.04 AMI
  instance_type = "t2.micro"
  key_name      = "Nova_key"
  subnet_id     = aws_subnet.Nova_Public_Subnet_1.id
  associate_public_ip_address = true
  vpc_security_group_ids  = [aws_security_group.Nova_backend_sg.id]

  tags = {
    Name = "Nova_Backend"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt update -y",
      "sudo apt install docker.io -y",
      "sudo systemctl start docker",
      "sudo docker pull shehab19/backend",
      "sudo docker run -d --name backend -p 8000:80 shehab19/backend"
    ]
  }

}

# Create Frontend (Uptime Kuma) EC2 Instance with Docker
resource "aws_instance" "Nova_Frontend_Instance" {
  ami           = "ami-005fc0f236362e99f"  # Ubuntu 22.04 AMI
  instance_type = "t2.micro"
  key_name      = "Nova_key"
  subnet_id     = aws_subnet.Nova_Public_Subnet_2.id
  associate_public_ip_address = true
  vpc_security_group_ids  = [aws_security_group.Nova_frontend_sg.id]

  tags = {
    Name = "Nova_Frontend"
  }

  provisioner "remote-exec" {
    inline = [
      "sudo apt update -y",
      "sudo apt install docker.io -y",
      "sudo systemctl start docker",
      "sudo docker pull shehab19/uptime-kuma",
      "sudo docker run -d --name frontend -p 3001:3001 shehab19/uptime-kuma"
    ]
  }

}

resource "aws_security_group" "Nova_mysql_sg" {
  vpc_id = aws_vpc.Nova_VPC.id

  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]  # Allow access from any instance in the VPC
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"  # Allow all outbound traffic
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Nova_mysql_sg"
  }
}

# Create a MySQL RDS instance
resource "aws_db_instance" "Nova_MySQL" {
  allocated_storage    = 8
  storage_type         = "gp2"
  engine              = "mysql"
  engine_version       = "8.0" 
  instance_class       = "db.t3.micro"
  db_name             = "mydb"
  username             = "admin"
  password             = "MySecurePassword123"
  parameter_group_name = "default.mysql8.0"
  publicly_accessible  = false
  vpc_security_group_ids = [aws_security_group.Nova_mysql_sg.id] # novaa
  db_subnet_group_name   = aws_db_subnet_group.Nova-Public-Subnet-Group.name
  multi_az             = true 
  tags = {
    Name = "Nova_MySQL"
  }

}

resource "aws_db_subnet_group" "Nova-Public-Subnet-Group" {
  subnet_ids = [
    aws_subnet.Nova_Public_Subnet_1.id,
    aws_subnet.Nova_Public_Subnet_2.id
  ]

  tags = {
    Name = "Nova-Public-Subnet-Group"
  }
}

resource "aws_sns_topic" "cpu_alarm_sns" {
  name = "cpu_alarm_sns_topic"
}

resource "aws_sns_topic_subscription" "cpu_alarm_subscription" {
  topic_arn = aws_sns_topic.cpu_alarm_sns.arn
  protocol  = "email"
  endpoint  = "amir.m.kasseb@gmail.com"  # Your email address
}


# CloudWatch Alarm for Frontend Instance
resource "aws_cloudwatch_metric_alarm" "frontend_cpu_alarm" {
  alarm_name          = "Frontend-High-CPU-Usage"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Average"
  threshold           = "50"  # 50% CPU usage threshold
  alarm_description   = "This alarm triggers if the CPU utilization exceeds 50% for the frontend instance."

  dimensions = {
    InstanceId = aws_instance.Nova_Frontend_Instance.id
  }

  alarm_actions = [aws_sns_topic.cpu_alarm_sns.arn]
}

# CloudWatch Alarm for Backend Instance
resource "aws_cloudwatch_metric_alarm" "backend_cpu_alarm" {
  alarm_name          = "Backend-High-CPU-Usage"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = "1"
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "60"
  statistic           = "Average"
  threshold           = "50"  # 50% CPU usage threshold
  alarm_description   = "This alarm triggers if the CPU utilization exceeds 50% for the backend instance."

  dimensions = {
    InstanceId = aws_instance.Nova_Backend_Instance.id
  }

  alarm_actions = [aws_sns_topic.cpu_alarm_sns.arn]
}

output "Nova_frontend_instance_public_ip" {
  value = aws_instance.Nova_Frontend_Instance.public_ip
}

output "Nova_backend_instance_public_ip" {
  value = aws_instance.Nova_Backend_Instance.public_ip
}

# Output the endpoint of the MySQL RDS instance
output "mysql_rds" {
  value = aws_db_instance.Nova_MySQL.endpoint
}