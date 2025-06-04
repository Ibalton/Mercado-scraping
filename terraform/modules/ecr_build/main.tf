###############################################################################
# produce one immutable tag per plan/apply
###############################################################################
locals {
  ts            = formatdate("YYYYMMDD-HHmmss", timestamp())
  backend_tag   = "backend-${local.ts}"
  frontend_tag  = "frontend-${local.ts}"
  scraper_tag  = "scraper-${local.ts}"
  repo_url      = var.ecr_repository_url                # 664122075535.dkr.ecr.us-east-1.amazonaws.com/mercado-scraper
  backend_image = "${local.repo_url}:${local.backend_tag}"
  frontend_image= "${local.repo_url}:${local.frontend_tag}"
  scraper_image= "${local.repo_url}:${local.scraper_tag}"
}

###############################################################################
# build & push (still using null_resource, but at least with immutable tags)
###############################################################################
resource "null_resource" "push_backend" {
  triggers = { tag = local.backend_tag }                # forces rebuild only when tag changes

  provisioner "local-exec" {
    command = "aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${local.repo_url} && docker build -t ${local.backend_image} ./backend && docker push ${local.backend_image}"
    working_dir = var.project_root
  }
}

resource "null_resource" "push_frontend" {
  triggers = { tag = local.frontend_tag }
  provisioner "local-exec" {
    command = "aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${local.repo_url} && docker build -t ${local.frontend_image} ./frontend && docker push ${local.frontend_image}"
    working_dir = var.project_root
  }
  depends_on = [null_resource.push_backend]
}

resource "null_resource" "push_scraper" {
  triggers = { tag = local.frontend_tag }
  provisioner "local-exec" {
    command = "aws ecr get-login-password --region ${var.aws_region} | docker login --username AWS --password-stdin ${local.repo_url} && docker build -t ${local.scraper_image} ./scraper && docker push ${local.scraper_image}"
    working_dir = var.project_root
  }
  depends_on = [null_resource.push_backend]
}