model main 

import "./Agents.gaml" 
import "./Loggers.gaml"
import "./Parameters.gaml"

global {
	//---------------------------------------------------------Performance Measures-----------------------------------------------------------------------------
	//------------------------------------------------------------------Necessary Variables--------------------------------------------------------------------------------------------------

	// GIS FILES
	geometry shape <- envelope(bound_shapefile);
	graph roadNetwork;
	list<int> chargingStationLocation;
	
	// For genetic optimization
	int trips_w_good_service <-0;
	
    // ---------------------------------------Agent Creation----------------------------------------------
	init{
    	// ---------------------------------------Buildings-----------------------------i----------------
		do logSetUp;
	    create building from: buildings_shapefile with: [type:string(read (usage))] {
		 	if(type!=office and type!=residence and type!=park and type!=education){ type <- "Other"; }
		}
	    
		// ---------------------------------------The Road Network----------------------------------------------
		create road from: roads_shapefile;
		
		roadNetwork <- as_edge_graph(road) ;
				
		create restaurant from: restaurants_csv with:
			[lat::float(get("latitude")),
			lon::float(get("longitude"))
			]
			{location <- to_GAMA_CRS({lon,lat},"EPSG:4326").location;}
					   
		// -------------------------------------Location of the charging stations----------------------------------------   
		
				// -------------------------------------Location of the charging stations----------------------------------------   
		//-----------------------------------------------Before----------------------------------------------------------
		
		list<int> tmpDist;
	    		
		loop vertex over: roadNetwork.vertices {
			create intersection {
				id <- roadNetwork.vertices index_of vertex;
				location <- point(vertex);
			}
		}

		//K-Means		
		//Create a list of x,y coordinate for each intersection
		list<list> instances <- intersection collect ([each.location.x, each.location.y]);

		//from the vertices list, create k groups  with the Kmeans algorithm (https://en.wikipedia.org/wiki/K-means_clustering)
		list<list<int>> kmeansClusters <- list<list<int>>(kmeans(instances, numChargingStations));

		//from clustered vertices to centroids locations
		int groupIndex <- 0;
		list<point> coordinatesCentroids <- [];
		loop cluster over: kmeansClusters {
			groupIndex <- groupIndex + 1;
			list<point> coordinatesVertices <- [];
			loop i over: cluster {
				add point (roadNetwork.vertices[i]) to: coordinatesVertices; 
			}
			add mean(coordinatesVertices) to: coordinatesCentroids;
		}    
	    
		loop centroid from:0 to:length(coordinatesCentroids)-1 {
			tmpDist <- [];
			loop vertices from:0 to:length(roadNetwork.vertices)-1{
				add (point(roadNetwork.vertices[vertices]) distance_to coordinatesCentroids[centroid]) to: tmpDist;
			}	
			loop vertices from:0 to: length(tmpDist)-1{
				if(min(tmpDist)=tmpDist[vertices]){
					add vertices to: chargingStationLocation;
					break;
				}
			}	
		}
	    
	    loop i from: 0 to: length(chargingStationLocation) - 1 {
			create chargingStation{
				location <- point(roadNetwork.vertices[chargingStationLocation[i]]);
				capacity <- chargingStationCapacity;
			}
		}
		//--------------------------------------Another option--------------------------------------------------
		
		/*create chargingStation from: chargingStations_csv with:
			[lat::float(get("Latitude")),
			lon::float(get("Longitude")),
			capacity::int(get("Total docks"))
			]
			{
				location <- to_GAMA_CRS({lon,lat},"EPSG:4326").location;
			 	//chargingStationCapacity <- capacity;
			}*/
			
		// -------------------------------------------The Bikes -----------------------------------------
		create autonomousBike number:numAutonomousBikes{					
			location <- point(one_of(roadNetwork.vertices));
			batteryLife <- rnd(minSafeBatteryAutonomousBike,maxBatteryLifeAutonomousBike); 	//Battery life random bewteen max and min
		}
	    	    
		// -------------------------------------------The Packages -----------------------------------------
		if packagesEnabled{create package from: pdemand_csv with:
		[start_hour::date(get("start_time")),
				start_lat::float(get("start_latitude")),
				start_lon::float(get("start_longitude")),
				target_lat::float(get("end_latitude")),
				target_lon::float(get("end_longitude"))	
		]{
			
			start_point  <- to_GAMA_CRS({start_lon,start_lat},"EPSG:4326").location;
			target_point  <- to_GAMA_CRS({target_lon,target_lat},"EPSG:4326").location;
			location <- start_point;
			
			string start_h_str <- string(start_hour,'kk');
			start_h <-  int(start_h_str);
			if start_h = 24 {
				start_h <- 0;
			}
			string start_min_str <- string(start_hour,'mm');
			start_min <- int(start_min_str);
		}}
		
		// -------------------------------------------The People -----------------------------------------
	    if peopleEnabled{create people from: demand_csv with:
		[start_hour::date(get("starttime")), //'yyyy-MM-dd hh:mm:s'
				start_lat::float(get("start_lat")),
				start_lon::float(get("start_lon")),
				target_lat::float(get("target_lat")),
				target_lon::float(get("target_lon"))
			]{

	        speed <- peopleSpeed;
	        start_point  <- to_GAMA_CRS({start_lon,start_lat},"EPSG:4326").location; // (lon, lat) var0 equals a geometry corresponding to the agent geometry transformed into the GAMA CRS
			target_point <- to_GAMA_CRS({target_lon,target_lat},"EPSG:4326").location;
			location <- start_point;
			
			string start_h_str <- string(start_hour,'kk');
			start_h <- int(start_h_str);
			string start_min_str <- string(start_hour,'mm');
			start_min <- int(start_min_str);
			
			//write "Start "+start_point+ " " +start_h+ ":"+ start_min;
			
			}}
						
			write "FINISH INITIALIZATION";
    }
    
	reflex stop_simulation when: cycle >= numberOfDays * numberOfHours * 3600 / step {
		do pause ;
	}
}

