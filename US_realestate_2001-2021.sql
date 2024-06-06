------------------------------Analysis of real estate transactions > 2k USD in United states Conneticut Jan 2022---------------------------
--Data source: Real estate transactions are from US The Office of Policy and Management: https://catalog.data.gov/dataset/real-estate-sales-2001-2018
	

USE USdata;


--1. This point was done in order to prepare the latitude and longitude columns for location extraction with Python script.

-- Delete word "POINT" from "Location" column and create a 2 new columns: Latitude and longitude based on 'Location' file

  -- Delete 'POINT' string and characters " )" "("
UPDATE Real_Estate_Sales2022 
SET Location = TRIM('POINT( ' FROM Location);
GO

UPDATE Real_Estate_Sales2022 
SET Location = TRIM(')' FROM Location);
GO

  -- Create new columns
ALTER TABLE Real_Estate_Sales2022
ADD Latitude FLOAT  

ALTER TABLE Real_Estate_Sales2022
ADD Longitude FLOAT  


  -- Update Latitude and Longitude columns
UPDATE Real_Estate_Sales2022
SET Longitude = SUBSTRING(Location, 0, CHARINDEX(' ', Location, 0));

UPDATE Real_Estate_Sales2022
SET Latitude = SUBSTRING(Location, CHARINDEX(' ', Location, 0)+1, LEN(Location));






------------ Second part. Analysis of data set "Transactions2022"

--2. Delete the spaces from the exact_loc column and update the able
UPDATE Transactions2022
SET exact_loc = TRIM(exact_loc)


--3. Add a column "rowid" and create a backup table to get the State, Country and postal code from "extact_loc" column
ALTER TABLE Transactions2022--add a column 'rowid' auto incrementing with 1 for each row
ADD rowid int IDENTITY(1,1)


SELECT *
INTO 
#TransactionsJ2022_backup
FROM
(
SELECT *, 
	'col'+CAST(
				ROW_NUMBER() OVER(PARTITION BY rowid ORDER BY rowid) AS VARCHAR
									) as col  --number each row partition by transaction nr. Transform in string and use them as col names
FROM Transactions2022 as emp
Cross apply 
	string_split(exact_loc, ',') as Split --split by delimiter
) as tbl
Pivot(
		MAX(value) FOR col IN([col1], [col2], [col3], [col4], [col5], [col6], [col7], [col8])) --pivot rows int columns use aggregate as values
as piv

SELECT * FROM #TransactionsJ2022_backup

DROP TABLE #TransactionsJ2022_backup



--4. Delete column [col1] as we don't need street nr
ALTER TABLE TransactionsJ2022_backup
DROP COLUMN col1




--5. Check col7, col5, col3, col6 and replace wrong values. Rename them "Postal_code", "City", "State", "Country" ,"Address"
UPDATE #TransactionsJ2022_backup 
SET
	col7 = RIGHT(
					exact_loc, CHARINDEX(' ,', REVERSE(exact_loc),0)-1 -- to make it easy, I extracted the country name using CHARINDEX as not all rows were correct 
																		-- due to the variable nr of values in "exact_loc" column
					),
	col5 =  --if null or ' United States', use values from col3 (the following "City" col)
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
		END,
	col4=  -- if col4 is a Postal Code OR 'United States' OR 'Connecticut' OR NULL, replace with col1 else don't replace
		CASE
			WHEN ISNUMERIC(col4) = 1
			THEN col1
			WHEN col4 = ' United States'
			THEN col1
			WHEN col4 = ' Connecticut'
			THEN col1
			WHEN col4 IS NULL
			THEN col1
		ELSE col4
		END


SELECT * FROM #TransactionsJ2022_backup

--Change column names:
USE tempdb

EXEC sp_rename'#TransactionsJ2022_backup.[col7]', 'Country', 'COLUMN' --change [col7] name to Country
EXEC sp_rename'#TransactionsJ2022_backup.[col6]', 'State', 'COLUMN' --change [col6] name to State
EXEC sp_rename'#TransactionsJ2022_backup.[col5]', 'City', 'COLUMN' --change [col5] name to City
EXEC sp_rename'#TransactionsJ2022_backup.[col4]', 'Address', 'COLUMN' --change [col4] name to Address
EXEC sp_rename'#TransactionsJ2022_backup.[col3]', 'Postal_code', 'COLUMN' --change [col3] name to Postal_code




