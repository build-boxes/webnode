# Terraform Save State File in PostGresql (PG)

To save Terraform state in a PostgreSQL database, you can use the Terraform Remote Backend feature with the pg backend. This allows Terraform to store its state file in a PostgreSQL database, ensuring better collaboration and state management for teams. Below is a concise guide:
  
Steps to Configure Terraform to Save State in PostgreSQL
  
## Set Up PostgreSQL Database:

Ensure you have a running PostgreSQL instance.
Create a database and a table for storing the Terraform state:  
Copy the code
```
CREATE DATABASE terraform_state;
\c terraform_state
CREATE TABLE state (
    id SERIAL PRIMARY KEY,
    state_data JSONB NOT NULL
);
```

## Install PostgreSQL Backend Support:

Terraform natively supports the pg backend, so no additional plugins are required.

## Configure the Backend in Terraform:

Update your terraform block in the configuration file (e.g., main.tf) to use the pg backend:  
Copy the code
```
terraform {
  backend "pg" {
    conn_str = "postgresql://username:password@hostname:port/database_name"
    schema_name = "public"  # Optional, defaults to 'public'
    table_name  = "state"   # Table created earlier
  }
}
```
Replace username, password, hostname, port, and database_name with your PostgreSQL credentials and details.

## Initialize Terraform:

Run the following command to initialize the backend:  
Copy the code
```
terraform init
```

Terraform will migrate your state file to the PostgreSQL database.

## Verify State Storage:

After initialization, Terraform will store the state in the specified PostgreSQL table. You can query the table to confirm:  
Copy the code
```
SELECT * FROM state;
```

## Notes:
  - Security: Use environment variables or a secure secrets manager to avoid hardcoding sensitive credentials in your configuration.
  - Collaboration: The PostgreSQL backend is ideal for teams, as it ensures a single source of truth for the Terraform state.
  - Backup: Regularly back up your PostgreSQL database to prevent data loss.
  
Let me know if you'd like further clarification or assistance! 😊