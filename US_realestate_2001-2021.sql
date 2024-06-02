------------------------------Analysis of real estate transactions > 2k USD in United states Conneticut Jan 2022---------------------------
--Data source: Real estate transactions are from US The Office of Policy and Management: https://catalog.data.gov/dataset/real-estate-sales-2001-2018
	

USE USdata;


--1. This point was done in order to prepare the latitude and longitude for extraction in Python script. You can use the modified data set directly.

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



------------ Analysis of data set "TransactionsJ2022"

--2. Delete the spaces from the exact_loc column and update the able
UPDATE TransactionsJ2022
SET exact_loc = TRIM(exact_loc)


--3. Create a column rowid and create a backup table to get the state, country and posta code from extact_location column
ALTER TABLE TransactionsJ2022 --add a column 'rowid' auto incrementing with 1 for each row
ADD rowid int IDENTITY(1,1)


SELECT *
INTO 
TransactionsJ2022_backup
FROM
(
SELECT *, 
	'col'+CAST(
				ROW_NUMBER() OVER(PARTITION BY rowid ORDER BY rowid) AS VARCHAR
									) as col  --number each row partition by transaction nr. Transform in string and use them as col names
FROM TransactionsJ2022 as emp
Cross apply 
	string_split(exact_loc, ',') as Split --split by delimiter
) as tbl
Pivot(
		MAX(value) FOR col IN([col1], [col2], [col3], [col4], [col5], [col6], [col7], [col8])) --pivot rows int columns use aggregate as values
as piv


