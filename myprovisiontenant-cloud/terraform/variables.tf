variable "subdomain" {
  description = "The subdomain to create the CNAME record for"
  type        = string
}

variable "alias_gateway" {
  description = "The alias gateway for the CNAME record"
  type        = string
}

variable "resource_group" {
  description = "The name of the resource group"
  type        = string
}

variable "dns_zone" {
  description = "The DNS zone name"
  type        = string
}

variable "customer_id" {
  description = "The customer ID for the mobile API"
  type        = string
}

variable "api_mgmt_service_name" {
  description = "The name of the API Management service"
  type        = string
}

variable "service_url" {
  description = "The URL for the mobile API service"
  type        = string
}

variable "tenant_id" {
  description = "The tenant ID for the API"
  type        = string
}

variable "signing_key" {
  description = "The signing key for JWT validation"
  type        = string
}

variable "audience" {
  description = "The audience for the JWT"
  type        = string
}

variable "issuer" {
  description = "The issuer for the JWT"
  type        = string
}

variable "mobile_display_name" {
  description = "The resource group name"
  type        = string
}

variable "mobile_webapi_name" {
  description = "The web API webapp name"
  type        = string
}
