uniform sampler2D auto_albedo_texture: repeat_disable, source_color;
uniform bool auto_albedo_texture_exists = false;
uniform sampler2D auto_albedo_flip_texture: repeat_disable, source_color;
uniform bool auto_albedo_flip_texture_exists = false;
uniform vec4 auto_albedo_color : source_color = vec4(1.0);