model Agents

import "./main.gaml"

global {
	
	float distanceInGraph (point origin, point destination) {
		return (origin distance_to destination using topology(roadNetwork));
	}
	
	/*list<autonomousBike> availableAutonomousBikes(people person , package delivery) {
		return autonomousBike where (each.availableForRideAB());
	}*/
	
   bool bidForBike(people person, package pack){
		
		//Get list of bikes that are available
		list<autonomousBike> availableBikes <- (autonomousBike where each.availableForRideAB());
		
		//If there are no bikes available in the city, return false
		if empty(availableBikes){
			return false;
		}else if person != nil{ //If person request
		
			point personIntersection <- roadNetwork.vertices closest_to(person); //Cast position to road node
			autonomousBike b <- autonomousBike closest_to(personIntersection); //Get closest bike
			float d<- distanceInGraph(personIntersection,b.location); //Get distance on roadNetwork
		
			if d >maxDistancePeople_AutonomousBike{
				return false;	 //If closest bike is too far, return false
			}else{
				float bidValuePerson <- (100-d+person.queueTime); 
				// Bid value ct is higher for people, its smaller for larger distances, and larger for larger queue times
				
				ask b { do receiveBid(person,nil,bidValuePerson);} //Send bid value to bike
				return true;
			}
		}else if pack !=nil{ // If package request
		
			point packIntersection <- roadNetwork.vertices closest_to(pack); //Cast position to road node
			autonomousBike b <- autonomousBike closest_to(packIntersection); //Get closest bike
			float d<- distanceInGraph(packIntersection,b.location); //Get distance on roadNetwork
		
			if d >maxDistancePackage_AutonomousBike{
				return false;	 //If closest bike is too far, return false
			}else{
				float bidValuePackage <- (50-d+pack.queueTime); 
				// Bid value ct is lower for packages, its smaller for larger distances, and larger for larger queue times
				
				ask b { do receiveBid(nil,package,bidValuePackage);} //Send bid value to bike
				return true;
			}
			
		}else{
			write 'ERROR in bidForBike caller'; return false;
		}
	
	}
	
	bool bikeAssigned(people person, package pack){
		if person != nil{
			if person.autonomousBikeToRide !=nil{ 
				return true;
			}else{
				return false;
			}
		}else if pack !=nil{ 
			if pack.autonomousBikeToDeliver !=nil{
				return true;
			}else{
				return false;
			}
		}else{
			return false;
		}
	}
		
		
/* 	bool requestAutonomousBike(people person, package pack, point destination) {
	 


		list<autonomousBike> available <- availableAutonomousBikes(person, pack);
		
		if empty(available) {
			return false;
		} else {
			if person != nil{ //People demand
			
			point personIntersection <- roadNetwork.vertices closest_to(person);
			autonomousBike b <- autonomousBike closest_to(personIntersection); 
			float d<- distanceInGraph(personIntersection,b.location);
			//write 'Distance in graph: ' + d;
			if d<maxDistancePeople_AutonomousBike {
					ask b { do pickUp(person, nil);}
					ask person {do ride(b);}
					return true;
			}else {
					return false; // If it is NOT close enough
				}
						
			} else if pack != nil{ //Package demand
			

				//Then just select closest bike
				autonomousBike b <- available closest_to(pack);
				ask b { do pickUp(nil,pack);}
				ask pack { do deliver(b);}
				return true;
				
			} else { 
				write 'Error in request bike'; //Because no one made this request
				return false;
			}
			
		}
		

	}*/
		
}

species road {
	aspect base {
		draw shape color: rgb(125, 125, 125);
	}
}

species building {
    aspect type {
		//draw shape color: color_map[type] border:color_map[type];
		draw shape color: color_map_2[type]-75 ;
	}
	string type; 
}


species chargingStation{
	
	list<autonomousBike> autonomousBikesToCharge;
	
	rgb color <- #deeppink;
	
	float lat;
	float lon;
	int capacity; 
	
	aspect base{
		draw hexagon(25,25) color:color border:#black;
	}
	
	reflex chargeBikes {
		ask capacity first autonomousBikesToCharge {
			batteryLife <- batteryLife + step*V2IChargingRate;
		}
	}
}

