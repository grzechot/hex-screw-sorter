// Hex screw sorter - stackable cups and rings with loose flat sieve plates
//
// Stacking joint (wall cross-section, outside on the left):
//   - wall is split into an outer half (thickness a) and an inner half (from b to wall)
//   - top: outer half rises as a socket with a square (90°) top edge; inner half ends lower as a ledge
//   - bottom: inner half extends down as a spigot that rests on the ledge below; the outer
//     face runs into the spigot through a chamfer (chamfer_angle from horizontal), lifted
//     clear of the socket edge below by seam_gap, so it never prints in the air
//   - a ring has an inner lip at the bottom of its spigot; a flat sieve plate dropped
//     into the ring rests on that lip, so ring + plate lift off together as one sieve
//     and sit on top of a cup or another ring
// Outer faces are flush, the stack pitch is exactly the module height, and every
// part prints without supports (sieve plates print flat).
//
// CLI example:
//   openscad -o sieve_4.3.stl -D 'part="sieve"' -D sieve_d=4.3 hex_sorter.scad

/* [Part selection] */
// What to render
part = "stack"; // [stack, lineup, section, sieve, cup, ring, lid, funnel]
// Gap between modules in "stack" view (0 = assembled)
explode = 25;

/* [Single part parameters] */
// Sieve hole size across flats [mm]
sieve_d = 4.3;
// Height in units U (cup, ring, funnel)
height_u = 2;
// Height in mm, overrides height_u when > 0
height_mm = 0;
// Cup dividers: 0, 2, 3 or 6 compartments
dividers = 0;
// Engrave hole size / height
label = true;
// Cut sieve holes (false = plain plate, fast preview)
holes = true;
// Text on the ring front, e.g. its sieve size "6.0" (empty = height in mm; height then moves to the back when set)
ring_label = "";

/* [Footprint] */
// Hex size across flats [mm]
hex_af = 100;
// Height unit U [mm]
unit = 15;
// Wall thickness [mm] (split in two halves for the joint)
wall = 2.4;
// Cup floor thickness [mm]
floor_t = 1.6;
// Lid plate thickness [mm]
lid_t = 2.4;

/* [Stacking joint] */
// Socket depth, measured from the top outer edge to the ledge [mm]
socket_h = 5;
// Radial clearance between socket and spigot [mm]
clearance = 0.3;
// Vertical gap between spigot end and the ledge below [mm] (0 = the spigot carries the load)
spigot_gap = 0;
// Bottom chamfer from the spigot to the outer face, measured from horizontal [deg]
chamfer_angle = 60;
// Vertical gap between the bottom chamfer and the socket edge of the module below [mm]
seam_gap = 0.3;

/* [Sieve plate] */
// Series used by "stack"
sieve_series = [8.0, 6.4, 5.3, 4.3, 3.3, 2.5];
// Plate thickness [mm]
plate_t = 2.0;
// Radial clearance of the plate inside the ring [mm]
plate_clr = 0.3;
// Ring bottom lip that carries the plate: width / thickness [mm]
lip_w = 2.0;
lip_t = 1.2;
// Web between hex holes [mm]
bridge = 1.2;
// Margin between holes and the wall inner face [mm]
hole_margin = 1.0;
// Added to hole size to compensate for printing shrinkage [mm]
hole_comp = 0.1;

/* [Funnel] */
// Funnel outlet diameter [mm]
funnel_d = 30;
// Funnel shell thickness (vertical) [mm]
funnel_t = 2;

/* [Label] */
label_size = 7;
// Stencil number cut through the sieve plate
plate_label_size = 10;
// Stencil bridges across the plate number: width [mm]
stencil_bridge = 0.8;
label_depth = 0.6;
label_font = "Liberation Sans:style=Bold";

