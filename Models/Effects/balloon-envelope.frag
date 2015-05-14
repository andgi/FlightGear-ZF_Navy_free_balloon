// -*-C++-*-
//  Balloon envelope fragment shader based on Shaders/model-default.frag.
//
//  Copyright (C) 2009 - 2010  Tim Moore         (timoore(at)redhat.com)
//  Copyright (C) 2010 - 2015  Anders Gidenstam  (anders(at)gidenstam.org)
//  This file is licensed under the GPL license version 2 or later.

#version 120

// Ambient term comes in gl_Color.rgb.
varying vec4 diffuse_term;
varying vec3 normal, tangent;
varying float alpha, pressureDelta, angle;//, loosness;

uniform sampler2D texture;

////fog "include" /////
uniform int fogType;

vec3 fog_Func(vec3 color, int type);
//////////////////////

void main()
{
    vec3 n, t, halfV;
    float NdotL, NdotHV, fogFactor;
    vec4 color = gl_FrontLightModelProduct.sceneColor + gl_Color;
    vec3 lightDir = gl_LightSource[0].position.xyz;
    vec3 halfVector = gl_LightSource[0].halfVector.xyz;
    vec4 texel;
    vec4 fragColor;
    vec4 specular = vec4(0.0);
    n = normalize(normal);
    // Add some normal variation due to wrinkles. 
    if (pressureDelta > 0.0) {
        t = normalize(tangent);
        float f = 0.25 * pressureDelta * sin(32.0*angle);
        n = normalize(n + f*t);
    }

    // If gl_Color.a == 0, this is a back-facing polygon and the
    // normal should be reversed.
    n = (2.0 * gl_Color.a - 1.0) * n;
    NdotL = max(dot(n, lightDir), 0.0);
    if (NdotL > 0.0) {
        color += diffuse_term * NdotL;
        halfV = normalize(halfVector);
        NdotHV = max(dot(n, halfV), 0.0);
        if (gl_FrontMaterial.shininess > 0.0)
            specular.rgb = (gl_FrontMaterial.specular.rgb
                            * gl_LightSource[0].specular.rgb
                            * pow(NdotHV, gl_FrontMaterial.shininess));
    }
    color.a = diffuse_term.a;
    // This shouldn't be necessary, but our lighting becomes very
    // saturated. Clamping the color before modulating by the texture
    // is closer to what the OpenGL fixed function pipeline does.
    color = clamp(color, 0.0, 1.0);
    texel = texture2D(texture, gl_TexCoord[0].st);
    fragColor = color * texel + specular;

    gl_FragColor = vec4(fog_Func(fragColor.rgb, fogType), fragColor.a);
}
