# ---------------------------------------------------------------------------------------------------
# tf_mod_azapi_resource — outputs
# Primary output `id` first. Never emit a secret. The `output` map carries ONLY what the caller
# explicitly selected via behavior.response_export_values (empty by default).
# ---------------------------------------------------------------------------------------------------

output "id" {
 description = "The ARM resource ID of the managed resource. Primary cross-resource reference."
 value = azapi_resource.this.id
}

output "name" {
 description = "The name of the managed Azure resource (may be provider-computed if not supplied)."
 value = azapi_resource.this.name
}

output "output" {
 description = <<-EOT
 Read-back properties selected via behavior.response_export_values (an empty object {} by default —
 nothing is exported unless the caller opts in). WARNING: exporting a path that holds secret/PII
 material will surface it here and in state; keep response_export_values = [] and export only
 non-secret paths per this module suite's design conventions.
 EOT
 value = azapi_resource.this.output
}

output "principal_id" {
 description = "Principal ID of the system-assigned managed identity, if one is configured (null otherwise). Consumed by role assignments for the resource's identity."
 value = try(azapi_resource.this.identity[0].principal_id, null)
}

output "tenant_id" {
 description = "Tenant ID of the system-assigned managed identity, if one is configured (null otherwise)."
 value = try(azapi_resource.this.identity[0].tenant_id, null)
}
