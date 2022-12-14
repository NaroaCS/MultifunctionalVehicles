model Loggers

import "./main.gaml"  //TODO: Add bid variables !!!

global { 
	map<string, string> filenames <- []; //Maps log types to filenames
	
	action registerLogFile(string filename) {
		filenames[filename] <- './../results/' + string(logDate, 'yyyy-MM-dd hh.mm.ss','en') + '/' + filename + '.csv';
	}
	
	action log(string filename, list data, list<string> columns) {
		if not(filename in filenames.keys) {
			do registerLogFile(filename);
			save ["Cycle", "Time", "NumBikes","Battery","AutDrivingSpeed",'MaxBiddingTime','PackBidCt','PackBidDist','PackBidQueue','PersonBidCt','PersonBidDist','PersonBidQueue','Agent'] + columns to: filenames[filename] type: "csv" rewrite: false header: false;
		}
		
		//if level <= loggingLevel {
		if loggingEnabled {
			save [cycle, string(current_date, "HH:mm:ss"), numAutonomousBikes, maxBatteryLifeAutonomousBike, DrivingSpeedAutonomousBike*3.6,maxBiddingTime,pack_bid_ct,pack_bid_dist_coef,pack_bid_queue_coef,person_bid_ct,person_bid_dist_coef,person_bid_queue_coef] + data to: filenames[filename] type: "csv" rewrite: false header: false;
		}
		if  printsEnabled {
			write [cycle, string(current_date,"HH:mm:ss")] + data;
		} 
	}
	
	action logForSetUp (list<string> parameters) {
		loop param over: parameters {
			save (param) to: './../results/' + string(logDate, 'yyyy-MM-dd hh.mm.ss','en') + '/' + 'setUp' + '.txt' type: "text" rewrite: false header: false;
		}
	}
	
	action logSetUp { 
		list<string> parameters <- [
		"NAutonomousBikes: "+string(numAutonomousBikes),
		
		"MaxWaitPeople: "+string(maxWaitTimePeople/60),
		"MaxWaitPackage: "+string(maxWaitTimePackage/60),

		"------------------------------SIMULATION PARAMETERS------------------------------",
		"Step: "+string(step),
		"Starting Date: "+string(starting_date),
		"Number of Days of Simulation: "+string(numberOfDays),
		"Number ot Hours of Simulation (if less than one day): "+string(numberOfHours),
		
		"People enabled: "+string(peopleEnabled),
		"Pakcages enabled: "+string(packagesEnabled),
		"Bidding enabled: "+string(biddingEnabled),
		

		"------------------------------BIKE PARAMETERS------------------------------",
		"Number of Bikes: "+string(numAutonomousBikes),
		"Max Battery Life of Bikes [km]: "+string(maxBatteryLifeAutonomousBike/1000 with_precision 2),
		"Autonomous driving speed [km/h]: "+string(DrivingSpeedAutonomousBike*3.6),
		"Minimum Battery [%]: "+string(minSafeBatteryAutonomousBike/maxBatteryLifeAutonomousBike*100),
		
		"------------------------------BIDDING PARAMETERS------------------------------",
		
		"Maximum bidding time [min]" +string(maxBiddingTime),
		"Package bidding constant: " +string(pack_bid_ct) ,
		"Package distance coefficient (-):" +string(pack_bid_dist_coef),
		"Package queue time coefficient: " +string(pack_bid_queue_coef),
		"Person bidding constant: " +string(person_bid_ct),
		"Person distance coefficient (-): " +string(person_bid_dist_coef),
		"Person queue time coefficient: " +string(person_bid_queue_coef),
			
		"------------------------------PEOPLE PARAMETERS------------------------------",
		"Maximum Wait Time People [min]: "+string(maxWaitTimePeople/60),
		"Walking Speed [km/h]: "+string(peopleSpeed*3.6),
		"Riding Speed Autonomous Bike [km/h]: "+string(RidingSpeedAutonomousBike*3.6),
		
		"------------------------------PACKAGE PARAMETERS------------------------------",
		"Maximum Wait Time Package [min]: "+string(maxWaitTimePackage/60),
		
		"------------------------------STATION PARAMETERS------------------------------",
		"Number of Charging Stations: "+string(numChargingStations),
		"V2I Charging Rate: "+string(V2IChargingRate  with_precision 2),
		
		"------------------------------MAP PARAMETERS------------------------------",
		"City Map Name: "+string(cityScopeCity),
		"Redisence: "+string(residence),
		"Office: "+string(office),
		"Usage: "+string(usage),
		"Color Map: "+string(color_map),
		
		"------------------------------LOGGING PARAMETERS------------------------------",
		"Print Enabled: "+string(printsEnabled),
		"Autonomous Bike Event/Trip Log: " +string(autonomousBikeEventLog),
		"People Trip Log: " + string(peopleTripLog),
		"Package Trip Log: "+ string(packageTripLog),
		"People Event Log: " + string(peopleEventLog),
		"Package Event Log:" + string(packageEventLog),
		"Station Charge Log: "+ string(stationChargeLogs),
		"Roads Traveled Log: " + string(roadsTraveledLog)
		];
		do logForSetUp(parameters);
		}
}