/* [Hidden] */
eps = 0.01;
part_u = height_mm > 0 ? height_mm / unit : height_u;   // height of a single part in U
half_a = wall/2 - clearance/2;            // outer half: s in [0, half_a]
half_b = wall/2 + clearance/2;            // inner half: s in [half_b, wall]
spigot_h = socket_h - spigot_gap;         // spigot length below the joint plane
cham_z0 = half_a * tan(chamfer_angle) + seam_gap;   // outer face bottom, above the joint plane
cham_z1 = cham_z0 - half_b * tan(chamfer_angle);    // chamfer meets the spigot face

// ---------- helpers ----------
// s = inset from the outer face

function hex_r(af) = af / 2 / cos(30);

// One decimal place: 6 -> "6.0"
function fmt1(v) = let(t = round(v * 10)) str(floor(t / 10), ".", t % 10);

module hex2d(af) { circle(r = hex_r(af), $fn = 6); }

module hexp(s, z0, z1) {
    translate([0, 0, z0]) linear_extrude(z1 - z0) hex2d(hex_af - 2*s);
}

// Outer body with chamfered bottom running into the spigot, square socket on top
module body(h, socket = true) {
    difference() {
        hull() { hexp(0, cham_z0, h); hexp(half_b, cham_z1, h); }
        if (socket) hexp(half_a, h - socket_h, h + 1);
    }
    hexp(half_b, -spigot_h, cham_z1 + eps);
}

module shell(h) {
    difference() {
        body(h);
        hexp(wall, -spigot_h - 1, h + 1);
    }
}

module front_text(txt) {
    text(txt, size = label_size, font = label_font, halign = "center", valign = "center");
}

module front_label(txt, h) {
    translate([0, -hex_af/2 + label_depth, h/2])
        rotate([90, 0, 0]) linear_extrude(label_depth + 1) front_text(txt);
}

// txt on the front face, optional txt_back on the back face
module labelled(txt, h, txt_back = "") {
    if (label && txt != "")
        difference() {
            children();
            front_label(txt, h);
            if (txt_back != "") rotate(180) front_label(txt_back, h);
        }
    else
        children();
}

// ---------- sieve plate ----------

hole_apothem = hex_af/2 - wall - lip_w - hole_margin;  // holes stay inside the lip
label_band_y = -hole_apothem + plate_label_size + 2; // no holes below this line (label area)

module hole_pattern(d) {
    f  = d + hole_comp;                 // across flats
    p  = f + bridge;                    // lattice pitch = uniform web
    rv = f / 2 / cos(30);               // hole circumradius
    lim = hole_apothem - rv;
    n  = ceil(hex_af / p) + 1;
    for (j = [-n : n], i = [-n : n]) {
        x = i*p + (abs(j) % 2) * p/2;
        y = j*p*sin(60);
        if (abs(y) <= lim
            && abs( x*cos(30) + y*sin(30)) <= lim
            && abs(-x*cos(30) + y*sin(30)) <= lim
            && !(label && y - rv < label_band_y && abs(x) < 2.2*plate_label_size))
            translate([x, y]) rotate(30) circle(r = rv, $fn = 6);
    }
}

// Size cut through the plate, with horizontal bridges holding the islands of 0, 6, 8...
module stencil_number(txt) {
    sz = plate_label_size;
    difference() {
        text(txt, size = sz, font = label_font, halign = "center", valign = "center");
        for (f = [-0.18, 0.18])
            translate([-2*sz, f*sz - stencil_bridge/2]) square([4*sz, stencil_bridge]);
    }
}

module sieve(d = sieve_d) {
    linear_extrude(plate_t)
        difference() {
            hex2d(hex_af - 2*(wall + plate_clr));
            if (holes) hole_pattern(d);
            if (label)
                translate([0, (-hole_apothem + label_band_y) / 2]) stencil_number(fmt1(d));
        }
}

// ---------- modules ----------

module divider_walls(h, n) {
    if (n > 0) {
        z0  = -spigot_h + floor_t - eps;
        top = h - socket_h - 0.5;       // stays below the spigot of the module above
        k_n = (n == 2) ? 2 : n;
        intersection() {
            hexp(wall - eps, z0, top);
            union() for (k = [0 : k_n - 1])
                rotate(k * 360 / k_n)
                    translate([0, -wall/2, z0]) cube([hex_r(hex_af), wall, top - z0]);
        }
    }
}