species restaurant{
	
	rgb color <- #sandybrown;
	
	float lat;
	float lon;
	point rest;
	
	aspect base{
		draw circle(10) color:color;
	}
}

species intersection {
	int id;	
}

species package control: fsm skills: [moving] {

	rgb color;
	
    map<string, rgb> color_map <- [
    	
    	"generated":: #transparent,
    	"firstmile":: #lightsteelblue,
    	"requestingAutonomousBike"::#red,
		"awaiting_autonomousBike_package":: #yellow,
		"delivering_autonomousBike":: #yellow,
		"lastmile"::#lightsteelblue,
		"retry":: #red,
		"delivered":: #transparent
	];
	
	packageLogger logger;
    packageLogger_trip tripLogger;
    
	date start_hour;
	float start_lat; 
	float start_lon;
	float target_lat; 
	float target_lon;
	
	point start_point;
	point target_point;
	int start_h;
	int start_min;
	
	autonomousBike autonomousBikeToDeliver;
	people person;
	
	point final_destination; 
    point target; 
    float waitTime;
    float queueTime;
    bool bidClear <- False;
        
	aspect base {
    	color <- color_map[state];
    	draw square(15) color: color border: #black;
    }
    
	action deliver(autonomousBike ab){
		autonomousBikeToDeliver <- ab;
	}
	
	reflex updateQueueTime{
		
		if timeToTravel = True{
			if (current_date.hour = start_h) {
				queueTime <- (current_date.minute - start_min);
			} else if (current_date.hour > start_h){
				queueTime <- (current_date.hour-start_h)*60 + (60 - start_min);	
			}
		}
		
	}
	
	bool timeToTravel { return ((current_date.hour = start_h and current_date.minute >= (start_min)) or (current_date.hour > start_h)) and !(self overlaps target_point); }

	
	int register <- 1;
	
	state generated initial: true {
    	
    	enter {
    		if register=1 and (packageEventLog or packageTripLog) {ask logger { do logEnterState;}}
    		target <- nil;
    	}
    	transition to: bidding when: timeToTravel() {
    		final_destination <- target_point;
    	}
    	exit {
			if register=1 and (packageEventLog) {ask logger { do logExitState; }}
		}
    }
    
    state bidding {
    	enter {
    		bidClear <-False;
    		if register = 1 and (packageEventLog or packageTripLog) {ask logger { do logEnterState; }}    		
    		if !host.bidForBike(nil,self) {
    			register <- 0;
    		} else {
    			register <- 1;
    		}
    	}
    	transition to: awaiting_bike_assignation when: register = 1{		
    	}
    	transition to: retry_bid when: register = 0 {
    	}
    	exit {
    		if register = 1 and packageEventLog {ask logger { do logExitState; }}
		}
    }
    
    state awaiting_bike_assignation { //TODO: if the bike decides, we need to bid for another one!
		    enter {
		    if register = 1 and (packageEventLog or packageTripLog) {ask logger { do logEnterState; }}    
		    if !host.bikeAssigned(nil,self) {
		    register <- 0;
		    } else {
		    register <- 1;
		    }
		    }
		    transition to: firstmile when: register = 1{
		    	target <- (road closest_to(self)).location;
		    }
		    transition to: wait_bidding when: register = 0 {
		    }
		    transition to: bidding when bidClear = True {
		    }
		    exit {
		    if register = 1 and packageEventLog {ask logger { do logExitState; }}
		}
   
    }

    
    state retry_bid {transition to: bidding{ } } // TODO: review if we can simplify these two processes
	state wait_bidding {transition to: awaiting_bike_reassignation{ }}
	
	state firstmile {
		enter{
			if packageEventLog or packageTripLog {ask logger{ do logEnterState;}}
		}
		transition to: awaiting_autonomousBike_package when: location=target{}
		exit {
			if packageEventLog {ask logger{do logExitState;}}
		}
		do goto target: target on: roadNetwork;
	}
	
	state awaiting_autonomousBike_package {
		enter {
			if packageEventLog or packageTripLog {ask logger { do logEnterState( "awaiting " + string(myself.autonomousBikeToDeliver) ); }}
		}
		transition to: delivering_autonomousBike when: autonomousBikeToDeliver.state = "in_use_packages" {target <- nil;}
		exit {
			if packageEventLog {ask logger { do logExitState; }}
		}
	}
	
	state delivering_autonomousBike {
		enter {
			if packageEventLog or packageTripLog {ask logger { do logEnterState( "delivering " + string(myself.autonomousBikeToDeliver) ); }}
		}
		transition to: lastmile when: autonomousBikeToDeliver.state != "in_use_packages" {
			target <- final_destination;
		}
		exit {
			if packageEventLog {ask logger { do logExitState; }}
			autonomousBikeToDeliver<- nil;
		}
		location <- autonomousBikeToDeliver.location; 
	}
	
	state lastmile {
		enter{
			if packageEventLog or packageTripLog {ask logger{ do logEnterState;}}
		}
		transition to:delivered when: location=target{}
		exit {
			if packageEventLog {ask logger{do logExitState;}}
		}
		do goto target: target on: roadNetwork;
	}
	
	state delivered {
		enter{
			if packageEventLog or packageTripLog {ask logger{ do logEnterState;}}
		}
	}
}

