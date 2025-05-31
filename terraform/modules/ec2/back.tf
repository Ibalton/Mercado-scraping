resource "aws_security_group" "private_sg" {
  name   = "private-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port       = 22
    to_port         = 22
    protocol        = "tcp"
    security_groups = [aws_security_group.public_sg.id]
  }

  ingress {
    from_port       = 8000
    to_port         = 8000
    protocol        = "tcp"
    security_groups = [aws_security_group.public_sg.id]
    description     = "frontend access to backend"
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_instance" "back" {
  ami           = "ami-0c02fb55956c7d316"
  instance_type = "t2.micro"
  subnet_id     = var.private_subnet_id
  key_name      = aws_key_pair.key.key_name
  vpc_security_group_ids = [aws_security_group.private_sg.id]

  root_block_device {
    volume_size = 16
  }

  tags = {
    Name = "backend"
  }
}

