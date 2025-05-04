cube([40,15,2]);

translate([0,2,0])
rotate([90,0,0])
cube([40,20,2]);

difference() {
    translate([(40-2)/2, 0,0])
rotate([0,0,90])
rotate([90,0,0])
cube([15,20,2]);
    
translate([0,15,0])
rotate([35,0,0])
cube([40,30,80]);


}