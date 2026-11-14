#version 460 core

#include <flutter/runtime_effect.glsl>

uniform float uTime;
uniform vec2 uResolution;
uniform float uIntensity;

out vec4 fragColor;

void main() {
    vec2 uv = FlutterFragCoord().xy / uResolution.xy;

    // Normalize coordinates to be centered
    vec2 p = uv * 2.0 - 1.0;
    p.x *= uResolution.x / uResolution.y;

    // Layered liquid waves
    float t = uTime * 0.5;
    float wave = sin(p.x * 2.0 + t) * 0.1;
    wave += sin(p.x * 1.5 - t * 1.2) * 0.05;
    wave += cos(p.x * 3.0 + t * 0.8) * 0.02;

    // Add audio intensity to wave height
    wave *= (1.0 + uIntensity * 2.0);

    float dist = abs(p.y - wave);

    // Colors (Gemini Inspired: Deep Blues, Purples, Cyans)
    vec3 color1 = vec3(0.1, 0.4, 0.9); // Azure
    vec3 color2 = vec3(0.5, 0.1, 0.8); // Purple
    vec3 color3 = vec3(0.0, 0.8, 0.7); // Cyan

    // Dynamic mixing based on time and position
    float mixFactor = sin(t + uv.x) * 0.5 + 0.5;
    vec3 baseColor = mix(color1, color2, mixFactor);
    baseColor = mix(baseColor, color3, cos(t * 0.7 + uv.y) * 0.5 + 0.5);

    // Glow effect
    float glow = 0.02 / (dist + 0.05);
    glow = pow(glow, 1.2);

    // Background gradient
    vec3 bgColor = vec3(0.02, 0.03, 0.08);
    vec3 finalColor = mix(bgColor, baseColor, glow * (0.5 + uIntensity));

    fragColor = vec4(finalColor, 1.0);
}
