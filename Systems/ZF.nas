##############################################################################
##
## ZF Navy free balloon
##
##  Copyright (C) 2006 - 2013  Anders Gidenstam  (anders(at)gidenstam.org)
##  This file is licensed under the GPL license v2 or later.
##
###############################################################################

var weight_on_gear =
    props.globals.getNode("/fdm/jsbsim/forces/fbz-gear-lbs");
var ballast   = "/fdm/jsbsim/inertia/pointmass-weight-lbs[0]";
var gas_valve = "/fdm/jsbsim/fcs/gas-valve-cmd-norm";
var rip_panel = "/fdm/jsbsim/fcs/rip-cmd-norm";
var ripped    = 0;

var print_wow = func {
    gui.popupTip("Current weight on gear " ~
                 weight_on_gear.getValue() ~ ".");
}

var weighoff = func {
    gui.popupTip("Weigh-off to 10% in progress. " ~
                 "Current weight " ~ weight_on_gear.getValue() ~ ".");
    var wow = weight_on_gear.getValue();
    var cont = getprop(ballast);
    interpolate(ballast,
                cont + 0.90 * wow,
                10);
}

# For experimental solar radiation heating.
var loopid = 0;
var loop = func (id) {
    if (id != loopid) return;
    setprop("/fdm/jsbsim/environment/sun-angle-rad",
            getprop("/sim/time/sun-angle-rad"));
    settimer(func { loop(id); }, 0.72);
}

setlistener("/sim/signal/fdm-initialized", func {
    loopid += 1;
    settimer(func { loop(loopid); }, 0.72);
});

# Disable the autopilot menu.
gui.menuEnable("autopilot", 0);

###############################################################################
# About dialog.

var ABOUT_DLG = 0;

var dialog = {
#################################################################
    init : func (x = nil, y = nil) {
        me.x = x;
        me.y = y;
        me.bg = [0, 0, 0, 0.3];    # background color
        me.fg = [[1.0, 1.0, 1.0, 1.0]]; 
        #
        # "private"
        me.title = "About";
        me.dialog = nil;
        me.namenode = props.Node.new({"dialog-name" : me.title });
    },
#################################################################
    create : func {
        if (me.dialog != nil)
            me.close();

        me.dialog = gui.Widget.new();
        me.dialog.set("name", me.title);
        if (me.x != nil)
            me.dialog.set("x", me.x);
        if (me.y != nil)
            me.dialog.set("y", me.y);

        me.dialog.set("layout", "vbox");
        me.dialog.set("default-padding", 0);

        var titlebar = me.dialog.addChild("group");
        titlebar.set("layout", "hbox");
        titlebar.addChild("empty").set("stretch", 1);
        titlebar.addChild("text").set
            ("label",
             "About");
        var w = titlebar.addChild("button");
        w.set("pref-width", 16);
        w.set("pref-height", 16);
        w.set("legend", "");
        w.set("default", 0);
        w.set("key", "esc");
        w.setBinding("nasal", "ZF.dialog.destroy(); ");
        w.setBinding("dialog-close");
        me.dialog.addChild("hrule");

        var content = me.dialog.addChild("group");
        content.set("layout", "vbox");
        content.set("halign", "center");
        content.set("default-padding", 5);
        props.globals.initNode("sim/about/text",
             "ZF Navy free balloon for FlightGear\n" ~
             "Copyright (C) 2006 - 2013  Anders Gidenstam\n\n" ~
             "FlightGear flight simulator\n" ~
             "Copyright (C) 1996 - 2013  http://www.flightgear.org\n\n" ~
             "This is free software, and you are welcome to\n" ~
             "redistribute it under certain conditions.\n" ~
             "See the GNU GENERAL PUBLIC LICENSE Version 2 for the details.",
             "STRING");
        var text = content.addChild("textbox");
        text.set("halign", "fill");
        #text.set("slider", 20);
        text.set("pref-width", 400);
        text.set("pref-height", 300);
        text.set("editable", 0);
        text.set("property", "sim/about/text");

        #me.dialog.addChild("hrule");

        fgcommand("dialog-new", me.dialog.prop());
        fgcommand("dialog-show", me.namenode);
    },
#################################################################
    close : func {
        fgcommand("dialog-close", me.namenode);
    },
#################################################################
    destroy : func {
        ABOUT_DLG = 0;
        me.close();
        delete(gui.dialog, "\"" ~ me.title ~ "\"");
    },
#################################################################
    show : func {
        if (!ABOUT_DLG) {
            ABOUT_DLG = 1;
            me.init(400, getprop("/sim/startup/ysize") - 500);
            me.create();
        }
    }
};
###############################################################################

# Popup the about dialog.
var about = func {
    dialog.show();
}