module cup(hu = 2, n = 0) {
    h = hu * unit;
    labelled(str(h), h) union() {
        shell(h);
        hexp(half_b, -spigot_h, -spigot_h + floor_t);
        divider_walls(h, n);
    }
}

module plate_lip() {
    difference() {
        hexp(half_b, -spigot_h, -spigot_h + lip_t);
        hexp(wall + lip_w, -spigot_h - 1, 0);
    }
}

module ring(hu = 2) {
    h = hu * unit;
    labelled(ring_label != "" ? ring_label : str(h), h, ring_label != "" ? str(h) : "") union() {
        shell(h);
        plate_lip();
    }
}

module lid() {
    difference() {
        body(lid_t, socket = false);
        hexp(wall, -spigot_h - 1, 0);
    }
}

module funnel(hu = 2) {
    h = hu * unit;
    z1 = h - socket_h;
    module cone(z_off = 0)
        translate([0, 0, z_off]) hull() {
            cylinder(d = funnel_d, h = eps, $fn = 64);
            hexp(wall, z1, z1 + eps);
        }
    union() {
        shell(h);
        intersection() {
            hexp(wall - 0.5, -spigot_h, z1);
            difference() {
                hull() { cone(-funnel_t); cone(0); }
                cone(0);
                translate([0, 0, -spigot_h - 1]) cylinder(d = funnel_d, h = h, $fn = 64);
            }
        }
    }
}

// ---------- views ----------

module stack() {
    s = sieve_series;
    hb = unit;           // base cup 1U
    hr = 2 * unit;       // sieve rings 2U
    n = len(s);
    color("SteelBlue") cup(1);
    for (k = [0 : n]) {
        top = hb + k * hr;                                  // top of the module below
        z = top + (k + 1) * explode;
        if (k < n) {
            translate([0, 0, z]) color("Gold") ring(2);
            translate([0, 0, z - spigot_h + lip_t + explode / 2])   // plate lifted out of its ring
                color([0.95, 0.75 - 0.08*k, 0.2]) sieve(s[n - 1 - k]);
        } else
            translate([0, 0, z]) color("SeaGreen") funnel(2);
    }
}

module lineup() {
    sp = hex_af * 1.15;
    items = ["cup1", "cup2", "cup4", "cup1d6", "ring1", "ring2", "lid", "sieve"];
    for (i = [0 : len(items) - 1])
        translate([(i % 4) * sp, -floor(i / 4) * sp, 0]) {
            it = items[i];
            if (it == "cup1")   color("SteelBlue")  cup(1);
            if (it == "cup2")   color("SteelBlue")  cup(2);
            if (it == "cup4")   color("SteelBlue")  cup(4);
            if (it == "cup1d6") color("RoyalBlue")  cup(1, 6);
            if (it == "ring1")  color("Gold")       ring(1);
            if (it == "ring2")  color("Gold")       ring(2);
            if (it == "lid")    color("SlateGray")  lid();
            if (it == "sieve")  color("Orange")     sieve(sieve_d);
        }
}

// Assembled cup 1U + plate + ring 2U + lid, cut in half to check the joint
module section() {
    intersection() {
        union() {
            color("SteelBlue") cup(1);
            color("Orange") translate([0, 0, unit - spigot_h + lip_t]) sieve(sieve_d);
            color("Gold") translate([0, 0, unit]) ring(2);
            color("SlateGray") translate([0, 0, 3*unit]) lid();
        }
        translate([0, -hex_af, -50]) cube([hex_af, 2*hex_af, 200]);
    }
}

if (part == "stack")   stack();
if (part == "lineup")  lineup();
if (part == "section") section();
if (part == "sieve")   sieve(sieve_d);
// Single parts are lifted so the spigot stands on the bed at z = 0
translate([0, 0, spigot_h]) {
    if (part == "cup")     cup(part_u, dividers);
    if (part == "ring")    ring(part_u);
    if (part == "lid")     lid();
    if (part == "funnel")  funnel(part_u);
}
