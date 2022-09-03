terraform {
  required_providers {
    google = {
      source = "hashicorp/google"
    }
  }
}

provider "google" {
  project = var.project
  region  = var.region
  zone    = var.zone
}

#provider "google-beta" {
#  project = var.project
#  region  = var.region
#  zone    = var.zone
#}

##########################
# Your Local IP Address, we will add it to the sql instance network rules

data "http" "myip" {
  url = "http://ipv4.icanhazip.com"
}

##########################
# GCP PUBSUB TOPIC

resource "google_pubsub_topic" "topic" {
  name = var.satori-audit-export-request
}

#######################################################
locals {
  #sql_instance_name = var.postgres-server-instance-name

  authorized_networks = [
    {
      name  = "Satori Installation Client IP"
      value = "${chomp(data.http.myip.response_body)}/32"
    },
  ]
}

########################
# CLOUD SQL

resource "google_sql_database_instance" "instance" {
  name             = var.postgres-server-instance-name
  database_version = "POSTGRES_14"
  region           = var.region
  settings {
    tier = var.sql_tier
    database_flags {
      name  = "password_encryption"
      value = "md5"
    }
    ip_configuration {
      ipv4_enabled = true
      require_ssl  = false

      dynamic "authorized_networks" {
        for_each = local.authorized_networks
        content {
          name  = lookup(authorized_networks.value, "name", null)
          value = authorized_networks.value.value
        }
      }
    }

  }
  deletion_protection = false
}

resource "google_sql_database" "database" {
  name     = "satoridb"
  instance = google_sql_database_instance.instance.name
  depends_on = [
    google_sql_database_instance.instance
  ]
}
resource "google_sql_user" "users" {
  name     = var.postgres_username
  instance = google_sql_database_instance.instance.name
  password = var.postgres_password
  depends_on = [
    google_sql_database_instance.instance
  ]
}

###########################
# BUCKETS FOR CLOUD FUNCTION

resource "google_storage_bucket" "function_bucket" {
  name     = "${var.project}-function"
  location = var.region
}

###########################
# GCP CLOUD FUNCTION

# Generates an archive of the source code compressed as a .zip file.
data "archive_file" "source" {
  type        = "zip"
  source_dir  = "src"
  output_path = "/tmp/function.zip"
}

# Add source code zip to the Cloud Function's bucket
resource "google_storage_bucket_object" "zip" {
  source       = data.archive_file.source.output_path
  content_type = "application/zip"

  # Append to the MD5 checksum of the files's content
  # to force the zip to be updated as soon as a change occurs
  name   = "src-${data.archive_file.source.output_md5}.zip"
  bucket = google_storage_bucket.function_bucket.name
}

# Create the Cloud function triggered by a `Finalize` event on the bucket
resource "google_cloudfunctions_function" "function" {
  name                  = "satori-audit-export-function"
  runtime               = "python310"
  available_memory_mb   = 2048
  source_archive_bucket = google_storage_bucket.function_bucket.name
  source_archive_object = google_storage_bucket_object.zip.name
  timeout                      = 540
  entry_point           = "mainwork"
  #service_account_email = google_service_account.satori_service_account.email

  event_trigger {
    event_type = "google.pubsub.topic.publish"
    resource   = "projects/${var.project}/topics/${var.satori-audit-export-request}"
    #service= "pubsub.googleapis.com"
    #failure_policy= {}
  }

  environment_variables = {
    postgres_port             = var.postgres_port
    postgres_username         = var.postgres_username
    postgres_database_name    = var.postgres_database_name
    postgres_schema_name      = var.postgres_schema_name
    postgres_table_name       = var.postgres_table_name
    satori_serviceaccount_id  = var.satori_serviceaccount_id
    satori_account_id         = var.satori_account_id
    satori_api_host           = var.satori_api_host
    postgres_password         = var.postgres_password
    postgres_server           = join(":", [var.project, var.region, var.postgres-server-instance-name])
    satori_serviceaccount_key = var.satori_serviceaccount_key

  }

  depends_on = [
    google_storage_bucket.function_bucket,
    google_storage_bucket_object.zip,
  ]
}


output "newsql-ip" {
  value = "sql server is running on ${google_sql_database_instance.instance.public_ip_address} and we have added your ip address of ${chomp(data.http.myip.response_body)} to its network security list."
  depends_on = [
    google_sql_database_instance.instance
  ]
}


