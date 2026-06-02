provider "aws" {
  region = "ap-southeast-1"
}

resource "aws_key_pair" "demo-key" {
  key_name   = "demo-key"
  public_key = file("./keypair/demo-key.pub")
}

resource "aws_instance" "demo-instance" {
  ami           = "ami-0543dbdaf4e114be7"
  instance_type = "t3.micro"
  key_name      = aws_key_pair.demo-key.key_name

  tags = {
    Name = "Demo Instance"
  }
  vpc_security_group_ids = [aws_security_group.demo-sg.id]
}

resource "aws_security_group" "demo-sg" {
  name        = "demo-sg"
  description = "Security group for demo instance"

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
}