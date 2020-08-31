// =================================================================
// A modular hexagonal rack, good for storing cylinders such as
// spice jars!
// =================================================================
// Copyright Jody Sankey 2019.
//
// This work is licensed under the Creative Commons Attribution 4.0
// International License. To view a copy of this license, visit 
// http://creativecommons.org/licenses/by/4.0/ or send a letter to
// Creative Commons, PO Box 1866, Mountain View, CA 94042, USA.
// =================================================================


// CONTROL VARIABLES
// =================

// Width across flats of each hole.
hole_af = 52;
// Maximum depth of each hole.
max_depth = 85;
// The angle of each hole away from horizontal
angle = 10;
// Thickness of the wall between holes.
wall = 3;
// Length of each side on interlocking tabs as a fraction of wall thickness.
tab_fraction = 0.3;
// Gap between large mating faces at the interlocking tabs.
tab_margin = 0.08;
// Small offset to ensure differences are resolved correctly.
nudge = 0.01;

// Use the "output" section at the bottom of the file to control the
// number of rows and columns, and which sides have interlocking tabs.





// CALCULATED VARIABLES
// ====================

// Width across corners of each hole.
hole_ac = hole_af/sin(60);
// Width across flats of the block each hole is cut from.
block_af = hole_af + 2*wall;
// Width across corners of the block each hole is cut from.
block_ac = block_af/sin(60);

// Spacing between horizontal centers
horizontal_spacing = hole_af+wall+nudge;
// Spacing between vertical centers
not_yet_projected_spacing = ((hole_af+wall)/sin(60) * 3/4) + nudge;
vertical_spacing = not_yet_projected_spacing /cos(angle);



// HELPER MODULES
// ==============

// Returns a hexagonal prism with a centreline on y/z and a body increasing in x
module hex_prism(length, width_af) {
  rotate([0,90,0])
    linear_extrude(height=length)
    circle(r=(width_af/2/sin(60)), $fn=6);
}

// Returns a locking tab with the key face on x/z, centered on z.
//   length(float) - Length of the part in z.
//   side (float) - Length of each triangle side. 
//   y_positive (boolean) - If true, the body of the triangle is on the +y side. 
module tri_prism(length, side, y_positive) {
  translate([0, y_positive ? tan(30)*side/2 : -tan(30)*side/2])
  rotate([0,90,0])
    rotate([0, 0, y_positive ? -30 : 30])
    linear_extrude(height=length)
    circle(r=side/2/cos(30), $fn=2);
}

// Returns a locking tab with the key face on x/z, centered on z.
module trapezoid(length, side) {
  rotate([0,90,0])
    linear_extrude(height=length)
     polygon(points=[[side/2+wall*tan(30),0],
                     [side/2+wall/2*tan(30), wall/2],  
                     [-side/2-wall/2*tan(30), wall/2],  
                     [-side/2-wall*tan(30), 0]]);  
}

// Pivots child(0) around y by the specified angle, centered at height z.
module rotate_with_offset(angle, z_position) {
  translate([0,0,z_position/cos(angle)])
  rotate([0,-angle,0])
  translate([0,0,-z_position])
  children([0]);
}

// Removes any part of child(0) that is past the y-z plane.
module remove_negative_x(max_dimension) {
  difference() {
    children([0]);
    translate([-max_dimension/2, 0, 0])
      cube(size=max_dimension, center=true);
  }
}

// Removes any part of child(0) that is past the y-z plane.
module remove_negative_z(max_dimension) {
  difference() {
    children([0]);
    translate([0,0, -max_dimension/2])
      cube(size=max_dimension, center=true);
  }
}


// BLOCK CONSTRUCTION
// ==================

// Returns a single cell, centered on y=0,z=0
//   hole (boolean) - If true, remove the interior of the cell.
module cell(hole) {
  rotate_with_offset(angle, block_ac/2) {
    difference() {
      translate([-block_ac,0,0])
      hex_prism(length=max_depth+wall+block_ac,width_af=block_af);
      if(hole == true) {
        translate([wall,0,0])
        hex_prism(length=max_depth+wall+block_ac,width_af=hole_af);
      }
    }
  }
}

// Returns a modified cell that can be subtracted from the spaces
// adjacent to the cells on the edge of block to form an interlocking
// edge, centered on y=0,z=0.
module edge_cutter() {
  raw_length = max_depth+2*block_ac;
  // Note we add half the desired margin to the hex prism, the other half will
  // be removed by the edge cutter on the mating face.
  cutter_af = block_af-wall+tab_margin;
  cutter_ac = cutter_af/sin(60);
  cutter_side = cutter_ac/2;
  tab_side = wall*tab_fraction;
  overcut_tab_side = tab_side + tab_margin*tan(30);
  undercut_tab_side = tab_side - tab_margin*tan(30);
  triangle_side = wall;
  
  // Generates a larger triangular prism suitable for adding to the cutter to
  // cut a groove in the part. The triangle is pointing right iff
  // point_right==true, with the opposite key face aligned on y=0. If z_positive
  // is true, the top corner is at z=overcut_tab_side, else the bottom corner is at
  // z=-overcut_tab_side.
  module groove(point_right, z_positive) {
    side = overcut_tab_side;
    translate([0,0,(z_positive ? 1 : -1)*(side/2-nudge)])
      tri_prism(length=raw_length, side=side+2*nudge, y_positive=point_right);    
  }
  
