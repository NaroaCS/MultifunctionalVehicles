model main

import "./Agents.gaml"


global {	


	// Simulation Step
	float step <- 5 #sec; 
	
	// Import GIS files
	string cityScopeCity <- "Cambridge";
	string cityGISFolder <- "./../includes/City/"+cityScopeCity;
	file bound_shapefile <- file(cityGISFolder + "/Bounds.shp");
	file roads_shapefile <- file(cityGISFolder + "/Roads.shp");
	
	geometry shape <- envelope(bound_shapefile);
	graph roadNetwork;
	
    // ---------------------------------------Agent Creation----------------------------------------------
	init{
	    
		// ---------------------------------------The Road Network----------------------------------------------
		create road from: roads_shapefile;
		
		roadNetwork <- as_edge_graph(road) ;
				
			
		// -------------------------------------------The Bikes -----------------------------------------
		create autonomousBike number: 100 {					
			location <- point(one_of(roadNetwork.vertices));}
	    	    
		
		// -------------------------------------------The People -----------------------------------------
	    create people number: 10{					
			location <- point(one_of(roadNetwork.vertices));}
	    
    }
    
	reflex stop_simulation when: cycle >= 24 * 3600 / step {
		do pause ;
	}
}

experiment test type: gui {

	output {
		display city_display type:opengl {
			species road aspect: base ;
			species people aspect: base ;
			species autonomousBike aspect: base;
		}

	}
}


