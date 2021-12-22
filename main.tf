provider "aws" {
  region = "us-east-1"
}

variable "vpc_cidr_block" {}
variable "subnet_cidr_block" {}
variable "env_prefix" {}
variable "my_ip" {}
variable "instance_type" {}
variable "public_key_location" {}



#VPC creation
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr_block

  tags = {
    Name : "${var.env_prefix}-mainvpc"
  }
}

#Create Subnet

resource "aws_subnet" "public_subnet" {
  cidr_block        = var.subnet_cidr_block
  vpc_id            = aws_vpc.main.id
  availability_zone = "us-east-1a"
}


#Create internet gateway

resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "main"
  }
}

#Create route table

resource "aws_route_table" "example" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "example"
  }
}


resource "aws_route_table_association" "a-rtb-subnet" {

  subnet_id      = aws_subnet.public_subnet.id
  route_table_id = aws_route_table.example.id

}


# Create Security Group
resource "aws_security_group" "jenkins_test_sg" {
  name        = "mainjenkinsreposg"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }
  ingress {
    description = "SSH"
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "mainjenkinsreposg"
  }
}

resource "aws_security_group" "nexusrepo_test_sg" {
  name        = "mainnexusreposg"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }
  ingress {
    description = "SSH"
    from_port   = 8081
    to_port     = 8081
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }
  tags = {
    Name = "mainnexusreposg"
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

resource "aws_security_group" "sonar_test_sg" {
  name        = "mainsonarreposg"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }
  ingress {
    description = "SSH"
    from_port   = 9000
    to_port     = 9000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }
  ingress {
    description = "SSH"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]

  }

  tags = {
    Name = "mainsonarreposg"
  }
  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }
}

#allowing jenkins secuity group in nexus security group. here source is jenkins and destination is nexus security group. 
resource "aws_security_group_rule" "allow_jenkins_test_sg" {

  type                     = "ingress"
  description              = "SSH"
  from_port                = 8081
  to_port                  = 8081
  protocol                 = "tcp"
  security_group_id        = aws_security_group.nexusrepo_test_sg.id #to
  source_security_group_id = aws_security_group.jenkins_test_sg.id   #from


}

resource "aws_security_group_rule" "allow_nexus_test_sg" {

  type                     = "ingress"
  description              = "SSH"
  from_port                = 8081
  to_port                  = 8081
  protocol                 = "tcp"
  security_group_id        = aws_security_group.jenkins_test_sg.id
  source_security_group_id = aws_security_group.nexusrepo_test_sg.id


}

resource "aws_security_group_rule" "allow_sonar_test_sg" {

  type                     = "ingress"
  description              = "SSH"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  security_group_id        = aws_security_group.jenkins_test_sg.id
  source_security_group_id = aws_security_group.sonar_test_sg.id

}

resource "aws_security_group_rule" "allow_jenkins_from_sonar_sg" {

  type                     = "ingress"
  description              = "SSH"
  from_port                = 80
  to_port                  = 80
  protocol                 = "tcp"
  security_group_id        = aws_security_group.sonar_test_sg.id
  source_security_group_id = aws_security_group.jenkins_test_sg.id


}

resource "aws_key_pair" "ssh-key" {

  key_name   = "server-key"
  public_key = file(var.public_key_location) #file location for your id_rsa.pub file
}



resource "aws_instance" "jenkins_server" {

  ami           = "ami-04505e74c0741db8d"
  instance_type = var.instance_type[0]
  #vpc_id                      = aws_vpc.main.id
  subnet_id                   = aws_subnet.public_subnet.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.jenkins_test_sg.id]
  key_name                    = aws_key_pair.ssh-key.key_name

  user_data = file("jenkins-setup.sh")


  tags = {
    Name = "${var.env_prefix}-jenkins_server"
  }


}

output "ec2_public_ip" {
  value = aws_instance.jenkins_server.public_ip
}

resource "aws_instance" "sonar_server" {

  ami           = "ami-04505e74c0741db8d"
  instance_type = var.instance_type[1]
  #vpc_id                      = aws_vpc.main.id
  subnet_id                   = aws_subnet.public_subnet.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.sonar_test_sg.id]
  key_name                    = aws_key_pair.ssh-key.key_name

  user_data = file("sonar-setup.sh")


  tags = {
    Name = "${var.env_prefix}-sonar_server"
  }


}

