# Define the AWS provider and specify the region
provider "aws" {
  region = "us-east-1"  # Changed to your desired region
}

# Create a VPC with a CIDR block of 10.0.0.0/16
resource "aws_vpc" "Nova_VPC" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "Nova_VPC"
  }
}

# Create a public subnet in Availability Zone us-east-1a
resource "aws_subnet" "Nova_Public_Subnet_1" {
  vpc_id            = aws_vpc.Nova_VPC.id
  cidr_block        = "10.0.1.0/24"
  availability_zone = "us-east-1a"  
  map_public_ip_on_launch = true

  tags = {
    Name = "Nova_Public_Subnet_1"
  }
}

# Create another public subnet in Availability Zone us-east-1b
resource "aws_subnet" "Nova_Public_Subnet_2" {
  vpc_id            = aws_vpc.Nova_VPC.id
  cidr_block        = "10.0.2.0/24"
  availability_zone = "us-east-1b"  
  map_public_ip_on_launch = true

  tags = {
    Name = "Nova_Public_Subnet_2"
  }
}

# Create an Internet Gateway and attach it to the VPC
resource "aws_internet_gateway" "Nova_IGW" {
  vpc_id = aws_vpc.Nova_VPC.id

  tags = {
    Name = "Nova_InternetGateway"
  }
}

# Create a route table for the public subnets and add a default route to the Internet Gateway
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

# Associate the public route table with Public Subnet 1
resource "aws_route_table_association" "Nova_Public_Subnet_Association_1" {
  subnet_id      = aws_subnet.Nova_Public_Subnet_1.id
  route_table_id = aws_route_table.Nova_Public_Route_Table.id
}

# Associate the public route table with Public Subnet 2
resource "aws_route_table_association" "Nova_Public_Subnet_Association_2" {
  subnet_id      = aws_subnet.Nova_Public_Subnet_2.id
  route_table_id = aws_route_table.Nova_Public_Route_Table.id
}

# Create a security group for the frontend to allow HTTP, HTTPS, and SSH traffic
resource "aws_security_group" "Nova_frontend_sg" {
  vpc_id = aws_vpc.Nova_VPC.id

  # Allow SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow HTTP access
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow HTTPS access
  ingress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow all outbound traffic
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

# Create a security group for the backend to allow SSH and backend service traffic
resource "aws_security_group" "Nova_backend_sg" {
  vpc_id = aws_vpc.Nova_VPC.id

  # Allow SSH access
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  
  }

  # Allow backend service access
  ingress {
    from_port   = 8000
    to_port     = 8000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]  
  }

  # Allow all outbound traffic
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
  key_name      = "Nova_key"  # Ensure this key exists in AWS
  subnet_id     = aws_subnet.Nova_Public_Subnet_1.id
  associate_public_ip_address = true
  vpc_security_group_ids  = [aws_security_group.Nova_backend_sg.id]

  tags = {
    Name = "Nova_Backend"
  }

  # Use a provisioner to install Docker and run the backend container
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
  key_name      = "Nova_key"  # Ensure this key exists in AWS
  subnet_id     = aws_subnet.Nova_Public_Subnet_2.id
  associate_public_ip_address = true
  vpc_security_group_ids  = [aws_security_group.Nova_frontend_sg.id]

  tags = {
    Name = "Nova_Frontend"
  }

  # Use a provisioner to install Docker and run the frontend container
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

# Create a security group for MySQL to allow access from within the VPC
resource "aws_security_group" "Nova_mysql_sg" {
  vpc_id = aws_vpc.Nova_VPC.id

  # Allow MySQL access within the VPC
  ingress {
    from_port   = 3306
    to_port     = 3306
    protocol    = "tcp"
    cidr_blocks = ["10.0.0.0/16"]  # Allow access from any instance in the VPC
  }

  # Allow all outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "Nova_mysql_sg"
  }
}

# Create a MySQL RDS instance
resource "aws_db_instance" "Nova_MySQL" {
  allocated_storage    = 8  # Storage size in GB
  storage_type         = "gp2"
  engine               = "mysql"
  engine_version       = "8.0" 
  instance_class       = "db.t3.micro"
  db_name              = "mydb"
  username             = "admin"
  password             = "MySecurePassword123"  # Set a secure password
  parameter_group_name = "default.mysql8.0"
  publicly_accessible  = false  # The database will not be publicly accessible
  vpc_security_group_ids = [aws_security_group.Nova_mysql_sg.id]
  db_subnet_group_name   = aws_db_subnet_group.Nova-Public-Subnet-Group.name
  multi_az             = true  # Multi-AZ for high availability
  
  tags = {
    Name = "Nova_MySQL"
  }
}

# Create a DB subnet group for MySQL RDS
resource "aws_db_subnet_group" "Nova-Public-Subnet-Group" {
  subnet_ids = [
    aws_subnet.Nova_Public_Subnet_1.id,
    aws_subnet.Nova_Public_Subnet_2.id
  ]

  tags = {
    Name = "Nova-Public-Subnet-Group"
  }
}

# Create an SNS topic for CloudWatch alarms
resource "aws_sns_topic" "cpu_alarm_sns_topic" {
  name = "nova_cpu_alarm_topic"
}

# Subscribe an email to the SNS topic to receive CloudWatch alarm notifications
resource "aws_sns_topic_subscription" "alarm_email_subscription" {
  topic_arn = aws_sns_topic.cpu_alarm_sns_topic.arn
  protocol  = "email"
  endpoint  = "amir.m.kasseb@gmail.com"  # Email to receive alarm notifications
}

# Create a CloudWatch alarm for frontend instance CPU utilization
resource "aws_cloudwatch_metric_alarm" "Nova_frontend_CPU_alarm" {
  alarm_name                = "Nova_frontend_CPU_alarm"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = "2"
  metric_name               = "CPUUtilization"
  namespace                 = "AWS/EC2"
  period                    = "120"
  statistic                 = "Average"
  threshold                 = "50"  # Alarm threshold set to 50%
  alarm_actions             = [aws_sns_topic.cpu_alarm_sns_topic.arn]
  dimensions = {
    InstanceId = aws_instance.Nova_Frontend_Instance.id
  }
}

# Create a CloudWatch alarm for backend instance CPU utilization
resource "aws_cloudwatch_metric_alarm" "Nova_backend_CPU_alarm" {
  alarm_name                = "Nova_backend_CPU_alarm"
  comparison_operator       = "GreaterThanThreshold"
  evaluation_periods        = "2"
  metric_name               = "CPUUtilization"
  namespace                 = "AWS/EC2"
  period                    = "120"
  statistic                 = "Average"
  threshold                 = "50"  # Alarm threshold set to 50%
  alarm_actions             = [aws_sns_topic.cpu_alarm_sns_topic.arn]
  dimensions = {
    InstanceId = aws_instance.Nova_Backend_Instance.id
  }
}

# Output the frontend instance public IP
output "Nova_frontend_instance_public_ip" {
  description = "The public IP of the frontend instance"
  value       = aws_instance.Nova_Frontend_Instance.public_ip
}

# Output the backend instance public IP
output "Nova_backend_instance_public_ip" {
  description = "The public IP of the backend instance"
  value       = aws_instance.Nova_Backend_Instance.public_ip
}

# Output the MySQL RDS endpoint
output "Nova_MySQL_endpoint" {
  description = "The endpoint of the MySQL RDS instance"
  value       = aws_db_instance.Nova_MySQL.endpoint
}
