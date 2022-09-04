# Satori Audit Data Export: Terraform Devops Automation

**A Terraform config for creating Google Cloud resources that will receive [Satori](https://www.satoricyber.com) query audit data on a schedule**

**[Summary](#Summary)**<br>
**[Setup](#Setup)**<br>
**[Usage](#Usage)**<br>
**[Rollback](#Rollback)**<br>

___

### Summary

- The following steps are meant as a quick-start guide.

- The end result will be a new GCP project with an automation solution:
	- when a message is received via Google PubSub to a certain topic, then
	- extract Satori query/audit data for the specified relative timeframe "days ago up to yesterday", and then
	- insert this data into a Google Cloud Postgres SQL instance.

- What you will need:
	- A [Google Cloud](https://console.cloud.google.com/welcome) account and the ability to create new cloud projects as an admin.
	- A [Satori](https://satoricyber.com/testdrive) account with admin rights.
	- Access to a command line / terminal session. Note: this project was tested on macOS/bash.

- _GCP opinions:_
	- This example was tested using a very plain, simple Google Cloud project and zero 'organizations'. 
	- All of the security settings are 'default' and thus have reasonable security.
	- However, your org may have an entirely different security topology which will make this config fail.
	- The SQL database that we create is assigned a public IP address. Your org IAM policy settings may prohibit this.
	- The Cloud Function we build uses Python 3.10 and runs under the standard 'appspot' account. Your org IAM policy settings may prohibit this.
	- There are many other reasons this config will fail, and they will likely have something to do with the way your Google Cloud security is configured.

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


### Setup

1. Install gcloud and terraform. 
	- Google gcloud install [info here](https://cloud.google.com/sdk/docs/install). For example, we used the ./install.sh on macos.
	- Hashicorp Terraform install [info here](https://www.terraform.io/downloads). For example, we used the brew method.

2. Once both are installed, in your command terminal, run the following. This will launch your browser and authenticate you against Google Cloud. This needs to succeed, in order to continue.
```
gcloud auth login
```

3. In your command terminal, run the following. This creates a project whose ID is "satori-audit-exports".
```
gcloud projects create satori-audit-exports --name="Satori Audit Exports Terraform"
```

4. In your command terminal, run the following to switch to this project for gcloud.
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

6. **If you haven't done so yet, download this repository that you are currently reading, open the file ```terraform.tfvars``` with your favorite text editor, and edit at least three of the variables.**
 
- Use git clone, or, download the zip and extract.
- With a text editor, you **must edit** the three Satori values in ALLCAPS in the file ```terraform.tfvars```. 
- You _can optionally_ change the other values as well, such as the database password or GCP region and zone. Then save the file.
- To run this quick start as-is, this is the only file you need to edit.

7. At the command line, make sure you navigate to the directory where this repo is located, and then run:
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
		- Terraform uses the source code from this repository you are currently reading, and
		- Zips up that code and loads it to a Google Cloud storage bucket.
		- The Cloud Function then uses the python code for executing calls to the Satori API and then runs database upserts.
- The SQL instance takes the longest - up to 15 minutes.
- Ideally, this command returns with no errors nor warnings. 
- If everything worked, the text output will show the IP address of the Postgres database that was created.

8. At the command line, send this message:
```
gcloud pubsub topics publish satori-audit-export-request --message="3"
```

- By posting a message to the Pubsub topic, this will trigger the cloud function to retrieve Satori audit data from the last 3 days using the Satori Rest API.
- You can change ```message="3"``` to any value up to 90. 
- This message based trigger is useful in many ways due to the relative nature of the "days ago" parameter, combined with primary key support for the audit data itself using column ```flow_id```.
- For example, from a production POV you can envision setting up a schedule to send a message to Pubsub once a week, to retrieve the last 7 days of audit data. Try this [quick start](https://cloud.google.com/scheduler/docs/tut-pub-sub) for more info.
- Note about time limits: Google Cloud functions have a 540 second (9 minute) maximum runtime. You may exceed this time limit if you attempt to pull too much Satori audit data at any one time.

___

### Usage

**You should have Satori audit data in your database now. Success!**

- Your client IP will have been added to the database network list.
- _You can now launch your favorite db client and connect to your new Postgres database hosting your Satori audit data!_
- The hostname is the IP address which was output to the terminal at the end of ```terraform apply```. The username, password and port are found in your ```terraform.tfvars``` file.
- If you left the defaults alone, you have a single table ```public.audit_data``` to explore.
- This quick start defaults to ```ssl_mode = false```, so SSL is not enabled for your Cloud SQL instance. If you change this to ```true```, then this terraform config will create a client cert bundle for your new Cloud SQL instance.
	- This information will be buried inside the terraform.tfstate file. 
	- You can run the following commands to create three new files to be used with your database client.
	- You will need to install the ```jq``` command first, e.g. on a mac you can run ```brew install jq```.
	- Then, to create the three new cert files, run the following:
```
terraform show -json terraform.tfstate | jq '.values.root_module.resources[] | select(.address=="google_sql_ssl_cert.client_cert") | .values.cert' > client.pem
terraform show -json terraform.tfstate | jq '.values.root_module.resources[] | select(.address=="google_sql_ssl_cert.client_cert") | .values.private_key' > private.key
terraform show -json terraform.tfstate | jq '.values.root_module.resources[] | select(.address=="google_sql_ssl_cert.client_cert") | .values.server_ca_cert' > server_ca.pem
```
- If after sending your Pubsub message there is no data in the created SQL table, then a program error has occurred in the Google Cloud Function. Go to that function in your web browser and then review its logs for error codes or more info.
 
### Rollback

- To roll back or undo your work in terraform, you run ```terraform destroy```.
- However, if you run ```terraform destroy``` for this project, it will throw an error on the SQL instance step.
- This is because terraform detects that the database is no longer empty - if you ran all the steps above this is true.
- To fix this, 
 	- first run ```drop table public.audit_data``` in your database client. 
 	- You will also need to "end" or "close" your connection or otherwise quit your database client.
- Once you have done both of these steps, now at the command line you can run ```terraform destroy``` and all of the terraform-created resources will be removed from your Google Cloud project.
- Note about running this terraform config multiple times: 
 	- Cloud SQL names are reserved for 10 days. 
 	- If you run ```terraform destroy```, and then re-run ```terraform apply```, you will get an error on the Cloud SQL step. 
 	- This is because even though terraform deleted the Cloud SQL instance, Google Cloud keeps its name reserved for up to ten days.
 	- To solve for this, each time you ```terraform apply``` after a ```terraform destroy```, you will first need to change the ```postgres-server-instance-name``` variable to a previously unused and new value.


_happy auditing!_
