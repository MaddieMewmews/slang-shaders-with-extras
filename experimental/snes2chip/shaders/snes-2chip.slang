#version 450

layout(push_constant) uniform Push
{
    vec4 SourceSize;
    vec4 OutputSize;
    uint FrameCount;
    float AlphaRise;
    float AlphaFall;
    float ChannelCapacitanceDrag; // Single parameter governing physical line load
    float EnableOvershoot;
    float RingingFrequency;
    float RingingDamping;
} params;

// Calibrated hardware coefficients matching raw oscilloscope voltage drop curves
#pragma parameter AlphaRise "S-PPU2 Pin Rise Speed" 0.65 0.40 1.00 0.01
#pragma parameter AlphaFall "S-PPU2 Pin Base Fall Speed" 0.73 0.40 1.00 0.01
#pragma parameter ChannelCapacitanceDrag "Silicon Line Cap Drag" 0.35 0.00 1.00 0.05
#pragma parameter EnableOvershoot "Toggle S-PPU2 Ringing/Overshoot" 1.0 0.0 1.0 1.0
#pragma parameter RingingFrequency "Overshoot Oscillation Speed" 1.55 0.50 4.00 0.05
#pragma parameter RingingDamping "Overshoot Signal Decay Rate" 0.58 0.10 1.00 0.05

layout(std140, set = 0, binding = 0) uniform UBO
{
    mat4 MVP;
} global;

#pragma stage vertex
layout(location = 0) in vec4 Position;
layout(location = 1) in vec2 TexCoord;
layout(location = 0) out vec2 vTexCoord;

void main()
{
   gl_Position = global.MVP * Position;
   vTexCoord = TexCoord;
}

#pragma stage fragment
layout(location = 0) in vec2 vTexCoord;
layout(location = 0) out vec4 FragColor;

layout(set = 0, binding = 2) uniform sampler2D Source;

void main()
{
    float current_x = vTexCoord.x * params.SourceSize.x;
    float current_y = vTexCoord.y;
    float inv_width = params.SourceSize.z;

    vec3 c0 = texture(Source, vec2(max(current_x - 3.0, 0.0) * inv_width, current_y)).rgb;
    vec3 c1 = texture(Source, vec2(max(current_x - 2.0, 0.0) * inv_width, current_y)).rgb;
    vec3 c2 = texture(Source, vec2(max(current_x - 1.0, 0.0) * inv_width, current_y)).rgb;
    vec3 c3 = texture(Source, vec2(vTexCoord.x, current_y)).rgb;

    vec3 simulated_voltage = c0;
    vec3 window[] = vec3[](c1, c2, c3);
    vec3 signal_velocity = vec3(0.0);

    for (int i = 0; i < 3; i++)
    {
        vec3 next_digital = window[i];

        // TRUE HARDWARE ACCURACY: The capacitance drag acts on each channel individually.
        // Higher channel amplitude = more line charge = slower discharge for that specific pin.
        vec3 channel_drag = simulated_voltage * params.ChannelCapacitanceDrag;
        vec3 integrated_fall = mix(vec3(params.AlphaFall), vec3(params.AlphaFall * 0.40), channel_drag);

        // Vectorized comparison handles channel execution entirely in parallel
        bvec3 standard_greater = greaterThan(next_digital, simulated_voltage);
        vec3 alpha = mix(integrated_fall, vec3(params.AlphaRise), vec3(standard_greater));

        vec3 baseline_step = alpha * (next_digital - simulated_voltage);

        if (params.EnableOvershoot > 0.5)
        {
            // Inductive overshoot is also a per-channel physical reaction
            vec3 acceleration = (next_digital - simulated_voltage) * params.RingingFrequency;
            signal_velocity = (signal_velocity + acceleration) * (1.0 - params.RingingDamping);
            simulated_voltage = clamp(simulated_voltage + baseline_step + signal_velocity * 0.1, 0.0, 1.0);
        }
        else
        {
            simulated_voltage = simulated_voltage + baseline_step;
        }
    }

    // Process the final sub-pixel step matching the exact channel state rules
    vec3 final_channel_drag = simulated_voltage * params.ChannelCapacitanceDrag;
    vec3 final_integrated_fall = mix(vec3(params.AlphaFall), vec3(params.AlphaFall * 0.40), final_channel_drag);

    bvec3 final_greater = greaterThan(c3, simulated_voltage);
    vec3 final_alpha = mix(final_integrated_fall, vec3(params.AlphaRise), vec3(final_greater));

    float frac_part = fract(current_x);
    vec3 final_voltage_output = simulated_voltage;
    if (params.EnableOvershoot > 0.5)
    {
        final_voltage_output = clamp(final_voltage_output + signal_velocity * (fract(current_x) * 0.05), 0.0, 1.0);
    }

    vec3 final_color = mix(final_voltage_output, c3, frac_part * final_alpha);

    FragColor = vec4(final_color, 1.0);
}