--6. Change rows where State is "Connecticut" to CT, then delete rows that are not 'CT'. Replace string rows from "Postal_code" column with NULL.
USE USdata
GO

--Transform rows in "State" where format is not the same as most rows 
UPDATE #TransactionsJ2022_backup
SET	State =  -- change rows from 'Connecticut' to 'CT'
		CASE
			WHEN State = 'Connecticut'
			THEN 'CT'
			ELSE State
			END

DELETE FROM #TransactionsJ2022_backup WHERE State <> 'CT' --delete other rows where state is unknown




--Where postal code is string, repalce with NULL
UPDATE #TransactionsJ2022_backup
SET Postal_code=
	CASE
		WHEN ISNUMERIC(Postal_code) = 1
		THEN Postal_code
		ELSE NULL
		END

ALTER TABLE TransactionsJ2022_backup
DROP COLUMN col1, col2, col8
GO

 --Check final result
SELECT * FROM #TransactionsJ2022_backup




--7. Create a temp table to store total sales by State and City in the first week
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
FROM #TransactionsJ2022_backup
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




--8. Select the 2nd highest  sales amount per city (if more than 1 transction was done per city, else return the only transaction) 
--Also, calculate the average sales value per city create another column to show the difference from the average sales amount per city)
SELECT
	City,
	Serial_Number,
	Sale_Amount,
	ROUND(Avg_sales, 0) as Average,
	ROUND(Sale_Amount-Avg_sales,0) as Difference
FROM
	(SELECT
		City,
		Serial_Number,
		Sale_Amount,
		AVG(Sale_Amount) OVER(PARTITION BY City) as avg_sales,
		CASE 
			WHEN COUNT(Serial_Number) OVER(PARTITION BY City) = 1
			THEN 2
			ELSE DENSE_RANK() OVER (PARTITION BY City ORDER BY Sale_Amount DESC)
		END as rnk
		FROM #TransactionsJ2022_backup
	)
		as source
WHERE rnk = 2
ORDER BY City





--9. Show total property sales per property type by city and count the total number of transactions per city (regardless of property type).
WITH get_sales AS
(
SELECT 
	City,
	CASE 
        WHEN Property_Type IS NULL THEN 'Unknown'
        ELSE Property_Type
	END as Property_type,
	SUM(Sale_Amount) as sales
FROM #TransactionsJ2022_backup
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
INNER JOIN #TransactionsJ2022_backup as b
ON piv.City = b.City
ORDER BY piv.City ASC




--10. DELETE columns Non_Use_Code, Assessor_Remarks, OPM_remarks from TransactionsJ2022_backup. Use transactions with SAVE TRANSACTION and ROLLBACK to be able to access its inital state
BEGIN TRANSACTION delete_cols --delete columns
	ALTER TABLE #TransactionsJ2022_backup
	DROP COLUMN Non_Use_Code, Assessor_Remarks,OPM_remarks;
SAVE TRANSACTION savepoint1;

ROLLBACK TRANSACTION delete_cols; -- run if you want to go to intial state

SELECT * FROM #TransactionsJ2022_backup;



--11. Count the number of properties sold per property type by day.
--Calculate the average sales amount per day
WITH base_tbl AS
(
SELECT 
	DATEPART(d, Date_Recorded) as transaction_day,
	Serial_Number,
	AVG(Sale_Amount) OVER(PARTITION BY DATEPART(d, Date_Recorded)) as avg_daily_sales,
	CASE 
        WHEN Property_Type IS NULL THEN 'Unknown'
        ELSE Property_Type
		END as Property_type
FROM #TransactionsJ2022_backup
)
SELECT	
	transaction_day,
	ROUND(avg_daily_sales,0) AS average_daily_sales,
	ISNULL([Residential],0) residential,
	ISNULL([Vacant Land], 0) [vacant land],
	ISNULL([Apartments], 0) [apartments],
	ISNULL([Industrial], 0) [industrial],
	ISNULL([Commercial], 0) [commercial],
	ISNULL([Unknown], 0) [unknown]
FROM base_tbl
PIVOT
(COUNT(Serial_Number)
FOR Property_type IN([Residential], [Vacant Land], [Apartments], [Industrial], [Commercial], [Unknown])
) as piv
ORDER BY
	transaction_day

