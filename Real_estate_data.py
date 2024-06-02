import pandas as pd
from sqlalchemy import create_engine
from sqlalchemy import URL
from sqlalchemy.ext.declarative  import declarative_base
import pyodbc
from geopy.geocoders import Photon


#create connection string URL
con = URL.create(
        'mssql+pyodbc',
         host = 'ALEXANDRUPC\SQLSERVER2022',
         database= 'USdata',
         query = {
        "driver": "ODBC Driver 18 for SQL Server",
        "TrustServerCertificate": "yes",
        "authentication": "ActiveDirectoryIntegrated",
         },

)

#connect to DB
engine = create_engine(con)
query = '''SELECT * FROM RealEstateUS WHERE YEAR(Date_Recorded) = 2022 AND MONTH(Date_Recorded) = 1 and 
            Latitude IS NOT NULL AND Longitude IS NOT NULL'''

#Import SQL in a df
df = pd.read_sql(query, engine)


#Check first 10 rows
# print(df.head(10))

#Make a Nominatim object and initialize Nominatim API  with the geoapiExercises parameter.
geolocator = Photon(user_agent="measurements", timeout= None)

# #Create a new column "Exactlocation"
location_exact = []

#Combine latitude and longitude in a tuple, get exact location based on coordonates and append them in "location_exact"
for i1, i2 in zip(df['Latitude'], df['Longitude']):
    Latitude = str(i1)
    Longitude = str(i2)
    location = geolocator.reverse(Latitude+","+Longitude)
    location_exact.append(location)
    print(location)

#Append location exact in the table
df['exact_loc'] = location_exact

#Add new table in SQL
# df.to_sql("RealEstateJ2021", con=engine, if_exists='replace', index=False,)
df.to_csv(r'D:\Projects and practice\Git projects\RealEstateJ2021.csv')
