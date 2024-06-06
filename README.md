# Analysis of real estate transactions from Connecticut, United states, January 2021

## Overview:
The scope of this project is to used SQL modify, query and find insights in the data using DML commands (Data Manipulation Language), such as UPDATE and DELETE to modify or delete certain characters from the data source, DDL commands(Data Definition Language) such as ALTER TABLE to add new columns, and other commands (subqueries, date functions, aggreations, Case, CTEs, Temporary tables, Transactions) <br>
Also, I have used **Python** with **SQLAlchemy** and **Pandas** libraries to import data from a database, to append the new generated column to the data frame, and to export it into a .csv file. To extract the exact location I used  **geopy library** , based on two columns: Latitude and Longitude.
 

## About the data source
The data set is a csv table from United States Open Data portal, with all the real estate transactions over 2K dollars in Connecticut, US in January 2022. 
Link: https://catalog.data.gov/dataset/real-estate-sales-2001-2018



## How to navigate through this project:
I have attached the initial data set, as well as the modified data source, so you can run only the SQL scripts related to the modified dataset directly. 
**Data set without exact location:** Real_Estate_Sales2022.csv
**Data set with exact location:** Transactions2022.csv

In case you are interested to start from scratch and create the modified CSV file, here's how:


1. First, run these SQL commands to create "Latitude" and "Longitude" columns from "Location" column.

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

2. Then, run the Python script "Import_location.py". All you have to do is replace your DB credentials and a file path in this parts of the code block:

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

#9.Export the table in CSV format
df.to_csv(r'<Your directory path>\Transactions2022.csv', index=False)

```
And that's it, you are all set! A new CSV file will be generated with the Postal Code, Street Number, Street Name, City, State, Country. All you have to do is to import the table into your DMBS and run the rest of the queries of this SQL file.


## Questions answered:
1. What were the total sales per State and City in the first week? Create a temporary table to store this data, with days of the week as columns.
2. What is the 2nd highest cummulated sales amount per city (if more than 1 transction was done per city, else return the only transaction). 
Also, calculate the average sales value per city and create another column to show the difference between average sales amount per city and 2nd highest sales amount.
3. What were the total sales per property type by city? How many transactions were done per city?
4. What was the total number of properties sold, for each property type, per day? What was the average sales amount per day regardless of property type?



## Transformations done:
1. Delete white space from column "exact_loc" table Transactions2022.
2. Add a new index column "rowid" in table Transactions2022. It must  be auto incremental.
3. Create a backup temporary table called "Transactions2022_backup" and add 6 columns by splitting "exact_loc"  before delimiter ','..
4. I used CHARINDEX, SUBSTRING AND REVERSE to clear the null or compatible values from the previous 6 new columns added by taking advantage of certain patterns in the data. Then, I renamed the columns.
5. Delete "col8", "col1", "col2" as it was not useful for this project.
6. Create a temporary table to store total sales by State and City in the first week.