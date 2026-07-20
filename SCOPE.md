# SCOPE — terraform-azapi-resource  (lightweight)

## Design intent
Generic, secure-by-default wrapper around the `azapi_resource` primitive. It is the Casey's escape hatch
for managing **any** Azure Resource Manager resource type for which no curated tier-2 `terraform-azapi-*`
module exists yet — preview services, brand-new api-versions, or properties `azurerm` does not expose.
It is the **one** module that accepts a caller-supplied ARM `type` (and api-version); every curated
module pins its type instead. Plan-only authoring; a human applies from CI.

## In scope
- Keystone: `azapi_resource.this` — ARM `type@api-version` is **caller-supplied** (not pinned).
  Manages the full create/read/update/delete lifecycle of one ARM resource.

## Out of scope / consumed by id
- The deployment scope (`parent_id`: resource group / subscription / management group / tenant /
  extension target / parent resource) — owned elsewhere, consumed by reference.
- Any user-assigned identity (consumed by `identity.identity_ids`) — owned by a UAMI module.
- Any customer-managed key / Key Vault referenced inside `body` — owned by a Key Vault module.

## Consumes
| Input | Type | Source module |
|---|---|---|
| parent_id | string (scope ARM ID) | an RG / parent-resource module, or a provider function (`provider::azapi::resource_group_resource_id`, ...) |
| identity.identity_ids | list(string) | a user-assigned managed identity module |

## 🔑 Required Azure RBAC Permissions
Because the ARM `type` is caller-supplied, the exact permissions are **type-dependent**. For whatever
type is passed, the identity that runs `terraform apply` needs, on the target `parent_id` scope:
- `Microsoft.<RP>/<resource>/write`, `/read`, `/delete` — the control-plane CRUD for that type.
- Any child-action permission the body triggers (e.g. `Microsoft.<RP>/<resource>/<action>/action`).
- RP registration: `Microsoft.<RP>` registered in the subscription (or
  `Microsoft.Resources/subscriptions/providers/register/action` if `skip_provider_registration = false`).
- Least-privilege: a custom role scoped to exactly the above, or the relevant service-specific built-in
  (e.g. "Storage Account Contributor"), assigned on the `parent_id` scope — never subscription Owner.

## Azure Prerequisites
- The resource provider `Microsoft.<RP>` for the chosen `type` is registered in the subscription.
- The chosen `type` api-version is available in the target region (confirm via Microsoft Learn or
  `az provider show -n Microsoft.<RP>`).
- The `parent_id` scope already exists (RG / parent resource / extension target).
- Terraform `>= 1.12`; azapi provider `~> 2.10`. Provider `enable_preflight = true` recommended; in
  regulated contexts also set `disable_default_output = true` so read-only properties are not pulled
  into state unless this module's `response_export_values` opts in.
- Auth configured by the **caller** (OIDC / workload identity preferred); this module configures none.

## Emits
| Output | Description | Consumed by |
|---|---|---|
| id | ARM resource ID of the managed resource | role assignments, private endpoints, diagnostics, the `parent_id` of child resources |
| name | Resource name (may be provider-computed) | data-plane config, app settings |
| principal_id | System-assigned identity principal (null if none) | role assignments for the resource's MI |
| tenant_id | System-assigned identity tenant (null if none) | cross-tenant scenarios |
| output | Opt-in read-back of `behavior.response_export_values` (`{}` by default) | downstream config referencing computed props |

## Provider gotchas
- `name`, `parent_id`, and the `type` resource-type portion are immutable / force-new; `location` is
  force-new for most types (enforced by ARM, not by this module).
- `ignore_missing_property = true` (default) keeps secret props supplied via `sensitive_body` from
  showing as drift.
- Over-exporting via `behavior.response_export_values` can pull secret/PII ARM props into state and the
  `output` — keep it `[]` unless a non-secret read-back is genuinely needed.
- `body` is native HCL (v2). Never `jsonencode`. Secrets go in `sensitive_body`, never `body`.

## Design decisions
- The `type`/api-version are caller-supplied by design (this is the generic wrapper); this is the one
  documented relaxation of the api-version-pinning rule, per this module suite's design conventions. Prefer a curated tier-2
  module when one exists for the type.
- `body` is typed `any` (the documented generic-body exception); secrets are routed through write-only
  `sensitive_body`; `schema_validation_enabled` defaults `true`; `response_export_values` defaults `[]`.
