//
//  Balloon envelope vertex shader based on Shaders/deferred-gbuffer.vert.
//
//  Copyright (C) 2012  Frederic Bouvier  (fredfgfs01(at)free.fr)
//  Copyright (C) 2012  Anders Gidenstam  (anders(at)gidenstam.org)
//  This file is licensed under the GPL license version 2 or later.
//
// attachment 0:  normal.x  |  normal.x  |  normal.y  |  normal.y
// attachment 1: diffuse.r  | diffuse.g  | diffuse.b  | material Id
// attachment 2: specular.l | shininess  | emission.l |  unused
//

// Balloon envelope specific constants.
uniform float gas_level_ft;
const float r = 6.185; // [meter]

varying vec3 ecNormal;
varying vec4 color;
// Balloon envelope specific varyings.
varying vec3 ecTangent;
varying float pressureDelta, angle;//, looseness;


void main() {
    // Compute vertex position in object space.
    vec4 oPosition = gl_Vertex;
    vec3 oNormal   = gl_Normal;

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

        oNormal.z = sqrt(1.0 - pow(oNormal.x,2.0) - pow(oNormal.y,2.0))/dlxy;
        oNormal = normalize(oNormal);
        
        oPosition.z = min(r - h, max(nz, oPosition.z));
        pressureDelta = sqrt(-0.5*(h + oPosition.z - r)/r);
    }
    angle = asin(oNormal.y);

    // The balloon envelope is assumed to be symetric around the z axis.
    vec2 tmp = normalize(oPosition.xy);
    vec3 oTangent = vec3(-tmp.y, tmp.x, 0);
    ecTangent = gl_NormalMatrix * oTangent;

    // Default vertex shader below, except that oPosition replaces
    // gl_Vertex and oNormal replaces gl_Normal.
    ecNormal = gl_NormalMatrix * oNormal;
    gl_Position = gl_ModelViewProjectionMatrix * oPosition;
    gl_TexCoord[0] = gl_TextureMatrix[0] * gl_MultiTexCoord0;
    color = gl_Color;
}
