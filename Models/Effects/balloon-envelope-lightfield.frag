// -*-C++-*-
// -*-C++-*-
//  Balloon envelope fragment shader based on Shaders/terrain-haze.frag.
//
//  Copyright (C) 2009 - 2011  Tim Moore         (timoore(at)redhat.com)
//  Copyright (C) 2011 - 2012  Thorsten Renk
//  Copyright (C) 2012  Anders Gidenstam  (anders(at)gidenstam.org)
//  This file is licensed under the GPL license version 2 or later.

// Ambient term comes in gl_Color.rgb.
varying vec4 diffuse_term;
varying vec3 normal;
varying vec3 relPos;


uniform sampler2D texture;


varying float yprime_alt;
varying float mie_angle;

uniform float visibility;
uniform float avisibility;
uniform float scattering;
//uniform float ground_scattering;
uniform float terminator;
uniform float terrain_alt; 
uniform float hazeLayerAltitude;
uniform float overcast;
//uniform float altitude;
uniform float eye_alt;

const float EarthRadius = 5800000.0;
const float terminator_width = 200000.0;

float alt;
float eShade;

// Balloon specific
varying vec3 tangent;
varying float pressureDelta, angle;//, looseness;
// End Balloon specific


float luminance(vec3 color)
{
    return dot(vec3(0.212671, 0.715160, 0.072169), color);
}


float light_func (in float x, in float a, in float b, in float c, in float d, in float e)
{
     x = x - 0.5;

     // use the asymptotics to shorten computations
     if (x > 30.0) {return e;}
     if (x < -15.0) {return 0.0;}

     return e / pow((1.0 + a * exp(-b * (x-c)) ),(1.0/d));
}

// this determines how light is attenuated in the distance
// physically this should be exp(-arg) but for technical reasons we use a sharper cutoff
// for distance > visibility

float fog_func (in float targ)
{
    float fade_mix;

    // for large altitude > 30 km, we switch to some component of quadratic distance fading to
    // create the illusion of improved visibility range

    targ = 1.25 * targ; // need to sync with the distance to which terrain is drawn


    if (alt < 30000.0) {
        return exp(-targ - targ * targ * targ * targ);
    } else if (alt < 50000.0) {
	fade_mix = (alt - 30000.0)/20000.0;
	return fade_mix * exp(-targ*targ - pow(targ,4.0)) + (1.0 - fade_mix) * exp(-targ - pow(targ,4.0));	
    } else {
        return exp(- targ * targ - pow(targ,4.0));
    }
}

