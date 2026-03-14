resource "aws_ecr_repository" "petclinic" {
  name                 = "petclinic-app"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }
}

output "ecr_repository_url" {
  value = aws_ecr_repository.petclinic.repository_url
}