  // Generates a smaller triangular prism suitable for subtracting from the cutter
  // to cut a tooth in the part. The triangle is pointing right iff
  // point_right==true, with the opposite key face aligned on y=0. If z_positive
  // is true, the top corner is at z=z_distance, else the bottom corner is at
  // z=-overcut_tab_side.
  module tooth(point_right, z_positive) {
    side = undercut_tab_side;
    translate([-nudge,0,(z_positive ? 1 : -1)*(side/2-nudge)])
      tri_prism(length=raw_length+2*nudge, side=side+2*nudge, y_positive=point_right);    
  }

  // Translates the child elements along a diagonal face of the hex prism.
  // z_positive and y_positive specify the face, y_distance the distance
  // from the centerline.
  module translate_along_face(y_positive, z_positive, y_distance) {
    translate([
       0,
       (y_positive ? 1 : -1)*y_distance,
       (z_positive ? 1 : -1)*(cutter_ac/2-y_distance*tan(30))])
      children();
  }

  rotate_with_offset(angle, block_ac/2) {
    translate([-block_ac+nudge,0,0])
    difference() {
      union() {
        hex_prism(length=raw_length,width_af=cutter_af);
        for (z_positive=[false,true], y_positive=[false,true]) {
          // Add cutting material to form outboard grooves.
          translate_along_face(y_positive, z_positive, cutter_af/2)
            groove(point_right=!y_positive, z_positive=z_positive);
          // Add cutting material to form inboard grooves.
          translate_along_face(y_positive, z_positive, tab_margin/2+tab_side*2*sin(60))
            groove(point_right=!y_positive, z_positive=z_positive);
        }
      }
      for (z_positive=[false,true], y_positive=[false,true]) {
        // Remove cutting material to form inboard teeth.
        translate_along_face(y_positive, z_positive, tab_margin/2)
          tooth(point_right=y_positive, z_positive=!z_positive);
        // Remove cutting material to form outboard teeth.
        translate_along_face(y_positive, z_positive, cutter_af/2-2*tab_side*sin(60))
          tooth(point_right=y_positive, z_positive=!z_positive);

      }          
    }
  }
}

// Returns the matrix of all cells.
module block(rows, columns, left_tabs, right_tabs) {
  rotate([0,-90,0])
  remove_negative_x(max_dimension=2*(columns+rows)*horizontal_spacing) {
    remove_negative_z(max_dimension=2*columns*(max_depth*horizontal_spacing)) {
      difference() {
        union() {
          // Matrix of the full cells plus partials.
          for (c=[0:columns-1]) {
            // A bottom row of spacers, most of which will be sliced off.
            translate([0,(c-0.5)*horizontal_spacing,block_ac/2-vertical_spacing])
              cell(hole=false);      
            // The normal matrix.
            for (r=[0:rows-1]) {
              translate([0,(c-(r%2)/2)*horizontal_spacing,r*vertical_spacing+block_ac/2])
                cell(hole=true);
            }
          }
          // Additional cells to the sides with tabs to create mating diagonal walls.
          if (left_tabs) {
            for (r=[0:2:rows-1]) {
              translate([0,-horizontal_spacing,r*vertical_spacing+block_ac/2])
                cell(hole=false);
            }
          }
          if (right_tabs) {
            for (r=[-1:2:rows-1]) {
              translate([0,(2*columns-1)/2*horizontal_spacing,r*vertical_spacing+block_ac/2])
                cell(hole=false);
            }
          }
        }
        // Add the interlocking pattern on each side if requested.
        if (left_tabs) {
          for (r=[0:2:rows-1]) {
            // Cut from all the right-offset rows.
            translate([0,-horizontal_spacing,r*vertical_spacing+block_ac/2])
              edge_cutter();
          }
          if (rows%2 == 1) {
            // Remove the weak strip this would leave on the top row.
            translate([0,-horizontal_spacing,(rows-1)*vertical_spacing+block_ac/2+wall])
              edge_cutter();
          }
          // Remove all material beyond the wall centerline on the left-most rows.
          translate([-nudge,-(2*horizontal_spacing-tab_margin/2),-nudge])
            cube([2*max_depth, horizontal_spacing, rows*horizontal_spacing]);
        }
        if (right_tabs) {
          for (r=[-1:2:rows-1]) {
            // Cut from all the left-offset rows.
            translate([0,(2*columns-1)*horizontal_spacing/2,r*vertical_spacing+block_ac/2])
              edge_cutter();
          }
          if (rows%2 == 0) {
            // Remove the weak strip this would leave on the top row.
            translate([0,(2*columns-1)*horizontal_spacing/2,(rows-1)*vertical_spacing+block_ac/2+wall])
              edge_cutter();
          }
          // Remove all material beyond the wall centerline on the left-most rows.
          translate([-nudge,(0.5+columns-1)*horizontal_spacing-tab_margin/2,-nudge])
            cube([2*max_depth, horizontal_spacing, rows*horizontal_spacing]);
        }
      }
    }
  }
}



// FINAL OUTPUT
// ============

// Comment or uncomment the examples below, or create new ones.


// The next three lines are left, middle, and right segments that interlock.
// 4 rows / 3 columns is the max size for a Prusa mk3 printer.
// -------------------------------------------------------------------------

//block(rows=4, columns=3, left_tabs=false, right_tabs=true);
block(rows=4, columns=2, left_tabs=true, right_tabs=true);
//block(rows=4, columns=3, left_tabs=true, right_tabs=false);


// The next line is a standalone 3x4 block that doesn't interlock.
// 4 rows / 3 columns is the max size for a Prusa mk3 printer.
// -------------------------------------------------------------------------

//block(rows=4, columns=3, left_tabs=false, right_tabs=false);


