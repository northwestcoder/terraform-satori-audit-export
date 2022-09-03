# Satori Audit Data Export: Terraform Devops Automation

![Satori Logi](https://satoricyber.com/wp-content/uploads/LogoDark2.svg)

### A Terraform config for creating GCP resources to receive Satori query audit data

- The following steps are meant as a quick-start guide.

- The end result will be a new GCP project with an automation solution:
	- when a message is received via Google PubSub to a certain topic, then
	- extract Satori query/audit data for the specified relative timeframe, and then
	- insert that data into a Cloud SQL instance (Postgres)

- What you will need:
	- A [Google Cloud](https://console.cloud.google.com/welcome) account and the ability to create new cloud projects.
	- A [Satori](https://satoricyber.com/testdrive) account with admin rights.
	- Access to a command line / terminal session.

- _GCP opinions:_

	- This example was tested using a very plain, simple GCP project and zero GCP 'organizations'. 
	- All of the security settings are 'default' and thus have reasonable security.
	- However, your org may have an entirely different security topology which will make this config fail.
	- The SQL database that we create is assigned a public IP address. Your org IAM policy settings may prohibit this.
	- The Cloud Function we build uses Python 3.10 and runs under the standard GCP 'appspot' account. Your org IAM policy settings may prohibit this.
	- There are many other reasons this config will fail, and they will _all_ have something to do with the way your GCP security is configured.

- Satori Config:
	- One of the first requirements is that you already have a [Satori account](https://www.satoricyber.com/testdrive) and that account has some audit data - i.e. the account is actively being used.
	- You need to be an admin for that Satori account. 
	- Head over to the [Satori Docs](https://app.satoricyber.com/docs/api) to learn how to create a service account ID and service account secret.
	- You only need three pieces of info from Satori:
		- Your Account ID
		- Your Service Account ID (that needs to be created)
		- Your Service Account Key (created with the service account)

- The rest of the requirements are shown in the following steps - each step must succeed in order to proceed to the next step!

___

#### :orange_circle: Setup

1. Install gcloud and terraform: 

	- Google gcloud install [info here](https://cloud.google.com/sdk/docs/install). For example, we used the ./install.sh on macos.

	- Hashicorp Terraform install [info here](https://www.terraform.io/downloads). For example, we used the brew method.

2. Once both are installed, in your command terminal, run the following. This will launch your browser and authenticate you against Google Cloud. This needs to succeed, in order to continue:
```
gcloud auth login
```

3. In your command terminal, run the following. This creates a project whose ID is "satori-audit-exports". You will need this ID later.
```
gcloud projects create satori-audit-exports --name="Satori Audit Exports Terraform"
```

4. In your command terminal, run the following to switch to this project for gcloud:
```
gcloud config set project satori-audit-exports
```

5. You *must* turn on the following API's or else failure will occur. You can paste the following into your terminal - it may take 1-2 minutes to run.
```
gcloud services enable cloudapis.googleapis.com
gcloud services enable cloudbuild.googleapis.com
gcloud services enable clouddebugger.googleapis.com
gcloud services enable cloudfunctions.googleapis.com
gcloud services enable cloudtrace.googleapis.com
gcloud services enable containerregistry.googleapis.com
gcloud services enable datastore.googleapis.com
gcloud services enable logging.googleapis.com
gcloud services enable monitoring.googleapis.com
gcloud services enable pubsub.googleapis.com
gcloud services enable servicemanagement.googleapis.com
gcloud services enable serviceusage.googleapis.com
gcloud services enable sql-component.googleapis.com
gcloud services enable sqladmin.googleapis.com
gcloud services enable storage-api.googleapis.com
gcloud services enable storage-component.googleapis.com
gcloud services enable storage.googleapis.com
```

6. If you haven't done so yet, download this repository that you are currently reading and edit the variables:
 
- Use git clone, or, download zip and extract. 
- In your terminal, navigate to the directory where this repository is located.
- With a text editor, you **must edit** the three Satori values in ALLCAPS in the file ```terraform.tfvars```. 
- You _can optionally_ change the other values as well, such as the database password or GCP region and zone. Then save the file.
```
#contents of terraform.tfvars file
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
```

7. At the command line, make sure you are in the directory where this repo is located, and then run:
```
terraform init
```
This sets up the Terraform environment for this project.
```
terraform validate
```
This validates the .tf files.
```
terraform apply
```
This last command executes all of the instructions and builds the solution.

- **Now wait about 15-20 minutes while terraform deploys the following:**
	- A Pubsub topic which will trigger our function.
	- Cloud Storage for our python code.
	- A Cloud SQL Instance for storing the audit data.
	- A Cloud Function for running the python code.
- The SQL instance takes the longest - up to 15 minutes.
- Ideally, this command returns with no errors nor warnings. 
- If everything worked, the text output will show the IP address of the Postgres database that was created.

8. At the command line, send this message:
```
gcloud pubsub topics publish satori-audit-export-request --message="3"
```

- By posting a message to the Pubsub topic, this will trigger the cloud function to retrieve Satori audit data using the Satori Rest API, for the last three days.
- You can change ```message="3"``` to any value up to 90. Don't forget the quotes. 
- This message based trigger is useful in many ways due to the relative nature of the "days ago" parameter, combined with primary key support for the audit data itself using column ```flow_id```.
- For example, from a production POV you can envision setting up a schedule to send a message to Pubsub once a week, to retrieve the last 7 days of audit data. Try this [quick start](https://cloud.google.com/scheduler/docs/tut-pub-sub) for more info.

___

#### :green_circle: Usage

**You should have Satori audit data now. Success!**

- Your client IP will have been added to the database network list.
- _You can now launch your favorite db client and connect to your new Postgres database hosting your Satori audit data!_
- The hostname is the IP address which was output to the terminal at the end of ```terraform apply```.
- If you left the defaults alone, you have a single table ```public.audit_data``` to explore.
- This quick start defaults to ```ssl_mode = false```, so SSL is not enabled. If you change this to 'true', then this terraform config will create a client cert bundle for your new Cloud SQL instance. This information will be inside the terraform.tfstate file. You can run the following commands to create three new files to be used with your database client. You will need to install the ```jq``` command first. On a mac you could run ```brew install jq```. To create the three new cert files, run the following:
```
terraform show -json terraform.tfstate | jq '.values.root_module.resources[] | select(.address=="google_sql_ssl_cert.client_cert") | .values.cert' > certs/client.pem
terraform show -json terraform.tfstate | jq '.values.root_module.resources[] | select(.address=="google_sql_ssl_cert.client_cert") | .values.private_key' > certs/private.key
terraform show -json terraform.tfstate | jq '.values.root_module.resources[] | select(.address=="google_sql_ssl_cert.client_cert") | .values.server_ca_cert' > certs/server_ca.pem
```
- If for some reason there is no data in the table, then some type of program error has occurred in the Google Cloud Function. Go to that function in your web browser and then review its logs for error codes or more info.

#### :red_circle: Clean up / Tear Down

- To unapply in terraform, you run ```terraform destroy```.
- However, if you run ```terraform destroy``` for this project, it will throw an error on the SQL instance step.
- This is because terraform detects that the database is no longer empty - if you ran all the steps above this is true.
- To fix this, 
 	- first run ```drop table public.audit_data``` in your database client. 
 	- You will also need to "end" or "close" your connection or otherwise quit your database client.
- Once you have done both of these steps, now at the command line you can run ```terraform destroy``` and all of the terraform-created resources will be removed from your Google Cloud project.
