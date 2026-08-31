module "monitoring" {
  source = "../../modules/monitoring"
}
module "networking" {
  source = "../../modules/networking"
}
module "security_group" {
  source = "../../modules/security-group"
}
module "rds" {
  source = "../../modules/rds"
}
module "secrets-manager" {
  source = "../../modules/secrets-manager"
}