// Generic
species Logger {
	
	action logPredicate virtual: true type: bool;
	string filename;
	list<string> columns;
	
	agent loggingAgent;
	
	action log(list data) {
		if logPredicate() {
			ask host {
				do log(myself.filename, [string(myself.loggingAgent.name)] + data, myself.columns);
			} 
		}
	}
}

species peopleLogger_trip parent: Logger mirrors: people {
	string filename <- string("people_trips_"+string(nowDate.hour)+"_"+string(nowDate.minute)+"_"+string(nowDate.second));
	list<string> columns <- [
		"Trip Served",
		"Wait Time (min)",
		"Departure Time",
		"Arrival Time",
		"Duration (min)",
		"Origin [lat]",
		"Origin [lon]",
		"Destination [lat]",
		"Destination [lon]",
		"Distance (m)"
	];

	bool logPredicate { return peopleTripLog; }
	people persontarget;
	
	init {
		persontarget <- people(target);
		persontarget.tripLogger <- self;
		loggingAgent <- persontarget;
	}
	
	action logTrip( bool served, float waitTime, date departure, date arrival, float tripduration, point origin, point destination, float distance) {
		point origin_WGS84 <- CRS_transform(origin, "EPSG:4326").location; 
		point destination_WGS84 <- CRS_transform(destination, "EPSG:4326").location; 
		string dep;
		string des;
		
		if departure= nil {dep <- nil;}else{dep <- string(departure,"HH:mm:ss");}
		
		if arrival = nil {des <- nil;} else {des <- string(arrival,"HH:mm:ss");}
		
		do log([served, waitTime,dep ,des, tripduration, origin_WGS84.x, origin_WGS84.y, destination_WGS84.x, destination_WGS84.y, distance]);
	} 
}

species packageLogger_trip parent: Logger mirrors: package {
	string filename <- string("package_trips_"+string(nowDate.hour)+"_"+string(nowDate.minute)+"_"+string(nowDate.second));
	list<string> columns <- [
		"Trip Served",
		"Wait Time (min)",
		"Departure Time",
		"Arrival Time",
		"Duration (min)",
		"Origin [lat]",
		"Origin [lon]",
		"Destination [lat]",
		"Destination [lon]",
		"Distance (m)"
	];

	bool logPredicate { return packageTripLog; }
	package packagetarget;
	
	init {
		packagetarget <- package(target);
		packagetarget.tripLogger <- self;
		loggingAgent <- packagetarget;
	}
	
	action logTrip( bool served, float waitTime, date departure, date arrival, float tripduration, point origin, point destination, float distance) {
		
		point origin_WGS84 <- CRS_transform(origin, "EPSG:4326").location; 
		point destination_WGS84 <- CRS_transform(destination, "EPSG:4326").location;
			
		string dep;
		string des;
		
		if departure= nil {dep <- nil;}else{dep <- string(departure,"HH:mm:ss");}
		
		if arrival = nil {des <- nil;} else {des <- string(arrival,"HH:mm:ss");}
		
		do log([served, waitTime,dep ,des, tripduration, origin_WGS84.x, origin_WGS84.y, destination_WGS84.x, destination_WGS84.y, distance]);
	} 
}

