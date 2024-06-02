# Analysis of real estate transactions in Connecticut, United states Jan 2021

## Overview:

In this project I used DML commands (Data Manipulation Language), such as UPDATE, DELETE to delete certain characters from rows, DDL commands(Data Definition Language) such as ALTER TABLE to add new columns to tables and DQL commands (Data Query Language) to perform various queries. <br>
Also, I have used **Python** with **SQLAlchemy** and **geopy** libraries to get a table from a database, get the exact location of each transaction based on two columns: Latitude and Longitude, and export the modified table back into the database.

## About the data source

The data set is a csv table with all the real estate sales > 2K dollars in Connecticut, US in January 2022. 
Link: https://catalog.data.gov/dataset/real-estate-sales-2001-2018

## How to navigate through this project:

The original data set was first modified in SQL, then the data was brought with Python. I have attached the modified data source, which will be used in the second part of this project, so you can run only the SQL scripts related to the modified dataset directly. In case you want to start from scratch, here's how:

1. First, get Latitude and Longitude from "Location" column.

```SQL
-- Delete word "POINT" from "Location" column and create a 2 new columns: Latitude and longitude based on 'Location' file

	-- Delete 'POINT' string and characters " )" "("
UPDATE RealEstateUS 
SET Location = TRIM('POINT( ' FROM Location);
GO

UPDATE RealEstateUS 
SET Location = TRIM(')' FROM Location);
GO

	-- Create new columns
ALTER TABLE RealEstateUS
ADD Latitude FLOAT  

ALTER TABLE RealEstateUS
ADD Longitude FLOAT  


	-- Update Latitude and Longitude columns
UPDATE RealEstateUS
SET Longitude = SUBSTRING(Location, 0, CHARINDEX(' ', Location, 0));

UPDATE RealEstateUS
SET Latitude = SUBSTRING(Location, CHARINDEX(' ', Location, 0)+1, LEN(Location));
```

2. Then, run the Python script. All you have to do is replace your DB credentials in this part:

```python
#1. create connection string URL
con = URL.create(
        '<your DB + DB Driver ',
         host = '<your instance name>',
         database= '<your DB name>',
         query = {
        "driver": "your DB driver",
        "TrustServerCertificate": "yes",
        "authentication": "ActiveDirectoryIntegrated",
         },

)
```

For the rest of the project, please visit the attached SQL file.

