#version 460 core
#pragma flutter: entry-point
#include <flutter/runtime_effect.glsl>

uniform vec4 uColor; 
 // Added to match your Dart code

out vec4 fragColor;

void main() {
    // FlutterFragCoord() gives coordinates in physical pixels
    vec2 fragCoord = FlutterFragCoord();
    
    // Output the color passed from Dart
    fragColor = uColor;
}
