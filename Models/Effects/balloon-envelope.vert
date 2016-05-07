// -*-C++-*-
//  Balloon envelope vertex shader based on Shaders/model-default.vert.
//
//  Copyright (C) 2009 - 2010  Tim Moore         (timoore(at)redhat.com)
//  Copyright (C) 2010 - 2016  Anders Gidenstam  (anders(at)gidenstam.org)
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

void balloon_envelope_geometry_func(out vec4 oPosition, out vec3 oNormal);

// The ambient term of the lighting equation that doesn't depend on
// the surface normal is passed in gl_{Front,Back}Color. The alpha
// component is set to 1 for front, 0 for back in order to work around
// bugs with gl_FrontFacing in the fragment shader.
varying vec4 diffuse_term;
varying vec3 normal;
uniform int colorMode;

////fog "include" /////
uniform int fogType;

vec3 fog_Func(vec3 color, int type);
//////////////////////

void main()
{
    // Balloon specific
    vec4 oPosition;
    vec3 oNormal;
    balloon_envelope_geometry_func(oPosition, oNormal);
    // End Balloon specific

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