species people control: fsm skills: [moving] {

	rgb color;
	
    map<string, rgb> color_map <- [
    	"wandering":: #blue,
		"requesting_autonomousBike":: #springgreen,
		"awaiting_autonomousBike":: #springgreen,
		"riding_autonomousBike":: #gamagreen,
		"firstmile":: #blue,
		"lastmile":: #blue
	];
	
	//loggers
    peopleLogger logger;
    peopleLogger_trip tripLogger;
    
    package delivery;

	//raw
	date start_hour; 
	float start_lat; 
	float start_lon;
	float target_lat;
	float target_lon;
	 
	//adapted
	point start_point;
	point target_point;
	int start_h; 
	int start_min; 
    
    autonomousBike autonomousBikeToRide;
    
    point final_destination;
    point target;
    float waitTime;
    float queueTime;
    bool bidClear <-False;
    
    aspect base {
    	color <- color_map[state];
    	draw circle(10) color: color border: #black;
    }
    
    //----------------PUBLIC FUNCTIONS-----------------
	
    action ride(autonomousBike ab) {
    	if ab!=nil{
    		autonomousBikeToRide <- ab;
    	}
    }
    	
	reflex updateQueueTime{
		
		if timeToTravel{
			if (current_date.hour = start_h) {
				queueTime <- (current_date.minute - start_min);
			} else if (current_date.hour > start_h){
				queueTime <- (current_date.hour-start_h)*60 + (60 - start_min);	
			}
		}
		
	}
    bool timeToTravel { return (current_date.hour = start_h and current_date.minute >= start_min) and !(self overlaps target_point); }
    
    state wandering initial: true {
    	enter {
    		if peopleEventLog or peopleTripLog {ask logger { do logEnterState; }}
    		target <- nil;
    	}
    	transition to: requesting_autonomousBike when: timeToTravel() {
       		final_destination <- target_point;
    	}
    	exit {
			if peopleEventLog {ask logger { do logExitState; }}
		}
    }
    
    state bidForBike {
		enter {
			bidClear <- False;
			if peopleEventLog or peopleTripLog {ask logger { do logEnterState; }} 
		}
		transition to: awaiting_bike_assignation when: host.bidForBike(self, nil) {
		}
		transition to: wandering {
			if peopleEventLog {ask logger { do logEvent( "Used another mode, wait too long" ); }}
			location <- final_destination;
		}
		exit {
			if peopleEventLog {ask logger { do logExitState("Bidding sent"); }}
		}
		
	}
    
	state awaiting_bike_assignation { //TODO: if the bike decides, we need to bid for another one!
		enter {
			if peopleEventLog or peopleTripLog {ask logger { do logEnterState; }} 
		}
		transition to: firstmile when: host.bikeAssigned(self, nil) {
			target <- (road closest_to(self)).location;
		}
		transition to: wait_bidding when: !host.bikeAssigned(self, nil) {
		}
		transition to: bidForBike when: bidClear = True{
			
		}
		exit {
			if peopleEventLog {ask logger { do logExitState("Requested Bike " + myself.autonomousBikeToRide); }}
		}
		
	}
	
	state wait_bidding {transition to: awaiting_bike_reassignation{ }}
	
	state firstmile {
		enter{
			if peopleEventLog or peopleTripLog {ask logger{ do logEnterState;}}
		}
		transition to: awaiting_autonomousBike when: location=target{}
		exit {
			if peopleEventLog {ask logger{do logExitState;}}
		}
		do goto target: target on: roadNetwork;
	}
	
	state awaiting_autonomousBike {
		enter {
			if peopleEventLog or peopleTripLog {ask logger { do logEnterState( "awaiting " + string(myself.autonomousBikeToRide) ); }}
		}
		transition to: riding_autonomousBike when: autonomousBikeToRide.state = "in_use_people" {target <- nil;}
		exit {
			if peopleEventLog {ask logger { do logExitState; }}
		}
	}
	
	state riding_autonomousBike {
		enter {
			if peopleEventLog or peopleTripLog {ask logger { do logEnterState( "riding " + string(myself.autonomousBikeToRide) ); }}
		}
		transition to: lastmile when: autonomousBikeToRide.state != "in_use_people" {
			target <- final_destination;
		}
		exit {
			if peopleEventLog {ask logger { do logExitState; }}
			autonomousBikeToRide <- nil;
		}
		location <- autonomousBikeToRide.location; //Always be at the same place as the bike
	}
	
	state lastmile {
		enter{
			if peopleEventLog or peopleTripLog {ask logger{ do logEnterState;}}
		}
		transition to:wandering when: location=target{}
		exit {
			if peopleEventLog {ask logger{do logExitState;}}
		}
		do goto target: target on: roadNetwork;
	}
}