experiment multifunctionalVehiclesVisual type: gui {
	parameter var: numAutonomousBikes init: numAutonomousBikes;
	//float minimum_cycle_duration<-0.01;
	parameter var: peopleEnabled init:true;
	parameter var: packagesEnabled init:true;
	parameter var: biddingEnabled init: true;
    output {
		display multifunctionalVehiclesVisual type:opengl background: #black axes: false{	 
			species building aspect: type visible:show_building position:{0,0,-0.001};
			species road aspect: base visible:show_road ;
			species people aspect: base visible:show_people;
			species chargingStation aspect: base visible:show_chargingStation ;
			species restaurant aspect:base visible:show_restaurant position:{0,0,-0.001};
			species autonomousBike aspect: realistic visible:show_autonomousBike trace:30 fading: true;
			species package aspect:base visible:show_package;

			event "b" {show_building<-!show_building;}
			event "r" {show_road<-!show_road;}
			event "p" {show_people<-!show_people;}
			event "s" {show_chargingStation<-!show_chargingStation;}
			event "f" {show_restaurant<-!show_restaurant;}
			event "d" {show_package<-!show_package;}
			event "a" {show_autonomousBike<-!show_autonomousBike;}
		}
    }
}

experiment batch_test_people type: batch repeat: 1 until: (cycle >= numberOfDays * numberOfHours * 3600 / step) {
	parameter var: numAutonomousBikes among:[100,150,200,250,300];
	//parameter var: numAutonomousBikes init:300;
	parameter var: peopleEnabled init:true;
	parameter var: packagesEnabled init:false;
	parameter var: biddingEnabled init: false;
	//TODO: review num Stations and charging speed
	//TODO: review maxDistance
}

experiment batch_test_packages type: batch repeat: 1 until: (cycle >= numberOfDays * numberOfHours * 3600 / step) {
	parameter var: numAutonomousBikes among:[100,150,200,250,300];
	parameter var: peopleEnabled init:false;
	parameter var: packagesEnabled init:true;
	parameter var: biddingEnabled init: false;
	//TODO: review num Stations and charging speed
	//TODO: review maxDistance
}

experiment batch_people_packages_nobid type: batch repeat: 1 until: (cycle >= numberOfDays * numberOfHours * 3600 / step) {
	parameter var: numAutonomousBikes among:[200,300,400,500,600];
	parameter var: peopleEnabled init:true;
	parameter var: packagesEnabled init:true;
	parameter var: biddingEnabled init: false;
	//TODO: review num Stations and charging speed
	//TODO: review maxDistance
}

experiment batch_people_packages_bidding type: batch repeat: 1 until: (cycle >= numberOfDays * numberOfHours * 3600 / step) {
	
	parameter var: numAutonomousBikes among:[200,300,400,500,600];
	//parameter var: numAutonomousBikes among: [400,500,600];
	parameter var: peopleEnabled init:true;
	parameter var: packagesEnabled init:true;
	parameter var: biddingEnabled init: true;
	
	//TODO: review num Stations and charging speed
	//TODO: review maxDistance
	
	//TODO: review this params
	parameter var: maxBiddingTime init: 1;
	parameter var: pack_bid_ct init: 1.00;
	parameter var: pack_bid_dist_coef init: 1/200;
	parameter var: pack_bid_queue_coef init: 2.0;
	parameter var: person_bid_ct init: 4.00;
	parameter var: person_bid_dist_coef init: 1/200;
	parameter var: person_bid_queue_coef init: 2.0;

}

