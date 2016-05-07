// -*-C++-*-
//  Balloon envelope geometry vertex shader function.
//
//  Copyright (C) 2010 - 2016  Anders Gidenstam  (anders(at)gidenstam.org)
//  This file is licensed under the GPL license version 2 or later.

#version 120

uniform float gas_level_ft;
const float r = 6.185; // [meter]

varying float pressureDelta, angle;//, looseness;
varying vec3  tangent;

void balloon_envelope_geometry_func(out vec4 oPosition, out vec3 oNormal)
{
    // Compute vertex position in object space.
    oPosition = gl_Vertex;
    oNormal   = gl_Normal;

    float h = max(1.0, 0.3048 * gas_level_ft); // [meter]

    pressureDelta = 0.0;
    //looseness = 0.0;
    if (oPosition.z < r - h) {
        if (h < r) {
            float lxy = length(oPosition.xy);
            float lmax = max(0.1,r*sqrt(1.0 - ((r-h)/r)*((r-h)/r)));
            oPosition.xy *= min(1.0,lmax/lxy);
        }
        float lxy = length(oPosition.xy);
        float nz  = r - (h + pow(1.0 - lxy/r, 5.0)*(2.5*r - h));
        float dlxy = -5.0*(2.5*r - h)/r * pow(1.0 - lxy/r, 4.0); // Derivative map lxy

        oNormal.z = sqrt(1.0 - dot(oNormal.xy,oNormal.xy))/dlxy;
        oNormal = normalize(oNormal);

        oPosition.z = min(r - h, max(nz, oPosition.z));
        pressureDelta = sqrt(-0.5*(h + oPosition.z - r)/r);
    }

    // The balloon envelope is assumed to be symetric around the z axis.
    vec2 tmp = normalize(oPosition.xy);
    angle = asin(tmp.y);
    vec3 oTangent = vec3(-tmp.y, tmp.x, 0);
    tangent = gl_NormalMatrix * oTangent;
}
