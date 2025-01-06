output "dns_record_name" {
  description = "The name of the DNS record created."
  value       = azurerm_dns_a_record.dns_record.name
}

output "dns_record_value" {
  description = "The value of the DNS record created."
  value       = azurerm_dns_a_record.dns_record.records[0]
}

output "mobile_api_url" {
  description = "The service URL for the mobile API"
  value       = azurerm_api_management_api.mobile_api.service_url
}