experiment bidding_genetic type: batch repeat: 1 until: (cycle >= numberOfDays * numberOfHours * 3600 / step) {

	parameter var: peopleEnabled init:true;
	parameter var: packagesEnabled init:true;
	parameter var: biddingEnabled init: true;
	
	parameter var: numAutonomousBikes init:300;
	//parameter var: maxWaitTimePeople init: 7 #mn; //Intsead of 30 ?
	//parameter var: maxWaitTimePackages init: 14 #mn; //Intsead of 50 ?

	parameter var: maxBiddingTime among: [1,2]; //TODO: make sure we are adding this time to wait time
	parameter var: pack_bid_ct among: [1.0,2.0,3.0,4.0];
	parameter var: pack_bid_dist_coef among: [1/50,1/100, 1/150];
	parameter var: pack_bid_queue_coef among: [1.0,2.0,3.0];
	parameter var: person_bid_ct among:   [1.0,2.0,3.0,4.0];
	parameter var: person_bid_dist_coef among: [1/50,1/100, 1/150]; //TODO: Maybe dist and queue are the same for bike and package?
	parameter var: person_bid_queue_coef among: [1.0,2.0,3.0];
	
	method genetic 
    pop_dim: 5 crossover_prob: 0.7 mutation_prob: 0.1 
    nb_prelim_gen: 1 max_gen: 20  maximize: trips_w_good_service;
	
	reflex save_results {
		ask simulations {
			//save [numBikes,evaporation,exploitationRate ,WanderingSpeed,avg_wait ] type: csv to:"./../data/results_genetic_1500_3.csv" rewrite: (int(self) = 0) ? true : false header: true ;
		    save [maxBiddingTime,pack_bid_ct,pack_bid_dist_coef,pack_bid_queue_coef,person_bid_ct, person_bid_dist_coef,person_bid_queue_coef] type: csv to:"./../results/results_genetic_bidding.csv" rewrite: (int(self) = 0) ? true : false header: true ;
		}
	}

}

experiment bidding_params type: batch repeat: 1 until: (cycle >= numberOfDays * numberOfHours * 3600 / step) {

	parameter var: peopleEnabled init:true;
	parameter var: packagesEnabled init:true;
	parameter var: biddingEnabled init: true;
	
	parameter var: numAutonomousBikes init:300;
	//parameter var: maxWaitTimePeople init: 7 #mn; //Intsead of 30 ?
	//parameter var: maxWaitTimePackages init: 14 #mn; //Intsead of 50 ?

	parameter var: maxBiddingTime init: 1; //TODO: make sure we are adding this time to wait time
	parameter var: pack_bid_ct among: [0.5,2.0,4.0];
	parameter var: pack_bid_dist_coef among: [1/50,1/100,1/150];
	parameter var: pack_bid_queue_coef among: [1.0,2.0,3.0];
	parameter var: person_bid_ct among: [0.5,2.0,4.0];
	parameter var: person_bid_dist_coef among: [1/50,1/100, 1/150]; //TODO: Maybe dist and queue are the same for bike and package?
	parameter var: person_bid_queue_coef among: [1.0,2.0,3.0];

}

/*experiment bidding_genetic type: batch repeat: 1 until: (cycle >= numberOfDays * numberOfHours * 3600 / step) {
	
	parameter var: peopleEnabled init:true;
	parameter var: packagesEnabled init:true;
	parameter var: biddingEnabled init: true;
	
	//TODO: review this params
	parameter var: maxWaitTimePeople init: 10; //Intsead of 30 ?
	parameter var: maxWaitTimePackages init: 20; //Intsead of 50 ?
	parameter var: maxBiddingTime among: [1,2,3]; //TODO: make sure we are adding this time to wait time
	parameter var: pack_bid_ct among: [100.00,200.00,300.00];
	parameter var: pack_bid_dist_coef among: [1/100, 1/200,1/300];
	parameter var: pack_bid_queue_coef init: [1.5,2.5,3.5];
	parameter var: person_bid_ct among: [200.00,300.00,400.00];
	parameter var: person_bid_dist_coef init: [1/100, 1/200,1/300]; //TODO: Maybe dist and queue are the same for bike and package?
	parameter var: person_bid_queue_coef init: [1.5,2.5,3.5];
	
	
	method genetic 
        pop_dim: 5 crossover_prob: 0.7 mutation_prob: 0.1 
        nb_prelim_gen: 1 max_gen: 20  maximize: trips_w_good_service;//TODO: Define param
	
	reflex save_results {
		ask simulations {
			//save [numBikes,evaporation,exploitationRate ,WanderingSpeed,avg_wait ] type: csv to:"./../data/results_genetic_1500_3.csv" rewrite: (int(self) = 0) ? true : false header: true ;
		    save [maxBiddingTime,pack_bid_ct,pack_bid_dist_coef,pack_bid_queue_coef,person_bid_ct, person_bid_dist_coef,person_bid_queue_coef] type: csv to:"./../results/results_genetic_bidding.csv" rewrite: (int(self) = 0) ? true : false header: true ;
		}
	}
}*/