resource "aws_instance" "nexus_server" {

  ami           = "ami-0ed9277fb7eb570c9"
  instance_type = var.instance_type[1]
  #vpc_id                      = aws_vpc.main.id
  subnet_id                   = aws_subnet.public_subnet.id
  associate_public_ip_address = true
  vpc_security_group_ids      = [aws_security_group.nexusrepo_test_sg.id]
  key_name                    = aws_key_pair.ssh-key.key_name

  user_data = file("nexus-setup.sh")


  tags = {
    Name = "${var.env_prefix}-nexus_server"
  }


}





output "ec2_jenkinspublic_ip" {
  value = aws_instance.jenkins_server.public_ip
}

output "ec2_sonarpublic_ip" {
  value = aws_instance.sonar_server.public_ip
}

output "ec2_nexuspublic_ip" {
  value = aws_instance.nexus_server.public_ip
}


/*
resource "aws_security_group" "jenkins_sg" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = [aws_vpc.main.cidr_block]
    ipv6_cidr_blocks = [aws_vpc.main.ipv6_cidr_block]
  }

  ingress {
    description      = "TLS from VPC"
    from_port        = 8080
    to_port          = 8080
    protocol         = "tcp"
    cidr_blocks      = [aws_vpc.main.cidr_block]
    ipv6_cidr_blocks = [aws_vpc.main.ipv6_cidr_block]

  }
  ingress {
    description      = "TLS from nexusrepo"
    from_port        = 8081
    to_port          = 8081
    protocol         = "tcp"
    cidr_blocks      = [aws_vpc.main.cidr_block]
    ipv6_cidr_blocks = [aws_vpc.main.ipv6_cidr_block]
    security_groups  = [aws_security_group.jenkins_sg.id]

  }
  ingress {
    description      = "TLS from sonarqube"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = [aws_vpc.main.cidr_block]
    ipv6_cidr_blocks = [aws_vpc.main.ipv6_cidr_block]
    security_groups  = [aws_security_group.sonar_sg.id]

  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_tls"
  }
}

resource "aws_security_group" "nexusrepo_sg" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = [aws_vpc.main.cidr_block]
    ipv6_cidr_blocks = [aws_vpc.main.ipv6_cidr_block]
  }

  ingress {
    description      = "TLS from VPC"
    from_port        = 8081
    to_port          = 8081
    protocol         = "tcp"
    cidr_blocks      = [aws_vpc.main.cidr_block]
    ipv6_cidr_blocks = [aws_vpc.main.ipv6_cidr_block]
  }
  ingress {
    description      = "security group from jenkins"
    from_port        = 8081
    to_port          = 8081
    protocol         = "tcp"
    cidr_blocks      = [aws_vpc.main.cidr_block]
    ipv6_cidr_blocks = [aws_vpc.main.ipv6_cidr_block]
    security_groups  = [aws_security_group.jenkins_sg.id]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_tls"
  }
}

resource "aws_security_group" "sonar_sg" {
  name        = "allow_tls"
  description = "Allow TLS inbound traffic"
  vpc_id      = aws_vpc.main.id

  ingress {
    description      = "SSH"
    from_port        = 22
    to_port          = 22
    protocol         = "tcp"
    cidr_blocks      = [aws_vpc.main.cidr_block]
    ipv6_cidr_blocks = [aws_vpc.main.ipv6_cidr_block]
  }

  ingress {
    description      = "SSH"
    from_port        = 9000
    to_port          = 9000
    protocol         = "tcp"
    cidr_blocks      = [aws_vpc.main.cidr_block]
    ipv6_cidr_blocks = [aws_vpc.main.ipv6_cidr_block]
  }

  ingress {
    description      = "TLS from VPC"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = [aws_vpc.main.cidr_block]
    ipv6_cidr_blocks = [aws_vpc.main.ipv6_cidr_block]
  }
  ingress {
    description      = "TLS from jenkins"
    from_port        = 80
    to_port          = 80
    protocol         = "tcp"
    cidr_blocks      = [aws_vpc.main.cidr_block]
    ipv6_cidr_blocks = [aws_vpc.main.ipv6_cidr_block]
    security_groups  = [aws_security_group.jenkins_sg.id]
  }

  egress {
    from_port        = 0
    to_port          = 0
    protocol         = "-1"
    cidr_blocks      = ["0.0.0.0/0"]
    ipv6_cidr_blocks = ["::/0"]
  }

  tags = {
    Name = "allow_tls"
  }
}

*/
