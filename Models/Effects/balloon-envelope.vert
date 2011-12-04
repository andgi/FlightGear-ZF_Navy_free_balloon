// -*-C++-*-
//  Balloon envelope vertex shader based on Shaders/model-default.vert.
//
//  Copyright (C) 2009 - 2010  Tim Moore         (timoore(at)redhat.com)
//  Copyright (C) 2010 - 2011  Anders Gidenstam  (anders(at)gidenstam.org)
//  This file is licensed under the GPL license version 2 or later.

// Shader that uses OpenGL state values to do per-pixel lighting
//
// The only light used is gl_LightSource[0], which is assumed to be
// directional.
//
// Diffuse colors come from the gl_Color, ambient from the material. This is
// equivalent to osg::Material::DIFFUSE.

#version 120

#define MODE_OFF 0
#define MODE_DIFFUSE 1
#define MODE_AMBIENT_AND_DIFFUSE 2

uniform float gas_level_ft;
const float r = 6.185; // [meter]

// The ambient term of the lighting equation that doesn't depend on
// the surface normal is passed in gl_{Front,Back}Color. The alpha
// component is set to 1 for front, 0 for back in order to work around
// bugs with gl_FrontFacing in the fragment shader.
varying vec4 diffuse_term;
varying vec3 normal, tangent;
varying float pressureDelta, angle;//, looseness;
uniform int colorMode;

////fog "include" /////
uniform int fogType;

vec3 fog_Func(vec3 color, int type);
//////////////////////

void main()
{
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
    tangent = gl_NormalMatrix * oTangent;

    // Default vertex shader below, except that oPosition replaces
    // gl_Vertex and oNormal replaces gl_Normal.
    gl_Position = gl_ModelViewProjectionMatrix * oPosition;
    gl_TexCoord[0] = gl_TextureMatrix[0] * gl_MultiTexCoord0;
    normal = gl_NormalMatrix * oNormal;
    vec4 ambient_color, diffuse_color;
    if (colorMode == MODE_DIFFUSE) {
        diffuse_color = gl_Color;
        ambient_color = gl_FrontMaterial.ambient;
    } else if (colorMode == MODE_AMBIENT_AND_DIFFUSE) {
        diffuse_color = gl_Color;
        ambient_color = gl_Color;
    } else {
        diffuse_color = gl_FrontMaterial.diffuse;
        ambient_color = gl_FrontMaterial.ambient;
    }
    diffuse_term = diffuse_color * gl_LightSource[0].diffuse;
    vec4 ambient_term = ambient_color * gl_LightSource[0].ambient;
    // Super hack: if diffuse material alpha is less than 1, assume a
    // transparency animation is at work
    if (gl_FrontMaterial.diffuse.a < 1.0)
        diffuse_term.a = gl_FrontMaterial.diffuse.a;
    else
        diffuse_term.a = gl_Color.a;
    // Another hack for supporting two-sided lighting without using
    // gl_FrontFacing in the fragment shader.
    gl_FrontColor.rgb = ambient_term.rgb;  gl_FrontColor.a = 1.0;
    //gl_BackColor.rgb = ambient_term.rgb; gl_FrontColor.a = 0.0;
}