species peopleLogger parent: Logger mirrors: people {
	string filename <- "people_event"+string(nowDate.hour)+"_"+string(nowDate.minute)+"_"+string(nowDate.second);
	list<string> columns <- [
		"Event",
		"Message",
		"Start Time",
		"End Time",
		"Duration (min)",
		"Distance (m)"
	];
	
	bool logPredicate { return peopleEventLog; }
	people persontarget;
	
	init {
		persontarget <- people(target);
		persontarget.logger <- self;
		loggingAgent <- persontarget;
	}
	
	float tripdistance <- 0.0;
	
	date departureTime;
	int departureCycle;
    int cycleAutonomousBikeRequested;
    float waitTime;
    int cycleStartActivity;
    date timeStartActivity;
    point locationStartActivity;
    string currentState;
    bool served;
    
    string timeStartstr;
    string currentstr;
	
	action logEnterState(string logmessage) {
		cycleStartActivity <- cycle;
		timeStartActivity <- current_date;
		locationStartActivity <- persontarget.location;
		currentState <- persontarget.state;
		if peopleEventLog {do log(['START: ' + currentState] + [logmessage]);}
		
		if peopleTripLog{ //because trips are logged by the eventLogger
			switch currentState {
				match "requestingAutonomousBike" {
					cycleAutonomousBikeRequested <- cycle;
					write  string(self)+"Autonomous bike requested at Cycle: "+cycleAutonomousBikeRequested;
					served <- false;
				}
				match "requested_with_bid" {
					cycleAutonomousBikeRequested <- cycle;
					write  string(self)+"Autonomous bike requested at Cycle: "+cycleAutonomousBikeRequested;
					served <- false;
				}
				match "riding_autonomousBike" {
					//trip is served
					write  string(self)+"Bike arrived at cycle : "+cycle;
					waitTime <- (cycle*step- cycleAutonomousBikeRequested*step)/60;
					write  string(self)+"wait time : "+waitTime;
					departureTime <- current_date;
					departureCycle <- cycle;
					served <- true;
				}
				match "wandering" {
					//trip has ended
					if tripdistance = 0 {
						write 'Error in tripdistance log User';
						//tripdistance <- persontarget.start_point distance_to persontarget.target_point;
						//TODO: review this ! 
					}
				
					if cycle != 0 {
						ask persontarget.tripLogger {
							do logTrip(
								myself.served,
								myself.waitTime,
								myself.departureTime,
								current_date,
								(cycle*step - myself.departureCycle*step)/60,
								persontarget.start_point.location,
								persontarget.target_point.location,
								myself.tripdistance
							);
						}
					}
				}
			}
		}
	}

	action logExitState(string logmessage) {
		
		if timeStartActivity= nil {timeStartstr <- nil;}else{timeStartstr <- string(timeStartActivity,"HH:mm:ss");}
		if current_date = nil {currentstr <- nil;} else {currentstr <- string(current_date,"HH:mm:ss");}
		
		do log(['END: ' + currentState, logmessage, timeStartstr, currentstr, (cycle*step - cycleStartActivity*step)/60, locationStartActivity distance_to persontarget.location]);
	}
	action logEvent(string event) {
		do log([event]);
	}
}

