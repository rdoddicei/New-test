provider "azurerm" {
  features = {}
}

#Creation of dns record

resource "azurerm_dns_cname_record" "dns_record" {
  name                = var.subdomain
  zone_name           = var.dns_zone
  resource_group_name = var.resource_group
  ttl                 = 3600
  record              = var.alias_gateway
}

# API Management API Resource
resource "azurerm_api_management_api" "mobile_api" {
  name                = var.api_mgmt_service_name
  api_management_name = var.api_mgmt_service_name
  resource_group_name = var.resource_group
  revision            = "1"
  display_name        = var.mobile_display_name
  service_url         = var.service_url
  path                = var.customer_id
  protocols           = ["http", "https"]
  subscription_required = false
  api_type            = "graphql"
  subscription_key_parameter_names {
    header = "Ocp-Apim-Subscription-Key"
    query  = "subscription-key"
  }
}

# API Policy
resource "azurerm_api_management_api_policy" "mobile_api_policy" {
  api_name            = azurerm_api_management_api.mobile_api.name
  api_management_name = var.api_mgmt_service_name
  resource_group_name = var.resource_group
  xml_content         = <<XML
    <policies>
    <inbound>
        <base />
        <set-header name="TenantID" exists-action="override">
        <value>${var.tenant_id}</value>
        </set-header>
        <validate-jwt header-name="Authorization" failed-validation-httpcode="401" failed-validation-error-message="Authorization is denied for this request." require-expiration-time="true" require-signed-tokens="true">
        <issuer-signing-keys>
            <key>${
            var.signing_key       
            }</key>
        </issuer-signing-keys>
        <decryption-keys>
            <key>${
            var.signing_key
            }</key>
        </decryption-keys>
        <audiences>
            <audience>${
            var.audience
            }</audience>
        </audiences>
        <issuers>
            <issuer>${
            var.issuer
            }</issuer>
        </issuers>
        <required-claims>
            <claim name="sub" match="any" />
        </required-claims>
        </validate-jwt>
        <set-header name="sid" exists-action="override">
        <value>@(context.Request.Headers.GetValueOrDefault("Authorization", "").AsJwt()?.Subject)</value>
        </set-header>
    </inbound>
    <backend>
        <base />
    </backend>
    <outbound>
        <base />
    </outbound>
    <on-error>
        <base />
    </on-error>
    </policies>
    XML
}
