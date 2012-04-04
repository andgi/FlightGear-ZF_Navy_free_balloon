//
//  Balloon envelope fragment shader based on Shaders/deferred-gbuffer.vert.
//
//  Copyright (C) 2012  Frederic Bouvier  (fredfgfs01(at)free.fr)
//  Copyright (C) 2012  Anders Gidenstam  (anders(at)gidenstam.org)
//  This file is licensed under the GPL license version 2 or later.
//
// attachment 0:  normal.x  |  normal.x  |  normal.y  |  normal.y
// attachment 1: diffuse.r  | diffuse.g  | diffuse.b  | material Id
// attachment 2: specular.l | shininess  | emission.l |  unused
//

varying vec3 ecNormal;
varying float alpha;

uniform int materialID;
uniform sampler2D texture;

// Balloon envelope specific varyings.
varying vec3 ecTangent;
varying float pressureDelta, angle;//, looseness;

void main() {
    vec3 normal = normalize(ecNormal);
    // Add some normal variation due to wrinkles. 
    if (pressureDelta > 0.0) {
        vec3 t = normalize(ecTangent);
        float f = 0.25 * pressureDelta * sin(72.0*angle);
        normal = normalize(normal + f*t);
    }

    // Default fragment shader below, except that normal replaces ecNormal.
    vec4 texel = texture2D(texture, gl_TexCoord[0].st);
    if (texel.a * alpha < 0.1)
        discard;
    float specular = dot( gl_FrontMaterial.specular.rgb, vec3( 0.3, 0.59, 0.11 ) );
    float shininess = gl_FrontMaterial.shininess;
    float emission = dot( gl_FrontLightModelProduct.sceneColor.rgb, vec3( 0.3, 0.59, 0.11 ) );
    
    vec3 normal2 = normalize( (2.0 * gl_Color.a - 1.0) * normal );
    gl_FragData[0] = vec4( (normal2.xy + vec2(1.0,1.0)) * 0.5, 0.0, 1.0 );
    gl_FragData[1] = vec4( gl_Color.rgb * texel.rgb, float( materialID ) / 255.0 );
    gl_FragData[2] = vec4( specular, shininess / 255.0, emission, 1.0 );
}
