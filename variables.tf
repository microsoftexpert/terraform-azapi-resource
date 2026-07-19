# ---------------------------------------------------------------------------------------------------
# tf_mod_azapi_resource — variables
#
# Generic, secure wrapper around `azapi_resource`. This is the ONE azapi module that accepts a
# caller-supplied ARM `type` (and therefore a caller-chosen api-version). Curated tier-2 modules MUST
# pin their type/api-version instead, per this module suite's design conventions.
#
# Because the wrapped resource is generic, the request `body` is a free-form value the caller shapes.
# This is the documented exception to the "no `any` for body" rule:
# for a single specific ARM type, mirror the body in a deeply-typed object() instead.
# ---------------------------------------------------------------------------------------------------

variable "type" {
 type = string
 description = <<-EOT
 The ARM resource type and API version, in the form `<resource-type>@<api-version>`,
 e.g. "Microsoft.Storage/storageAccounts@2025-06-01" or
 "Microsoft.Network/virtualNetworks/subnets@2024-05-01".

 Immutable: changing the resource-type portion forces a new resource. The api-version is part of
 the contract you choose for this call — pin it deliberately, per this module suite's design conventions.
 EOT

 validation {
 condition = can(regex("^.+/.+@.+$", var.type))
 error_message = "type must be in the form \"<Namespace>/<resource>@<api-version>\", e.g. \"Microsoft.Storage/storageAccounts@2025-06-01\"."
 }
}

variable "name" {
 type = string
 default = null
 description = <<-EOT
 Name of the Azure resource. Optional because a few resource types derive it, but most top-level
 resources require it. Immutable: changing `name` forces a new resource (destroy + recreate).
 EOT
}

variable "parent_id" {
 type = string
 default = null
 description = <<-EOT
 ARM ID of the scope this resource is created in (the deployment scope). Immutable (force-new).
 - resource group scope: "/subscriptions/<sub>/resourceGroups/<rg>"
 - subscription scope: "/subscriptions/<sub>"
 - management group: "/providers/Microsoft.Management/managementGroups/<mg>"
 - tenant scope: "/"
 - extension scope: the ID of the resource being extended
 - child resources: the parent resource's ID (e.g. a subnet's parent_id is the vnet ID)
 For "Microsoft.Resources/resourceGroups" parent_id may be omitted; it then defaults to the
 provider's subscription. Build it with the provider functions (e.g.
 provider::azapi::resource_group_resource_id(...)) where it improves clarity.
 EOT
}

variable "location" {
 type = string
 default = null
 description = "Azure region for the resource (e.g. \"eastus2\"). Many resource types treat a change as force-new (enforced by ARM, not by this module). Omit for global / region-less types."
}

variable "body" {
 type = any
 default = {}
 description = <<-EOT
 The ARM request body as a NATIVE HCL object (never a jsonencode string — that is the v1 idiom).
 ARM property keys are camelCase, e.g.:
 body = {
 sku = { name = "Standard_LRS" }
 properties = { minimumTlsVersion = "TLS1_2", publicNetworkAccess = "Disabled" }
 }
 Typed `any` ONLY because this is the generic wrapper; secrets must NOT go here — use
 `sensitive_body`. Read-only / server-set properties should be omitted.
 EOT
}

variable "sensitive_body" {
 type = any
 default = null
 sensitive = true
 description = <<-EOT
 Write-only secret-bearing fragment of the request body (e.g. administratorLoginPassword, keys).
 Merge-patched into `body` at apply time and NEVER persisted to Terraform state. Use this for any
 credential material; never place secrets in `body`. Pair with `sensitive_body_version` to force a
 re-send when a rotated secret's value changes.
 EOT
}

variable "sensitive_body_version" {
 type = map(string)
 default = {}
 description = <<-EOT
 Map of `sensitive_body` property paths to opaque version strings, e.g.
 { "properties.administratorLoginPassword" = "v2" }. Bump a value to force that write-only property
 to be re-sent on the next apply (write-only values are not diffed from state).
 EOT
}

variable "identity" {
 type = object({
 type = string
 identity_ids = optional(list(string))
 })
 default = null
 description = <<-EOT
 Optional managed identity for the resource. Prefer managed identity over embedding credentials.
 {
 type = "SystemAssigned" | "UserAssigned" | "SystemAssigned, UserAssigned" | "None"
 identity_ids = optional(list(string)) # required when type includes "UserAssigned"
 }
 EOT

 validation {
 condition = var.identity == null ? true: contains(["SystemAssigned", "UserAssigned", "SystemAssigned, UserAssigned", "None"], var.identity.type)
 error_message = "identity.type must be one of: \"SystemAssigned\", \"UserAssigned\", \"SystemAssigned, UserAssigned\", \"None\"."
 }
}

