import pandas as pd
from sqlalchemy import create_engine
from sqlalchemy import URL
from sqlalchemy.ext.declarative  import declarative_base
import pyodbc
from geopy.geocoders import Photon


#1. create connection string URL
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

#2. connect to DB
engine = create_engine(con)
query = '''SELECT * FROM RealEstateUS WHERE Latitude IS NOT NULL AND Longitude IS NOT NULL'''

#3.Import SQL in a dataframe
df = pd.read_sql(query, engine)


#4.Check first 10 rows
# print(df.head(10))


#5.Make a Nominatim object and initialize Nominatim API  with the geoapiExercises parameter.
geolocator = Photon(user_agent="measurements", timeout= None)


#6.Create a new column "Exactlocation"
location_exact = []

#7.Combine latitude and longitude in a tuple, get exact location based on coordonates and append them in "location_exact"
for i1, i2 in zip(df['Latitude'], df['Longitude']):
    Latitude = str(i1)
    Longitude = str(i2)
    location = geolocator.reverse(Latitude+","+Longitude)
    location_exact.append(location)


#8.Append location exact in the table
df['exact_loc'].update(location_exact)

print(type(df['Latitude']))

#9.Add new table in SQL
df.to_sql("RealEstateJ2022", con=engine, if_exists='replace', index=False)


# df.to_csv(r'D:\Projects and practice\Git projects\RealEstateJ2021.csv')
