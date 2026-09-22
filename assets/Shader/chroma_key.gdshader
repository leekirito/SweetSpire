shader_type canvas_item;

// The color you want to make transparent (Defaults to Green Screen)
uniform vec4 chroma_key_color : source_color = vec4(0.0, 1.0, 0.0, 1.0);

// How close the video pixels need to be to the key color to get cut out
uniform float threshold : hint_range(0.0, 1.0, 0.01) = 0.3;

// Smooths out the pixel edges to prevent harsh jagged lines
uniform float fade : hint_range(0.0, 1.0, 0.01) = 0.1;

void fragment() {
    // Fetch the original pixel color from the OGV video stream
    vec4 video_color = texture(TEXTURE, UV);
    
    // Calculate the distance between the pixel color and your target chroma key color
    float color_dist = distance(video_color.rgb, chroma_key_color.rgb);
    
    // Smoothly calculate transparency based on threshold and fade ranges
    float alpha = smoothstep(threshold, threshold + fade, color_dist);
    
    // Output the video frame with the calculated transparency
    COLOR = vec4(video_color.rgb, video_color.a * alpha);
}