species packageLogger parent: Logger mirrors: package {
	string filename <- "package_event"+string(nowDate.hour)+"_"+string(nowDate.minute)+"_"+string(nowDate.second);
	list<string> columns <- [
		"Event",
		"Message",
		"Start Time",
		"End Time",
		"Duration (min)",
		"Distance (m)"
	];
	
	bool logPredicate { return packageEventLog; }
	package packagetarget;
	
	init {
		packagetarget <- package(target);
		packagetarget.logger <- self;
		loggingAgent <- packagetarget;
	}
	
	float tripdistance <- 0.0;
	
	date departureTime;
	int departureCycle;
	int cycleRequestingAutonomousBike;
    float waitTime;
    int cycleStartActivity;
    date timeStartActivity;
    point locationStartActivity;
    string currentState;
    bool served <- false;
    
    string timeStartstr;
    string currentstr;
	
	action logEnterState(string logmessage) {
		cycleStartActivity <- cycle;
		timeStartActivity <- current_date;
		locationStartActivity <- packagetarget.location;
		currentState <- packagetarget.state;
		if packageEventLog {do log(['START: ' + currentState] + [logmessage]);}
		
		if packageTripLog{ 
			switch currentState {
				match "requestingAutonomousBike" {
					cycleRequestingAutonomousBike <- cycle;
					served <- false;
				}
				match "requested_with_bid" {
					cycleRequestingAutonomousBike <- cycle;
					served <- false;
				}
				match "delivering_autonomousBike" {
					waitTime <- (cycle*step - cycleRequestingAutonomousBike*step)/60; 
					departureTime <- current_date;
					departureCycle <- cycle;
					served <- true;
				}
				match "delivered"{
					if tripdistance = 0 {
						tripdistance <- packagetarget.start_point distance_to packagetarget.target_point;
					}
				
					if cycle != 0 {
						ask packagetarget.tripLogger {
							do logTrip(
								myself.served,
								myself.waitTime,
								myself.departureTime,
								current_date,
								(cycle*step - myself.departureCycle*step)/60,
								packagetarget.start_point.location,
								packagetarget.target_point.location,
								myself.tripdistance
							);						
						}
					} 
				}
			}
		}
	}
	
	action logExitState(string logmessage) {
		
		if timeStartActivity= nil {timeStartstr <- nil;}else{timeStartstr <- string(timeStartActivity,"HH:mm:ss");}
		if current_date = nil {currentstr <- nil;} else {currentstr <- string(current_date,"HH:mm:ss");}
		
		do log(['END: ' + currentState, logmessage, timeStartstr, currentstr, (cycle*step - cycleStartActivity*step)/60, locationStartActivity distance_to packagetarget.location]);
	}
	action logEvent(string event) {
		do log([event]);
	}
}

species autonomousBikeLogger_chargeEvents parent: Logger mirrors: autonomousBike { //Station Charging
	string filename <- 'AutonomousBike_station_charge'+string(nowDate.hour)+"_"+string(nowDate.minute)+"_"+string(nowDate.second);
	list<string> columns <- [
		"Station",
		"Start Time",
		"End Time",
		"Duration (min)",
		"Start Battery %",
		"End Battery %",
		"Battery Gain %"
	];
	bool logPredicate { return stationChargeLogs; }
	autonomousBike autonomousBiketarget;
	string startstr;
	string endstr;
	
	init {
		autonomousBiketarget <- autonomousBike(target);
		autonomousBiketarget.chargeLogger <- self;
		loggingAgent <- autonomousBiketarget;
	}
	
	action logCharge(chargingStation station, date startTime, date endTime, float chargeDuration, float startBattery, float endBattery, float batteryGain) {
				
		if startTime= nil {startstr <- nil;}else{startstr <- string(startTime,"HH:mm:ss");}
		if endTime = nil {endstr <- nil;} else {endstr <- string(endTime,"HH:mm:ss");}
		
		do log([station, startstr, endstr, chargeDuration, startBattery, endBattery, batteryGain]);
	}
}

