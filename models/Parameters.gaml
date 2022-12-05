model Parameters

import "./main.gaml"

global {
	//----------------------Simulation Parameters------------------------
	
	//Simulation time step
	float step <- 2 #sec; //TODO: Change to 2 
	
	//Simulation starting date
	date starting_date <- date("2021-10-12 08:00:00"); 
	
	//Date for log files
	//date logDate <- #now;
	date logDate <- date("2022-12-05 14:53:00");
	
	date nowDate <- #now;
	
	//Duration of the simulation
	int numberOfDays <- 1; //WARNING: If >1 set numberOfHours to 24h
	int numberOfHours <- 24; //WARNING: If one day, we can also specify the number of hours, otherwise set 24h
	
	//----------------------Logging Parameters------------------------
	bool loggingEnabled <- true parameter: "Logging" category: "Logs";
	bool printsEnabled <- false parameter: "Printing" category: "Logs";
	
	bool autonomousBikeEventLog <-true parameter: "Autonomous Bike Event/Trip Log" category: "Logs";
	
	bool peopleTripLog <-true parameter: "People Trip Log" category: "Logs";
	bool peopleEventLog <-true parameter: "People Event Log" category: "Logs";
	
	bool packageTripLog <-true parameter: "Package Trip Log" category: "Logs";
	bool packageEventLog <-true parameter: "Package Event Log" category: "Logs";
		
	bool stationChargeLogs <- true parameter: "Station Charge Log" category: "Logs";
	
	bool roadsTraveledLog <- false parameter: "Roads Traveled Log" category: "Logs";
	
	//-----------------Autonomous Bike Parameters-----------------------
	int numAutonomousBikes <- 200				min: 0 max: 500 parameter: "Num Autonomous Bikes:" category: "Bike";
	float maxBatteryLifeAutonomousBike <- 50000.0 #m	min: 10000#m max: 70000#m parameter: "Autonomous Bike Battery Capacity (m):" category: "Bike"; //battery capacity in m
	float PickUpSpeedAutonomousBike <-  8/3.6 #m/#s min: 1/3.6 #m/#s max: 15/3.6 #m/#s parameter: "Autonomous Bike Pick-up Speed (m/s):" category:  "Bike";
	float RidingSpeedAutonomousBike <-  PickUpSpeedAutonomousBike min: 1/3.6 #m/#s max: 15/3.6 #m/#s parameter: "Autonomous Bike Riding Speed (m/s):" category:  "Bike";
	float minSafeBatteryAutonomousBike <- 0.25*maxBatteryLifeAutonomousBike #m; //Amount of battery at which we seek battery and that is always reserved when charging another bike
	//float nightSafeBatteryAutonomousBike <- 0.9*maxBatteryLifeAutonomousBike #m; 
	
	//----------------------numChargingStationsion Parameters------------------------
	//----------------------------------Before---------------------------------------
	/*int numChargingStations <- 75 	min: 1 max: 100 parameter: "Num Charging Stations:" category: "Initial";
	//float V2IChargingRate <- maxBatteryLife/(4.5*60*60) #m/#s; //4.5 h of charge
	float V2IChargingRate <- maxBatteryLifeAutonomousBike/(111) #m/#s;  // 111 s battery swapping -> average of the two reported by Fei-Hui Huang 2019 Understanding user acceptancd of battery swapping service of sustainable transport
	int chargingStationCapacity <- 16; //Average number of docks in bluebikes stations in April 2022*/
	
	//------------------------------------After--------------------------------------
	int numChargingStations <- 75 	min: 1 max: 100 parameter: "Num Charging Stations:" category: "Initial";
	//float V2IChargingRate <- maxBatteryLifeAutonomousBike/(4.5*60*60) #m/#s; //4.5 h of charge
	float V2IChargingRate <- maxBatteryLifeAutonomousBike/(111) #m/#s;  // 111 s battery swapping -> average of the two reported by Fei-Hui Huang 2019 Understanding user acceptancd of battery swapping service of sustainable transport
		
	//--------------------------People Parameters----------------------------
	int numPeople <- 250 				min: 0 max: 1000 parameter: "Num People:" category: "Initial";
	float maxWaitTimePeople <- 60 #mn		min: 3#mn max: 60#mn parameter: "Max Wait Time People:" category: "People";
	float maxWalkTimePeople <- 10 #mn  min: 1 #mn  max: 15 #mn parameter: "Max Walking Time People:" category: "People";
	float maxDistancePeople_AutonomousBike <- maxWaitTimePeople*PickUpSpeedAutonomousBike #m; //The maxWaitTime is translated into a max radius taking into account the speed of the bikes
    float peopleSpeed <- 5/3.6 #m/#s	min: 1/3.6 #m/#s max: 10/3.6 #m/#s parameter: "People Speed (m/s):" category: "People";
   	float maxDistancePeople_DocklessBike <- maxWalkTimePeople*peopleSpeed #m; 
    
    //--------------------------Package Parameters----------------------------
    float maxWaitTimePackage <- 1440 #mn		min: 3#mn max: 1440#mn parameter: "Max Wait Time Package:" category: "Package";
	float maxDistancePackage_AutonomousBike <- maxWaitTimePackage*PickUpSpeedAutonomousBike #m;
     
    //--------------------------Demand Parameters-----------------------------
    string cityDemandFolder <- "./../includes/Demand";
    csv_file demand_csv <- csv_file (cityDemandFolder+ "/user_demand_cambridge_oct12.csv",true); 
    csv_file pdemand_csv <- csv_file (cityDemandFolder+ "/fooddeliverytrips_cambridge.csv",true);
       
    //----------------------Map Parameters------------------------
	
	//Case - Cambridge
	string cityScopeCity <- "Cambridge";
	string residence <- "R";
	string office <- "O";
	string park <- "P";
	string health <- "H";
	string education <- "E";
	string usage <- "usage";
	
	map<string, rgb> color_map <- [residence::#papayawhip-10, office::#gray, park::#lightgreen, education::#lightblue, "Other"::#black];
    map<string, rgb> color_map_2 <-  [residence::#dimgray, office::#darkcyan, park::#darkolivegreen+15, education::#steelblue-50, "Other"::#black];
    
	//GIS FILES To Upload - Cambridge
	string cityGISFolder <- "./../includes/City/"+cityScopeCity;
	file bound_shapefile <- file(cityGISFolder + "/Bounds.shp")			parameter: "Bounds Shapefile:" category: "GIS";
	file buildings_shapefile <- file(cityGISFolder + "/Buildings.shp")	parameter: "Building Shapefile:" category: "GIS";
	file roads_shapefile <- file(cityGISFolder + "/Roads.shp")			parameter: "Road Shapefile:" category: "GIS";
	
	//Charging Stations - Cambridge
	csv_file chargingStations_csv <- csv_file(cityGISFolder+ "/bluebikes_stations_cambridge.csv",true);
	
	//Restaurants - Cambridge
	csv_file restaurants_csv <- csv_file (cityGISFolder+ "/restaurants_cambridge.csv",true);

	// Show Layers
	bool show_building <- true;
	bool show_road <- true;
	bool show_people <- true;
	bool show_restaurant <- true;
	bool show_chargingStation <- true;
	bool show_package <- true;
	bool show_autonomousBike <- true;			
}	