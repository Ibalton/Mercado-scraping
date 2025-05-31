module "vpc" {
  source = "./modules/vpc"
}

module "ec2" {
  source             = "./modules/ec2"
  vpc_id             = module.vpc.vpc_id
  public_subnet_id   = module.vpc.public_subnet_id
  private_subnet_id  = module.vpc.private_subnet_id
  ami_id             = var.ami_id
  key_pair_name      = var.key_pair_name
  my_ip              = var.my_ip
}


module "rds" {
  source                 = "./modules/rds"
  db_subnet_group        = module.vpc.db_subnet_group
  vpc_security_group_ids = [module.ec2.db_sg_id]
  private_subnet_ids = module.vpc.private_subnet_ids
}
