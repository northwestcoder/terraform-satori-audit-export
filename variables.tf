variable "project" {
}

variable "region" {
  default = "us-east1"
}

variable "sql_tier" {
}

variable "zone" {
}

variable "postgres_username" {
  default = "postgres"
}

variable "postgres_password" {
}

variable "postgres_database_name" {
  default = "satoridb"
}

variable "postgres_schema_name" {
  default = "satori_audits"
}

variable "postgres_table_name" {
  default = "audit_data"
}

variable "postgres-server-instance-name" {
  default = "satori-terraform-postgres"
}

variable "postgres_port" {
  default = "5432"
}

variable "ssl_mode" {
  default = false
}

variable "satori-audit-export-request" {
  default = "satori-audit-export-request"
}

variable "satori_serviceaccount_id" {
}

variable "satori_serviceaccount_key" {
}

variable "satori_account_id" {
}

variable "satori_api_host" {
  default = "app.satoricyber.com"
}