--Transform the back up table
--4. Delete column [col1[ as we don't need street nr
ALTER TABLE TransactionsJ2022_backup
DROP COLUMN col1



--5. Update col7, col5, col3, col6 with the appropiate values and rename them "Postal_code", "City", "State", "Country" 
UPDATE TransactionsJ2022_backup 
SET
	col7 = RIGHT(--use case to update 'col7' (the following "Country" col) with appropiate country from the last not null row value 
					exact_loc, CHARINDEX(' ,', REVERSE(exact_loc),0)-1
					),
	col5 =  --use case to update 'col5' if null row value (the following "City" col)
	CASE
		WHEN col5 IS NULL 
		THEN col3
		WHEN col5 = ' United States'
		THEN col3
		ELSE col5
	END,
	col3 = --use case to update 'col3'(the following "Postal code" column)  with values from other columns if not in col3 
	CASE
		WHEN LEN(col3) <> 6 AND LEN(col2) = 6 
			THEN col2
		WHEN LEN(col3) <> 6 AND LEN(col4) = 6 
			THEN col4
		ELSE col3
	END,
	col6 = --use case to update 'col6' with state name from column 'exact_loc'
		CASE 
			WHEN CHARINDEX(' ,', REVERSE(exact_loc)) > 0 AND CHARINDEX(' ,', REVERSE(exact_loc), CHARINDEX(' ,', REVERSE(exact_loc)) + 1) > 0 THEN  --if char lenght is >0, get data from 'exact_loc' column
				REVERSE(
					SUBSTRING(
						REVERSE(exact_loc),
						CHARINDEX(' ,', REVERSE(exact_loc)) + 2,  -- Start after the first delimiter (' ,')
						CHARINDEX(' ,', REVERSE(exact_loc), CHARINDEX(' ,', REVERSE(exact_loc)) + 1) - CHARINDEX(' ,', REVERSE(exact_loc)) - 2 -- Adjust length to stop before the second delimiter
					)
				)
			ELSE 'DefaultState' -- Or handle as appropriate
		END;

--Change column names:
sp_rename'TransactionsJ2022_backup.[col7]', 'Country', 'COLUMN' --change [col7] name to Country
sp_rename'TransactionsJ2022_backup.[col6]', 'State', 'COLUMN' --change [col6] name to State
sp_rename'TransactionsJ2022_backup.[col5]', 'City', 'COLUMN' --change [col5] name to City
sp_rename'TransactionsJ2022_backup.[col3]', 'Postal_code', 'COLUMN' --change [col3] name to Postal_code


--6. Delete othe columns that will not be used in the analysis and make "State" rows in the same format
ALTER TABLE TransactionsJ2022_backup
DROP COLUMN col2, col8


--Transform rows in "State" where format is not the same as most rows 

SELECT State, COUNT(*) as count_occur -- check the distinct rows in column 'State
FROM TransactionsJ2022_backup
GROUP BY State
ORDER BY State

UPDATE TransactionsJ2022_backup
SET	State =  -- change rows from 'Connecticut' to 'CT'
		CASE
			WHEN State = 'Connecticut'
			THEN 'CT'
			ELSE State
			END

DELETE FROM TransactionsJ2022_backup WHERE State <> 'CT' --delete other rows where state is unknown




--7. Create a temp table to store the sales amount by State and City for the first week
SELECT 
	State,
	City,
	ISNULL([1],0) _1,
	ISNULL([2],0) _2,
	ISNULL([3],0) _3,
	ISNULL([4],0) _4,
	ISNULL([5],0) _5,
	ISNULL([6],0) _6,
	ISNULL([7],0) _7
INTO #Transactionsbyday
FROM 
(SELECT 
	State,
	City,
	DAY(Date_Recorded) as trans_day,
	SUM(Sale_Amount) as total_sales
FROM TransactionsJ2022_backup
GROUP BY
	State,
	City,
	DAY(Date_Recorded)
	) as Main_tbl
PIVOT(
	SUM(total_sales)
	FOR trans_day IN ([1],[2],[3],[4],[5],[6],[7])
) as pivt


SELECT * FROM #Transactionsbyday --check


--8. Select the 2nd highest cummulated sales amount per city (if more than 1 transction was done per city, else return the only transaction) 
--Also, calculate the average sales value per city create another column to show the difference from the average sales amount per city)
SELECT
	City,
	Serial_Number,
	Sale_Amount,
	Avg_sales,
	Sale_Amount-Avg_sales as Diff
FROM
	(SELECT
		City,
		Serial_Number,
		Sale_Amount,
		AVG(Sale_Amount) OVER(PARTITION BY City) as avg_sales,
		CASE WHEN COUNT(Serial_Number) OVER(PARTITION BY City) = 1
			THEN 2
		ELSE DENSE_RANK() OVER (PARTITION BY City ORDER BY Sale_Amount DESC)
		END as rnk
		FROM TransactionsJ2022_backup 
	)
		as source
WHERE rnk = 2
ORDER BY City




--9. Update column "State" where null based on the Cities and postal codes where state is not null
UPDATE a
SET a.State = ISNULL(a.State, b.State)
FROM TransactionsJ2022_backup as a
JOIN TransactionsJ2022_backup as b
ON a.City = b.City
AND
b.State IS NOT NULL

--Check
SELECT * FROM TransactionsJ2022_backup
ORDER BY City;




--10. Show total property sales per property type by city and the number of transactions
WITH get_sales AS
(
SELECT 
	City,
	  CASE 
            WHEN Property_Type IS NULL THEN 'Unknown'
            ELSE Property_Type
			END as Property_type,
	SUM(Sale_Amount) as sales
FROM TransactionsJ2022_backup
GROUP BY 
	City,
	CASE 
            WHEN Property_Type IS NULL THEN 'Unknown'
            ELSE Property_Type
			END
)
Select
	DISTINCT(piv.City),
	ISNULL([Residential],0) Residential,
	ISNULL([Vacant Land], 0) [Vacant Land],
	ISNULL([Apartments], 0) [Apartments],
	ISNULL([Industrial], 0) [Industrial],
	ISNULL([Commercial], 0) [Commercial],
	ISNULL([Unknown], 0) [Unknown],
	COUNT(b.Serial_Number) OVER(PARTITION BY b.City) AS count_transact
FROM get_sales
PIVOT
(
SUM(sales)
FOR Property_type IN([Residential], [Vacant Land], [Apartments], [Industrial], [Commercial], [Unknown])
) as piv
INNER JOIN TransactionsJ2022_backup as b
ON piv.City = b.City
ORDER BY piv.City ASC



--11. DELETE columns Non_Use_Code, Assessor_Remarks, OPM_remarks from TransactionsJ2022_backup. Use transactions with SAVE TRANSACTION and ROLLBACK to be able to access its inital state
BEGIN TRANSACTION delete_cols --delete columns
	ALTER TABLE TransactionsJ2022_backup
	DROP COLUMN Non_Use_Code, Assessor_Remarks,OPM_remarks;
SAVE TRANSACTION savepoint1;

ROLLBACK TRANSACTION delete_cols; -- run if you want to go to intial state

SELECT * FROM TransactionsJ2022_backup;



--12. Count the number of properties sold and and avg sales amount by Property_type per day
WITH base_tbl AS
(
SELECT 
	DATEPART(d, Date_Recorded) as day,
	Serial_Number,
	Sale_Amount,
	CASE 
        WHEN Property_Type IS NULL THEN 'Unknown'
        ELSE Property_Type
		END as Property_type
FROM TransactionsJ2022_backup
)
SELECT	
	DISTINCT(day),
	AVG(Sale_Amount) as avg_sales,
	ISNULL([Residential],0) Residential,
	ISNULL([Vacant Land], 0) [Vacant Land],
	ISNULL([Apartments], 0) [Apartments],
	ISNULL([Industrial], 0) [Industrial],
	ISNULL([Commercial], 0) [Commercial],
	ISNULL([Unknown], 0) [Unknown]
FROM base_tbl
PIVOT
(COUNT(Serial_Number)
FOR Property_type IN([Residential], [Vacant Land], [Apartments], [Industrial], [Commercial], [Unknown])
) as piv
GROUP BY
	day,
	Residential,
	[Vacant Land],
	[Apartments],
	[Industrial],
	[Commercial],
	[Unknown]


SELECT * FROM RealEstateJ2022

SELECT * FROM RealEstateUS