species autonomousBike control: fsm skills: [moving] {
	
	//----------------Display-----------------
	rgb color;
	
	map<string, rgb> color_map <- [
		"wandering"::#blue,
		
		"low_battery":: #red,
		//"night_recharging":: #orangered,
		"getting_charge":: #red,
		//"getting_night_charge":: #orangered,
		//"night_relocating":: #springgreen,
		
		"picking_up_people"::#springgreen,
		"picking_up_packages"::#mediumorchid,
		"in_use_people"::#gamagreen,
		"in_use_packages"::#gold
	];
	
	aspect realistic {
		color <- color_map[state];
		draw triangle(35) color:color border:color rotate: heading + 90 ;
	} 

	//loggers
	autonomousBikeLogger_roadsTraveled travelLogger;
	autonomousBikeLogger_chargeEvents chargeLogger;
	autonomousBikeLogger_event eventLogger;
	    
	/* ========================================== PUBLIC FUNCTIONS ========================================= */
	
	people rider;
	package delivery;
	int activity; //0=Package 1=Person
	
	list<string> rideStates <- ["wandering"]; 
	bool lowPass <- false;
	
	
	float highestBid <- 0;
	people highestBidderUser;
	package highestBidderPackage;
	list<people> personBidders;
	list<package> packageBidders;
	
	int bid_start_h;
	int bid_start_min;
	
	bool availableForRideAB {
		return (state in rideStates) and self.state="wandering" and !setLowBattery() and rider = nil  and delivery=nil;
	}
	

	action pickUp(people person, package pack) { 
		
		if person != nil{
			
			rider <- person;
			activity <- 1;
		} else if pack != nil {
			
			delivery <- pack;
			activity <- 0;
		}
	}
	

	/* ========================================== PRIVATE FUNCTIONS ========================================= */
	//---------------BATTERY-----------------
	
	bool setLowBattery { 
		if batteryLife < minSafeBatteryAutonomousBike { return true; } 
		else {
			return false;
		}
	}
	/*bool setNightChargingTime { 
		if (batteryLife < nightSafeBatteryAutonomousBike) and (current_date.hour>=2) and (current_date.hour<5){ return true; } 
		else {
			return false;
		}
	}*/
	float energyCost(float distance) {
		return distance;
	}
	action reduceBattery(float distance) {
		batteryLife <- batteryLife - energyCost(distance); 
	}
	//----------------MOVEMENT-----------------
	point target;
	//point nightorigin;
	
	float batteryLife min: 0.0 max: maxBatteryLifeAutonomousBike; 
	float distancePerCycle;
	
	float distanceTraveledBike;
	path travelledPath; 
	
	bool canMove {
		return ((target != nil and target != location)) and batteryLife > 0;
	}
	

		
	path moveTowardTarget {
		if (state="in_use_people" or state="in_use_packages"){return goto(on:roadNetwork, target:target, return_path: true, speed:RidingSpeedAutonomousBike);}
		return goto(on:roadNetwork, target:target, return_path: true, speed:PickUpSpeedAutonomousBike);
	}
	
	reflex move when: canMove() {
		
		travelledPath <- moveTowardTarget();
		
		float distanceTraveled <- host.distanceInGraph(travelledPath.source,travelledPath.target);
		
		do reduceBattery(distanceTraveled);
	}

	action receiveBid(people person, package pack, float bidValue){
		if person != nil{
			add person to: personBidders;
		}else if pack != nil{
			add pack to: packageBidders;
		}
		if higestBid = 0 { //First bid
			bid_start_h <- current_date.h;
			bid_start_min <- current_date.min;
		}
		if bidValue > highestBid { 
		//If the current bid value is larger than the previous max, we updare it
			highestBidderUser <- nil;
			highestBidderPackage <- nil;
			highestBid <- bidValue;
			if person !=nil {
				highestBidderUser <- person;
			}else if package !=nil{
				highestBidderPackage <- pack;	
			}else{
				write 'Error in receiveBid()';
			}
		}

	}
	
	reflex endBid(){
		if (current_date.h = bid_start_h and current_date.min > (bid_start_min + maxBiddingTime)) or (current_date.h > bid_start_h and maxBiddingTime>(60-bid_start_min)){
		for person in personBidders each.bidClear <-True;
		for package in packageBidders each.bidClear <- True;}
	}
				
	/* ========================================== STATE MACHINE ========================================= */
	state wandering initial: true {
		enter {
			if autonomousBikeEventLog {
				ask eventLogger { do logEnterState; }
				ask travelLogger { do logRoads(0.0);}
			}
			target <- nil;
		}
		transition to: picking_up_people when: rider != nil and activity = 1{}
		transition to: picking_up_packages when: delivery != nil and activity = 0{}
		transition to: low_battery when: setLowBattery() {}
		//transition to: night_recharging when: setNightChargingTime() {nightorigin <- self.location;}
		exit {
			if autonomousBikeEventLog {ask eventLogger { do logExitState; }}
		}
	}
	
	state low_battery {
		enter{
			target <- (chargingStation closest_to(self)).location; 
			distanceTraveledBike <- target distance_to location;
			if autonomousBikeEventLog {
				ask eventLogger { do logEnterState(myself.state); }
				ask travelLogger { do logRoads(myself.distanceTraveledBike);}
			}
		}
		transition to: getting_charge when: self.location = target {}
		exit {
			if autonomousBikeEventLog {ask eventLogger { do logExitState; }}
		}
	}
	/*state night_recharging {
		enter{
			target <- (chargingStation closest_to(self)).location; 
			autonomousBike_distance_C <- target distance_to location;
			if autonomousBikeEventLog {
				ask eventLogger { do logEnterState(myself.state); }
				ask travelLogger { do logRoads(autonomousBike_distance_C);}
			}
		}
		transition to: getting_night_charge when: self.location = target {}
		exit {
			if autonomousBikeEventLog {ask eventLogger { do logExitState; }}
		}
	}*/
	
	state getting_charge {
		enter {
			if stationChargeLogs{
				ask eventLogger { do logEnterState("Charging at " + (chargingStation closest_to myself)); }
				ask travelLogger { do logRoads(0.0);}
			}		
			target <- nil;
			ask chargingStation closest_to(self) {
				autonomousBikesToCharge <- autonomousBikesToCharge + myself;
			}
		}
		transition to: wandering when: batteryLife >= maxBatteryLifeAutonomousBike {}
		exit {
			if stationChargeLogs{ask eventLogger { do logExitState("Charged at " + (chargingStation closest_to myself)); }}
			ask chargingStation closest_to(self) {
				autonomousBikesToCharge <- autonomousBikesToCharge - myself;
			}
		}
	}
	
	/*state getting_night_charge { //TODO: Think if we want to reactivate this
		enter {
			if stationChargeLogs{
				ask eventLogger { do logEnterState("Charging at " + (chargingStation closest_to myself)); }
				ask travelLogger { do logRoads(0.0);}
			}		
			target <- nil;
			ask chargingStation closest_to(self) {
				autonomousBikesToCharge <- autonomousBikesToCharge + myself;
			}
		}
		transition to: night_relocating when: batteryLife >= maxBatteryLifeAutonomousBike {}
		exit {
			if stationChargeLogs{ask eventLogger { do logExitState("Charged at " + (chargingStation closest_to myself)); }}
			ask chargingStation closest_to(self) {
				autonomousBikesToCharge <- autonomousBikesToCharge - myself;
			}
		}
	}*/
	
	/*state night_relocating {
		enter{
			target <- nightorigin;
			autonomousBike_distance_C <- target distance_to location;
			if autonomousBikeEventLog {
				ask eventLogger { do logEnterState(myself.state); }
				ask travelLogger { do logRoads(autonomousBike_distance_C);}
			}
		}
		transition to: wandering when: self.location = target {}
		exit {
			if autonomousBikeEventLog {ask eventLogger { do logExitState; }}
		}
	}*/
			
	state picking_up_people {
			enter {
				target <- rider.target;
				distanceTraveledBike <- target distance_to location;
				if autonomousBikeEventLog {
					ask eventLogger { do logEnterState("Picking up " + myself.rider); }
					ask travelLogger { do logRoads(myself.distanceTraveledBike);}
				}
			}
			transition to: in_use_people when: (location=target and rider.location=target) {}
			exit{
				if autonomousBikeEventLog {ask eventLogger { do logExitState("Picked up " + myself.rider); }}
			}
	}	
	
	state picking_up_packages {
			enter {
				target <- delivery.target; 
				distanceTraveledBike <- target distance_to location;
				if autonomousBikeEventLog {
					ask eventLogger { do logEnterState("Picking up " + myself.delivery); }
					ask travelLogger { do logRoads(myself.distanceTraveledBike);}
				}
			}
			transition to: in_use_packages when: (location=target and delivery.location=target) {}
			exit{
				if autonomousBikeEventLog {ask eventLogger { do logExitState("Picked up " + myself.delivery); }}
			}
	}
	
	state in_use_people {
		enter {
			target <- (road closest_to rider.final_destination).location;
			distanceTraveledBike <- target distance_to location;
			if autonomousBikeEventLog {
				ask eventLogger { do logEnterState("In Use " + myself.rider); }
				ask travelLogger { do logRoads(myself.distanceTraveledBike);}
			}
		}
		transition to: wandering when: location=target {
			rider <- nil;
		}
		exit {
			if autonomousBikeEventLog {ask eventLogger { do logExitState("Used" + myself.rider); }}
		}
	}
	
	state in_use_packages {
		enter {
			target <- (road closest_to delivery.final_destination).location;  
			distanceTraveledBike <- target distance_to location;
			if autonomousBikeEventLog {
				ask eventLogger { do logEnterState("In Use " + myself.delivery); }
				ask travelLogger { do logRoads(myself.distanceTraveledBike);}
			}
		}
		transition to: wandering when: location=target {
			delivery <- nil;
		}
		exit {
			if autonomousBikeEventLog {ask eventLogger { do logExitState("Used" + myself.delivery); }}
		}
	}
}