void main()
{

    // this is taken from default.frag
    vec3 n;
    float NdotL, NdotHV, fogFactor;
    vec4 color = gl_Color;
    vec3 lightDir = gl_LightSource[0].position.xyz;
    vec3 halfVector = gl_LightSource[0].halfVector.xyz;
    vec4 texel;
    vec4 fragColor;
    vec4 specular = vec4(0.0);
    float intensity;


    // Balloon specific
    n = normalize(normal);
    // Add some normal variation due to wrinkles. 
    if (pressureDelta > 0.0) {
        vec3 t = normalize(tangent);
        float f = 0.25 * pressureDelta * sin(72.0*angle);
        n = normalize(n + f*t);
    }
    // End Balloon specific


    vec4 light_specular = gl_LightSource[0].specular;

    // If gl_Color.a == 0, this is a back-facing polygon and the
    // normal should be reversed.
    n = (2.0 * gl_Color.a - 1.0) * n;

    NdotL = dot(n, lightDir);
    if (NdotL > 0.0) {
        color += diffuse_term * NdotL;
        NdotHV = max(dot(n, halfVector), 0.0);
        if (gl_FrontMaterial.shininess > 0.0)
            specular.rgb = (gl_FrontMaterial.specular.rgb
                            * light_specular.rgb
                            * pow(NdotHV, gl_FrontMaterial.shininess));
    }
    color.a = diffuse_term.a;
    // This shouldn't be necessary, but our lighting becomes very
    // saturated. Clamping the color before modulating by the texture
    // is closer to what the OpenGL fixed function pipeline does.
    color = clamp(color, 0.0, 1.0);
    texel = texture2D(texture, gl_TexCoord[0].st);
    fragColor = color * texel + specular;



    // here comes the terrain haze model
    float delta_z = hazeLayerAltitude - eye_alt;
    float dist = length(relPos);

    if (dist > max(40.0, 0.04 * min(visibility,avisibility))) {
        //if (dist > 40.0) {
        alt = eye_alt;

        float transmission;
        float vAltitude;
        float delta_zv;
        float H;
        float distance_in_layer;
        float transmission_arg;

        // angle with horizon
        float ct = dot(vec3(0.0, 0.0, 1.0), relPos)/dist;


        // we solve the geometry what part of the light path is attenuated normally and what is through the haze layer

        if (delta_z > 0.0) { // we're inside the layer
            if (ct < 0.0) { // we look down 
                distance_in_layer = dist;
		vAltitude = min(distance_in_layer,min(visibility, avisibility)) * ct;
  		delta_zv = delta_z - vAltitude;
            } else { 	// we may look through upper layer edge
		H = dist * ct;
		if (H > delta_z) {distance_in_layer = dist/H * delta_z;}
		else {distance_in_layer = dist;}
		vAltitude = min(distance_in_layer,visibility) * ct;
  		delta_zv = delta_z - vAltitude;	
            }
	} else { // we see the layer from above, delta_z < 0.0
            H = dist * -ct;
            if (H  < (-delta_z)) { // we don't see into the layer at all, aloft visibility is the only fading
		distance_in_layer = 0.0;
		delta_zv = 0.0;
            } else {
		vAltitude = H + delta_z;
		distance_in_layer = vAltitude/H * dist; 
		vAltitude = min(distance_in_layer,visibility) * (-ct);
		delta_zv = vAltitude;
            } 
	}


        // ground haze cannot be thinner than aloft visibility in the model,
        // so we need to use aloft visibility otherwise
        transmission_arg = (dist-distance_in_layer)/avisibility;


        float eqColorFactor;
        //float scattering = ground_scattering + (1.0 - ground_scattering) * smoothstep(hazeLayerAltitude -100.0, hazeLayerAltitude + 100.0, relPos.z + eye_alt);

        if (visibility < avisibility) {
            transmission_arg = transmission_arg + (distance_in_layer/visibility);
            // this combines the Weber-Fechner intensity
            eqColorFactor = 1.0 - 0.1 * delta_zv/visibility - (1.0 -scattering);
	} else {
            transmission_arg = transmission_arg + (distance_in_layer/avisibility);
            // this combines the Weber-Fechner intensity
            eqColorFactor = 1.0 - 0.1 * delta_zv/avisibility - (1.0 -scattering);
	}

        transmission =  fog_func(transmission_arg);

        // there's always residual intensity, we should never be driven to zero
        if (eqColorFactor < 0.2) eqColorFactor = 0.2;

        float lightArg = (terminator-yprime_alt)/100000.0;
        vec3 hazeColor;

        hazeColor.b = light_func(lightArg, 1.330e-05, 0.264, 2.527, 1.08e-05, 1.0);
        hazeColor.g = light_func(lightArg, 3.931e-06, 0.264, 3.827, 7.93e-06, 1.0);
        hazeColor.r = light_func(lightArg, 8.305e-06, 0.161, 3.827, 3.04e-05, 1.0);

        // now dim the light for haze
        eShade = 0.9 * smoothstep(terminator_width+ terminator, -terminator_width + terminator, yprime_alt) + 0.1;

        // Mie-like factor
        if (lightArg < 10.0) {
            intensity = length(hazeColor);
            float mie_magnitude = 0.5 * smoothstep(350000.0, 150000.0, terminator-sqrt(2.0 * EarthRadius * terrain_alt));
            hazeColor = intensity * ((1.0 - mie_magnitude) + mie_magnitude * mie_angle) * normalize(mix(hazeColor,  vec3 (0.5, 0.58, 0.65), mie_magnitude * (0.5 - 0.5 * mie_angle)) ); 
	}

        // high altitude desaturation of the haze color
        intensity = length(hazeColor);
        hazeColor = intensity * normalize (mix(hazeColor, intensity * vec3 (1.0,1.0,1.0), 0.7* smoothstep(5000.0, 50000.0, alt)));

        // blue hue of haze
        hazeColor.x = hazeColor.x * 0.83;
        hazeColor.y = hazeColor.y * 0.9; 


        // additional blue in indirect light
        float fade_out = max(0.65 - 0.3 *overcast, 0.45);
        intensity = length(hazeColor);
        hazeColor = intensity * normalize(mix(hazeColor,  1.5* vec3 (0.45, 0.6, 0.8), 1.0 -smoothstep(0.25, fade_out,eShade) )); 

        // change haze color to blue hue for strong fogging
        //intensity = length(hazeColor);
        hazeColor = intensity * normalize(mix(hazeColor,  2.0 * vec3 (0.55, 0.6, 0.8), (1.0-smoothstep(0.3,0.8,eqColorFactor)))); 

        // reduce haze intensity when looking at shaded surfaces, only in terminator region
        float shadow = mix( min(1.0 + dot(normal,lightDir),1.0), 1.0, 1.0-smoothstep(0.1, 0.4, transmission));
        hazeColor = mix(shadow * hazeColor, hazeColor, 0.3 + 0.7* smoothstep(250000.0, 400000.0, terminator));

        // determine the right mix of transmission and haze
        fragColor.xyz = mix(eqColorFactor * hazeColor * eShade, fragColor.xyz,transmission);
        gl_FragColor = fragColor;
    } else { // if dist < 40.0 no fogging at all 
        gl_FragColor = fragColor;
    }
}
