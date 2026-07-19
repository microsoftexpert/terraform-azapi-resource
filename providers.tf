terraform {
 required_version = ">= 1.12.0"

 required_providers {
 azapi = {
 source = "Azure/azapi"
 version = "~> 2.10"
 }
 }
}

# NO provider {} block. Authentication, subscription, tenant, region and OIDC settings are the
# caller's concern, configured in the root module's provider "azapi" block and the CI environment
# (ARM_* / OIDC).
