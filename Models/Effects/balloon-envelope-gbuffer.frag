//
//  Balloon envelope fragment shader based on Shaders/deferred-gbuffer.vert.
//
//  Copyright (C) 2012  Frederic Bouvier  (fredfgfs01(at)free.fr)
//  Copyright (C) 2012 - 2015  Anders Gidenstam  (anders(at)gidenstam.org)
//  This file is licensed under the GPL license version 2 or later.
//

varying vec3 ecNormal;
varying float alpha;

uniform int materialID;
uniform sampler2D texture;

// Balloon envelope specific varyings.
varying vec3 ecTangent;
varying float pressureDelta, angle;//, looseness;

void encode_gbuffer(vec3 normal, vec3 color, int mId, float specular, float shininess, float emission, float depth);

void main() {
    vec3 normal = normalize(ecNormal);
    // Add some normal variation due to wrinkles. 
    if (pressureDelta > 0.0) {
        vec3 t = normalize(ecTangent);
        float f = 0.25 * pressureDelta * sin(32.0*angle);
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
    encode_gbuffer(normal2, gl_Color.rgb * texel.rgb, materialID, specular, shininess, emission, gl_FragCoord.z);
}
