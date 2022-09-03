# Satori Audit Data Export: Terraform Devops Automation

**A Terraform config for creating GCP resources to receive Satori security audit data**

- The following steps are meant as a quick-start guide.

- The end result will be a new GCP project with an automation solution:
	- when a message is received via Google PubSub to a certain topic, then
	- extract Satori query/audit data, and then
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
	- One of the first requirements is that you already have a Satori account and that account has some audit data - i.e. the account is actively being used.
	- You need to be an admin for that Satori account. 
	- Head over to the [Satori Docs](https://app.satoricyber.com/docs/api) to learn how to create a service account ID and service account secret.
	- You only need three pieces of info from Satori:
		- Your Account ID
		- Your Service Account ID (that needs to be created)
		- Your Service Account Key (created with the service account)

- The rest of the requirements are shown in the following steps - each step must succeed in order to proceed to the next step!


___

1. Install gcloud and terraform: 

	- Google gcloud install [info here](https://cloud.google.com/sdk/docs/install). For example, we used the ./install.sh on macos.

	- Hashicorp Terraform install [info here](https://www.terraform.io/downloads). For example, we used the brew method.

2. Once both are installed, log into gcloud:
```
gcloud auth login
```

This will launch your browser and authenticate you against GCP. This needs to succeed, in order to continue.

3. IN WEB BROWSER: create a new empty GCP project, you should be admin for this project. Take note of its PROJECT_ID

4. Back in your command terminal:

```gcloud config set project PROJECT_ID```

5. Where PROJECT_ID is from the above step.

6. You *must* turn on the following API's or else failure. You can paste the following into your terminal - it may take 1-2 minutes to run.
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

7. If you haven't done so yet, download this repository and edit the variables
 
- Use git clone, or, download zip and extract. 
- In your terminal, navigate to the directory where this repository is located. 
- With a text editor, you _must_ edit the file ```terraform.tfvars``` file and change any value in ALLCAPS accordingly. 
- You _can_ change the other values as well, if desired, such as the database password:
```
#project vars
project = "YOUR_GCP_PROJECT_ID_FROM_PREVIOUS_STEP"
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

#satori info
satori_serviceaccount_id = "SATORI_SA_ID"
satori_serviceaccount_key = "SATORI_SA_KEY"
satori_account_id = "SATORI_ACCOUNT_ID"
satori_api_host = "app.satoricyber.com"
```

8. At the command line, make sure you are in the directory where this repo is located, and then run:
```
terraform init
```
This sets up the Terraform environment
```
terraform validate
```
This validates the .tf files
```
terraform apply
```
This last command executes all of the instructions and builds the solution.

- **Now wait about 15-20 minutes while terraform deploys the following:**
	- A Pubsub topic which will trigger our function 
	- Cloud Storage for our python code
	- Cloud SQL Instance for storing the audit data
	- Cloud Function for running the python code
- The SQL instance takes the longest - up to 15 minutes. Ideally, this command returns with no errors nor warnings. 
- If everything worked, the text output will show the IP address of the postgres database.

9. At the command line, send this message:
```
gcloud pubsub topics publish satori-audit-export-request --message="3"
```

- By posting a message to the Pubsub topic, this will trigger the cloud function to retrieve Satori audit data using the Satori Rest API, for the last three days.
- You can change ```message="3"``` to any value up to 90. Don't forget the quotes.
- From a production POV, you can envision setting up a schedule to send a message to Pubsub, e.g. Once a week retrieve the last 7 days of audit data. Try this [quick start](https://cloud.google.com/scheduler/docs/tut-pub-sub) for more info.

**You should have Satori audit data now. Success!**

Your client IP will have been added to the database network list, so you can fire up your favorite db client and connect to your new Satori Postgres database hosting your audit data using the IP address which was output from the previous step.

This quick start defaults to SQL SSL mode = false, so SSL is not enabled. If you change to this to 'true', then you will need to configure client certificates and add those to your database client - this is outside the scope of this quick start.

**Clean up / Tear Down**

- If you run ```terraform destroy``` it will throw an error on the sql instance step.
- This is because terraform detects that the database is no longer empty (if you ran all the steps above).
- To fix this, 
 	- first run ```drop table public.audit_data``` in your database client. 
 	- You will also need to "end" or "close" your connection or otherwise quit your database client.
- Once you have done both of these steps, now at the command line you can run ```terraform destroy```, and all of the above resources will be removed from your Google Cloud project.
