model Agents

import "./main.gaml"



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
		autonomousBike b <- autonomousBike closest_to(self);
		float d_graph <- self distance_to b using topology(roadNetwork);
		float d_eucl <- self distance_to b;
		write 'Distance in graph: ' + d_graph;
		write 'Euclidean distance: '+ d_eucl;
		write '-----------------------------';
		}
}


species autonomousBike control: fsm skills: [moving] {
	
	aspect base {
		draw triangle(10) color: color border: #red;
	}
}	