variable "behavior" {
 description = <<-EOT
 azapi behavior controls. Secure defaults applied; override deliberately.
 {
 schema_validation_enabled = optional(bool, true) # keep true; validates type+body against the embedded schema at plan
 ignore_casing = optional(bool, false) # surface real casing drift rather than hide it
 ignore_missing_property = optional(bool, true) # provider default; stops un-echoed (e.g. secret) props showing as drift
 ignore_null_property = optional(bool, false)
 response_export_values = optional(any, []) # export NOTHING by default; opt in per path or JMESPath map
 locks = optional(list(string), []) # ARM IDs to serialize against, to avoid parallel races
 ignore_other_items_in_list = optional(list(string), [])
 list_unique_id_property = optional(map(string), {})
 retry = optional(object({
 error_message_regex = list(string) # regexes that, when matched on an error, trigger a retry
 interval_seconds = optional(number, 10) # 1..120
 max_interval_seconds = optional(number, 180) # 1..300
 }))
 }
 Over-exporting via `response_export_values` can pull sensitive/PII ARM properties into state and
 the `output` — keep it [] unless a non-secret read-back is genuinely needed, per this module suite's design conventions.
 EOT
 type = object({
 schema_validation_enabled = optional(bool, true)
 ignore_casing = optional(bool, false)
 ignore_missing_property = optional(bool, true)
 ignore_null_property = optional(bool, false)
 response_export_values = optional(any, [])
 locks = optional(list(string), [])
 ignore_other_items_in_list = optional(list(string), [])
 list_unique_id_property = optional(map(string), {})
 retry = optional(object({
 error_message_regex = list(string)
 interval_seconds = optional(number, 10)
 max_interval_seconds = optional(number, 180)
 }))
 })
 default = {}

 validation {
 condition = var.behavior.retry == null ? true: (var.behavior.retry.interval_seconds >= 1 && var.behavior.retry.interval_seconds <= 120)
 error_message = "behavior.retry.interval_seconds must be between 1 and 120."
 }
 validation {
 condition = var.behavior.retry == null ? true: (var.behavior.retry.max_interval_seconds >= 1 && var.behavior.retry.max_interval_seconds <= 300)
 error_message = "behavior.retry.max_interval_seconds must be between 1 and 300."
 }
}

variable "tags" {
 type = map(string)
 default = {}
 description = "ARM tags. Max 50 tags; each key <= 512 chars and value <= 256 chars."

 validation {
 condition = length(var.tags) <= 50
 error_message = "tags supports at most 50 entries."
 }
}

variable "timeouts" {
 type = object({
 create = optional(string)
 read = optional(string)
 update = optional(string)
 delete = optional(string)
 })
 default = null
 description = "Optional operation timeouts as Go durations, e.g. { create = \"30m\", delete = \"1h\" }."
}

variable "replace_triggers_external_values" {
 type = any
 default = null
 description = <<-EOT
 When this value changes (and is not null), the resource is replaced. Use to force replacement on
 changes ARM treats as immutable but does not itself force, e.g. [var.sku, var.zones]. Set to null
 ("break glass") to disable the trigger.
 EOT
}

variable "replace_triggers_refs" {
 type = list(string)
 default = []
 description = "List of property paths within the current configuration whose change should force replacement, e.g. [\"body.properties.sku.name\"]."
}

variable "request_options" {
 description = <<-EOT
 Advanced: extra HTTP headers and query parameters sent with each ARM operation. Empty by default.
 {
 create_headers / read_headers / update_headers / delete_headers = optional(map(string), {})
 create_query_parameters /... / delete_query_parameters = optional(map(list(string)), {})
 }
 Useful for api-specific headers (e.g. "x-ms-*"). Do NOT place secrets in headers.
 EOT
 type = object({
 create_headers = optional(map(string), {})
 create_query_parameters = optional(map(list(string)), {})
 read_headers = optional(map(string), {})
 read_query_parameters = optional(map(list(string)), {})
 update_headers = optional(map(string), {})
 update_query_parameters = optional(map(list(string)), {})
 delete_headers = optional(map(string), {})
 delete_query_parameters = optional(map(list(string)), {})
 })
 default = {}
}