species autonomousBikeLogger_roadsTraveled parent: Logger mirrors: autonomousBike {
	
	string filename <- 'AutonomousBike_roadstraveled'+string(nowDate.hour)+"_"+string(nowDate.minute)+"_"+string(nowDate.second);
	list<string> columns <- [
		"Distance Traveled"
	];
	bool logPredicate { return roadsTraveledLog; }
	autonomousBike autonomousBiketarget;
	
	float totalDistance <- 0.0;
	
	init {
		autonomousBiketarget <- autonomousBike(target);
		autonomousBiketarget.travelLogger <- self;
		loggingAgent <- autonomousBiketarget;
	}
	
	action logRoads(float distanceTraveled) {
		
		totalDistance <- distanceTraveled;
		
		do log( [distanceTraveled]);
	}
}


species autonomousBikeLogger_event parent: Logger mirrors: autonomousBike {
	
	bool logPredicate { return autonomousBikeEventLog; }
	string filename <- 'autonomousBike_trip_event'+string(nowDate.hour)+"_"+string(nowDate.minute)+"_"+string(nowDate.second);
	list<string> columns <- [
		"Event",
		"Activity",
		"Message",
		"Start Time",
		"End Time",
		"Duration (min)",
		"Distance Traveled",
		"Start Battery %",
		"End Battery %",
		"Battery Gain %"
	];
	
	autonomousBike autonomousBiketarget;
	init {
		autonomousBiketarget <- autonomousBike(target);
		autonomousBiketarget.eventLogger <- self;
		loggingAgent <- autonomousBiketarget;
	}
	
	chargingStation stationCharging;
	float chargingStartTime;
	float batteryLifeBeginningCharge;
	
	int cycleStartActivity;
	date timeStartActivity;
	point locationStartActivity;
	float batteryStartActivity;
	string currentState;
	int activity;
	
	action logEnterState(string logmessage) {
		cycleStartActivity <- cycle;
		timeStartActivity <- current_date;
		batteryStartActivity <- autonomousBiketarget.batteryLife;
		locationStartActivity <- autonomousBiketarget.location;
		
		currentState <- autonomousBiketarget.state;
		
		activity <- autonomousBiketarget.activity;
		do log( ['START: ' + autonomousBiketarget.state] + [activity] + [logmessage]);
	}

	action logExitState(string logmessage) {
		float d <- autonomousBiketarget.travelLogger.totalDistance;
		string timeStartstr;
		string currentstr;
		
		if timeStartActivity= nil {timeStartstr <- nil;}else{timeStartstr <- string(timeStartActivity,"HH:mm:ss");}
		if current_date = nil {currentstr <- nil;} else {currentstr <- string(current_date,"HH:mm:ss");}
			
		do log( [
			'END: ' + currentState,
			activity,
			logmessage,
			timeStartstr,
			currentstr,
			(cycle*step - cycleStartActivity*step)/(60),
			d,
			batteryStartActivity/maxBatteryLifeAutonomousBike*100,
			autonomousBiketarget.batteryLife/maxBatteryLifeAutonomousBike*100,
			(autonomousBiketarget.batteryLife-batteryStartActivity)/maxBatteryLifeAutonomousBike*100
		]);
				
		if currentState = "getting_charge" {
			ask autonomousBiketarget.chargeLogger {
				do logCharge(
					chargingStation closest_to autonomousBiketarget,
					myself.timeStartActivity,
					current_date,
					(cycle*step - myself.cycleStartActivity*step)/(60),
					myself.batteryStartActivity/maxBatteryLifeAutonomousBike*100,
					autonomousBiketarget.batteryLife/maxBatteryLifeAutonomousBike*100,
					(autonomousBiketarget.batteryLife-myself.batteryStartActivity)/maxBatteryLifeAutonomousBike*100
				);
			}
		}
	}
}