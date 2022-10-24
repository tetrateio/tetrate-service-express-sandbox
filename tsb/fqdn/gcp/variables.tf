variable "dns_zone" {
    default = null
}
variable "fqdn" {
}
variable "address" {
}

variable "tsb_mp" {
  default = {}
}
variable "gcp_k8s_regions" {
  default = []
}
locals {
  infra = data.terraform_remote_state.infra
  k8s_regions = var.gcp_k8s_regions
}