# Example: manage a resource group with the generic azapi_resource wrapper, secure-by-default.
# The CALLER configures the azapi provider + auth (OIDC / workload identity preferred); this example
# shows the minimal calling pattern. Plan-only: a human applies from CI.

terraform {
 required_version = ">= 1.12.0"
 required_providers {
 azapi = {
 source = "Azure/azapi"
 version = "~> 2.10"
 }
 }
}

provider "azapi" {
 # subscription_id / tenant_id / OIDC settings come from the environment (ARM_*), never hardcoded.
 enable_preflight = true
}

module "resource_group" {
 source = "../.."

 type = "Microsoft.Resources/resourceGroups@2024-11-01"
 name = "rg-casey-example"
 parent_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
 location = "eastus2"

 tags = {
 environment = "example"
 managed_by = "terraform"
 }
}

output "resource_group_id" {
 value = module.resource_group.id
}
