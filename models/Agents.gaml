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
			autonomousBike b <- availableBikes closest_to(personIntersection); //Get closest bike
			float d<- distanceInGraph(personIntersection,b.location); //Get distance on roadNetwork
		
			if d >maxDistancePeople_AutonomousBike{
				return false;	 //If closest bike is too far, return false
			}else{
				float bidValuePerson <- (person_bid_ct -person_bid_dist_coef*d +person_bid_queue_coef*person.queueTime); 
				// Bid value ct is higher for people, its smaller for larger distances, and larger for larger queue times
				
				ask b { do receiveBid(person,nil,bidValuePerson);} //Send bid value to bike
				return true;
			}
		}else if pack !=nil{ // If package request
		
			point packIntersection <- roadNetwork.vertices closest_to(pack); //Cast position to road node
			autonomousBike b <- availableBikes closest_to(packIntersection); //Get closest bike
			float d<- distanceInGraph(packIntersection,b.location); //Get distance on roadNetwork
		
			if d >maxDistancePackage_AutonomousBike{
				return false;	 //If closest bike is too far, return false
			}else{
				float bidValuePackage <- (pack_bid_ct - pack_bid_dist_coef*d+ pack_bid_queue_coef*pack.queueTime); 
				// Bid value ct is lower for packages, its smaller for larger distances, and larger for larger queue times
				
				ask b { do receiveBid(nil,pack,bidValuePackage);} //Send bid value to bike
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
    int queueTime;
    int bidClear <- 0;
        
	aspect base {
    	color <- color_map[state];
    	draw square(15) color: color border: #black;
    }
    
	action deliver(autonomousBike ab){
		autonomousBikeToDeliver <- ab;
	}
	
	reflex updateQueueTime{
		
		if timeToTravel(){
			if (current_date.hour = start_h) {
				queueTime <- (current_date.minute - start_min);
			} else if (current_date.hour > start_h){
				queueTime <- (current_date.hour-start_h)*60 + (60 - start_min);	
			}
		}
		
	}
	
	bool timeToTravel { return ((current_date.hour = start_h and current_date.minute >= (start_min)) or (current_date.hour > start_h)) and !(self overlaps target_point); }

	
	state wandering initial: true {
    	
    	enter {
    		if (packageEventLog or packageTripLog) {ask logger { do logEnterState;}}
    		target <- nil;
    	}
    	transition to: bidding when: timeToTravel() {
    		final_destination <- target_point;
    	}
    	exit {
			if (packageEventLog) {ask logger { do logExitState; }}
		}
    }
    
    state bidding {
    	enter {
    		write string(self) + 'entering bidding';
    		if (packageEventLog or packageTripLog) {ask logger { do logEnterState; }} 
    		bidClear <-0;
    		target <- (road closest_to(self)).location;
   	
    	}
    	transition to: awaiting_bike_assignation when: host.bidForBike(nil,self){		
    	}
    	transition to: wandering when: !host.bidForBike(nil,self) {
			if peopleEventLog {ask logger { do logEvent( "Package not delivered" ); }}
			location <- final_destination;
		}
    	exit {
    		if packageEventLog {ask logger { do logExitState; }}
		}
		
	}
    state awaiting_bike_assignation{
		
		enter{
    		if (packageEventLog or packageTripLog){ask logger {do logEnterState;}}
    	}
	    transition to: firstmile when: host.bikeAssigned(nil,self){ 
	    	target <- (road closest_to(self)).location;
	    }
	    transition to: bidding when: bidClear = 1 {
	    	write string(self)+ 'lost bid, will bid again';
	    }
	    exit {
	    if packageEventLog {ask logger { do logExitState; }}
		}
   
   }

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
    int queueTime;
    int bidClear;
    
    int register <-0;
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
		
		if timeToTravel() {
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
    	transition to: bidding when: timeToTravel() {
       		final_destination <- target_point;
    	}
    	exit {
			if peopleEventLog {ask logger { do logExitState; }}
		}
    }
    
    state bidding {
		enter {
			write string(self) + 'entering bidding';
			if peopleEventLog or peopleTripLog {ask logger { do logEnterState; }} 
			bidClear <- 0;
			target <- (road closest_to(self)).location;
		}
		transition to: awaiting_bike_assignation when: host.bidForBike(self,nil) {
		}
		transition to: wandering when: !host.bidForBike(self,nil) {
			if peopleEventLog {ask logger { do logEvent( "Used another mode, wait too long" ); }}
			location <- final_destination;
		}
		exit {
			if peopleEventLog {ask logger { do logExitState; }}
		}
		
	}
    
	state awaiting_bike_assignation {
		enter {
			if peopleEventLog or peopleTripLog {ask logger { do logEnterState; }} 
		}
		transition to: firstmile when: host.bikeAssigned(self, nil) {
			target <- (road closest_to(self)).location;
		}
		transition to: bidding when: bidClear = 1 {
			write string(self)+ 'lost bid, will bid again';
			
		}
		exit {
			//if peopleEventLog {ask logger { do logExitState("Requested Bike " + myself.autonomousBikeToRide); }}
			if peopleEventLog { ask logger {do logExitState;}}
		}
		
	}

	
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
		"getting_charge":: #red,

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
	
	bool biddingStart <- false;
	float highestBid <- -100000.00;
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
		if (state="in_use_people"){return goto(on:roadNetwork, target:target, return_path: true, speed:RidingSpeedAutonomousBike);}
		return goto(on:roadNetwork, target:target, return_path: true, speed:DrivingSpeedAutonomousBike);
	}
	
	reflex move when: canMove() {
		
		travelledPath <- moveTowardTarget();
		
		float distanceTraveled <- host.distanceInGraph(travelledPath.source,travelledPath.target);
		
		do reduceBattery(distanceTraveled);
	}

	action receiveBid(people person, package pack, float bidValue){
		write 'Bike ' + string(self) +'received bid from:'+ person + '/'+ pack +' of value: '+ bidValue ;
		biddingStart <- true;
		if person != nil{
			add person to: personBidders;
		}else if pack != nil{
			add pack to: packageBidders;
		}
		if highestBid = -100000.00{ //First bid
			bid_start_h <- current_date.hour;
			bid_start_min <- current_date.minute;
		}
		if bidValue > highestBid { 
		//If the current bid value is larger than the previous max, we update it
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
	
	action endBidProcess{
			loop i over: personBidders{	
				i.bidClear <- 1;
			}
			loop j over: packageBidders{
				j.bidClear <- 1;
			}
			if highestBidderUser !=nil and highestBidderPackage = nil{ //If the highest bidder was a person
				do pickUp(highestBidderUser,nil);
				ask highestBidderUser {do ride(myself);}
				write 'Highest bidder for bike '+ string(self)+' person '+ highestBidderUser;
			}else if highestBidderPackage !=nil and highestBidderUser = nil {
				do pickUp(nil,highestBidderPackage);
				ask highestBidderPackage {do deliver(myself);}
				write 'Highest bidder for bike '+ string(self)+' package '+ highestBidderPackage;
			}else{
				write 'Error: Confusion with highest bidder';
			}
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
		transition to: bidding when: biddingStart= true{} // When it receives bid
		transition to: low_battery when: setLowBattery() {}
		exit {
			if autonomousBikeEventLog {ask eventLogger { do logExitState; }}
		}
	}
	
	state bidding {
		enter{
			if autonomousBikeEventLog {
				ask eventLogger { do logEnterState; }
				ask travelLogger { do logRoads(0.0);}
			}
			
		} //Wait for bidding time to end
		transition to: endBid when: (highestBid != -100000.00) and (current_date.hour = bid_start_h and current_date.minute > (bid_start_min + maxBiddingTime)) or (current_date.hour > bid_start_h and maxBiddingTime>(60-bid_start_min)){}
		exit {
			if autonomousBikeEventLog {ask eventLogger { do logExitState; }}
		}
	}
	state endBid {
		enter{	 
			if autonomousBikeEventLog {
				ask eventLogger { do logEnterState; }
				ask travelLogger { do logRoads(0.0);}
			}
			do endBidProcess(); //Assign winner and get the rest of packages and people out of the bid waiting
			
			//Clear all the variables for next round
			biddingStart <- false;
			highestBid <- -100000.00;
			highestBidderUser<- nil;
			highestBidderPackage <- nil;
			personBidders <- [];
			packageBidders <- [];
			bid_start_h <- nil;
			bid_start_min <- nil;
		}
		transition to: picking_up_people when: rider != nil and activity = 1{}
		transition to: picking_up_packages when: delivery != nil and activity = 0{}
		exit {
			if autonomousBikeEventLog {ask eventLogger { do logExitState; }}
		}
	}
	
	state low_battery {
		enter{
			target <- (chargingStation closest_to(self)).location; 
			
			point target_intersection <- roadNetwork.vertices closest_to(target);
			distanceTraveledBike <- host.distanceInGraph(target_intersection,location);
			
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
				autonomousBikesToCharge <- autonomousBikesToCharge - myself;}
		}
	}
			
	state picking_up_people {
			enter {
				target <- rider.target;
			
				point target_intersection <- roadNetwork.vertices closest_to(target);
				distanceTraveledBike <- host.distanceInGraph(target_intersection,location);
				
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
			
				point target_intersection <- roadNetwork.vertices closest_to(target);
				distanceTraveledBike <- host.distanceInGraph(target_intersection,location);
				
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
			
			point target_intersection <- roadNetwork.vertices closest_to(target);
			distanceTraveledBike <- host.distanceInGraph(target_intersection,location);

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
			
		point target_intersection <- roadNetwork.vertices closest_to(target);
		distanceTraveledBike <- host.distanceInGraph(target_intersection,location);
		
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


