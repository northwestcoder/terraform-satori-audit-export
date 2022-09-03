#satori vars
satori_serviceaccount_id = "SATORI_SA_ID"
satori_serviceaccount_key = "SATORI_SA_KEY"
satori_account_id = "SATORI_ACCOUNT_ID"

#GCP vars
project = "satori-audit-exports"
region = "us-east1"
zone = "us-east1-c"

#database vars
sql_tier = "db-f1-micro"
postgres_username = "postgres"
postgres_password = "Change!This^Password"
postgres_database_name = "satoridb"
postgres_schema_name = "public"
postgres_table_name = "audit_data"
postgres-server-instance-name = "satori-terraform-postgres"
postgres_port = "5432"
ssl_mode = false

#pubsub topic name
satori-audit-export-request = "satori-audit-export-request"
#satori api host
satori_api_host = "app.satoricyber.com"
