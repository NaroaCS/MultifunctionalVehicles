import numpy as np
import pandas as pd
import os
import glob

#CHANGE folder  

os.chdir("../results/2022-12-06 01.00.00")


if True: #Load all csv files in directory and concat just once 
    extension = 'csv'

    #Bike trips
    bike_filenames =[i for i in glob.glob('autonomousBike_trip_event*.{}'.format(extension))]

    bike_df_temp= pd.DataFrame()
    bike_df_temp= pd.concat([pd.read_csv(f) for f in bike_filenames], ignore_index=True)
    print(bike_df_temp.head())
    bike_df_temp.to_csv('bike_concat.csv')

    #To check bug
    # for f in bike_filenames:
    #     df_f=pd.read_csv(f)
    #     print(f)
    #     print(df_f.shape)
    #     bike_df_temp=pd.concat([bike_df_temp,df_f])
    #     print(bike_df_temp.shape)

    #User trips
    user_filenames =[i for i in glob.glob('people_trips_*.{}'.format(extension))]
    user_df_temp= pd.concat([pd.read_csv(f) for f in user_filenames ], ignore_index=True)
    print(user_df_temp.head())
    user_df_temp.to_csv('user_concat.csv')

    #Package trips
    package_filenames =[i for i in glob.glob('package_trips_*.{}'.format(extension))]
    package_df_temp= pd.concat([pd.read_csv(f) for f in package_filenames ], ignore_index=True)
    print(package_df_temp.head())
    package_df_temp.to_csv('package_concat.csv')

#Read already concat .csv
#bike_df=pd.read_csv('bike_concat.csv')
#user_df=pd.read_csv('user_concat.csv')
#package_df=pd.read_csv('package_concat.csv')

if False:

    bike_df.drop(bike_df.loc[bike_df['Num Bikes']=='Num Bikes'].index, inplace=True)
    user_df.drop(user_df.loc[user_df['Num Bikes']=='Num Bikes'].index, inplace=True)
    error_bike=[1,3,4,5,6,7,8,9,10,16,18]
    error_user=[1,3,4,5,6,7,8,9,10,13,16,17,18,19,20,21]
    for i in error_bike:
        bike_df.iloc[:,i]=pd.to_numeric(bike_df.iloc[:,i])
    for i in error_user:
        user_df.iloc[:,i]=pd.to_numeric(user_df.iloc[:,i])
    user_df['Trip Served'] = user_df['Trip Served'].astype('bool')
    bike_df.to_csv('bike_concat.csv')
    user_df.to_csv('user_concat.csv')



# #
