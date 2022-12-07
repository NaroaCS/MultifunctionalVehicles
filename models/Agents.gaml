model Agents

import "./main.gaml"

global{
	
	
	bool requestBike_global(people person){
		autonomousBike b <- autonomousBike closest_to(person);
		float d_graph <- person distance_to b using topology(roadNetwork);
		float d_eucl <- person distance_to b;
		write 'Distance in graph (global): ' + d_graph;
		write 'Euclidean distance (global): '+ d_eucl;
		write '-----------------------------';
		
	return false;
	
	}
}


species road {	
		aspect base {
		draw shape color: #black ;
	}
}

species people control: fsm skills: [moving] {
	
	aspect base {
		draw circle(10) color: color border: #blue;
	}
	
	reflex requestBike when: current_date.hour = 1 {
		bool req <- host.requestBike_global(self);
		autonomousBike b <- autonomousBike closest_to(self);
		float d_graph <- self distance_to b using topology(roadNetwork);
		float d_eucl <- self distance_to b;
		write 'Distance in graph (reflex): ' + d_graph;
		write 'Euclidean distance (reflex): '+ d_eucl;
		write '-----------------------------';
		}
}


species autonomousBike control: fsm skills: [moving] {
	
	aspect base {
		draw triangle(10) color: color border: #red;
	}
}	