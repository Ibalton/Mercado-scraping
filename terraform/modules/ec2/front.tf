resource "aws_security_group" "public_sg" {
  name   = "public-sg"
  vpc_id = var.vpc_id

  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = [var.my_ip]
  }

  ingress {
    from_port   = 80
    to_port     = 80
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

resource "aws_key_pair" "key" {
  key_name   = "mercado-key"
  public_key = file("~/.ssh/mercado.pub")
}

resource "aws_instance" "front" {
  ami           = "ami-0c02fb55956c7d316"  # Amazon Linux 2
  instance_type = "t2.micro"
  subnet_id     = var.public_subnet_id
  key_name      = aws_key_pair.key.key_name
  associate_public_ip_address = false
  vpc_security_group_ids = [aws_security_group.public_sg.id]

  tags = {
    Name = "frontend"
  }
}

resource "aws_eip" "front_ip" {
  instance = aws_instance.front.id
}

