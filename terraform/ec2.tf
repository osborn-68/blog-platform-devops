### Latest Ubuntu 22.04 AMI ###
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

### Bastion / DevOps Node (public subnet) ###
resource "aws_instance" "bastion" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.bastion_sg.id]
  key_name                    = var.key_name
  associate_public_ip_address = true

  tags = { Name = "blog-bastion" }
}

### Application Node (public subnet - so browser can reach it directly) ###
resource "aws_instance" "app" {
  ami                         = data.aws_ami.ubuntu.id
  instance_type               = var.instance_type
  subnet_id                   = aws_subnet.public.id
  vpc_security_group_ids      = [aws_security_group.app_sg.id]
  key_name                    = var.key_name
  associate_public_ip_address = true

  tags = { Name = "blog-app" }
}

### Database Node (private subnet - only reachable from bastion/app) ###
resource "aws_instance" "db" {
  ami                     = data.aws_ami.ubuntu.id
  instance_type           = var.instance_type
  subnet_id               = aws_subnet.private.id
  vpc_security_group_ids  = [aws_security_group.db_sg.id]
  key_name                = var.key_name

  tags = { Name = "blog-db" }
}
