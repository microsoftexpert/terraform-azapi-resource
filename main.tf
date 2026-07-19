# ---------------------------------------------------------------------------------------------------
# tf_mod_azapi_resource — main
#
# A thin, total renderer over the `azapi_resource` primitive. One keystone resource named `this`.
# Secure-by-default behavior controls per this module suite's design conventions; secrets routed via write-only `sensitive_body`.
# ---------------------------------------------------------------------------------------------------

resource "azapi_resource" "this" {
 # Caller-supplied ARM type@api-version (the documented generic-wrapper exception). Force-new.
 type = var.type
 name = var.name
 parent_id = var.parent_id
 location = var.location

 # Native HCL body assembled by the caller. NEVER jsonencode (that is the v1 idiom).
 body = var.body

 # Secrets are write-only: merge-patched into the request body, never persisted to state.
 sensitive_body = var.sensitive_body
 sensitive_body_version = var.sensitive_body_version

 # Secure-by-default behavior controls.
 schema_validation_enabled = var.behavior.schema_validation_enabled
 ignore_casing = var.behavior.ignore_casing
 ignore_missing_property = var.behavior.ignore_missing_property
 ignore_null_property = var.behavior.ignore_null_property
 response_export_values = var.behavior.response_export_values
 locks = var.behavior.locks

 ignore_other_items_in_list = var.behavior.ignore_other_items_in_list
 list_unique_id_property = var.behavior.list_unique_id_property

 # Force-replace controls (inactive unless the caller opts in).
 replace_triggers_external_values = var.replace_triggers_external_values
 replace_triggers_refs = var.replace_triggers_refs

 # Per-operation request headers / query parameters (advanced; empty by default).
 create_headers = var.request_options.create_headers
 create_query_parameters = var.request_options.create_query_parameters
 read_headers = var.request_options.read_headers
 read_query_parameters = var.request_options.read_query_parameters
 update_headers = var.request_options.update_headers
 update_query_parameters = var.request_options.update_query_parameters
 delete_headers = var.request_options.delete_headers
 delete_query_parameters = var.request_options.delete_query_parameters

 tags = var.tags

 # retry is a single nested-object attribute. The deprecated multiplier / randomization_factor
 # fields are intentionally not exposed (they will be removed in a future provider version).
 retry = var.behavior.retry == null ? null: {
 error_message_regex = var.behavior.retry.error_message_regex
 interval_seconds = var.behavior.retry.interval_seconds
 max_interval_seconds = var.behavior.retry.max_interval_seconds
 }

 dynamic "identity" {
 for_each = var.identity == null ? []: [var.identity]
 content {
 type = identity.value.type
 identity_ids = identity.value.identity_ids
 }
 }

 dynamic "timeouts" {
 for_each = var.timeouts == null ? []: [var.timeouts]
 content {
 create = timeouts.value.create
 read = timeouts.value.read
 update = timeouts.value.update
 delete = timeouts.value.delete
 }
 }
}
