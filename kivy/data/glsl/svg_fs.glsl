#version 130
#ifdef GL_ES
    precision highp float;
#endif

varying vec2 coord;
varying vec2 texcoord;
varying vec4 vertex_color;
varying float gradient;
varying float gradient_param1;
varying float gradient_param2;
varying float gradient_param3;
varying float gradient_param4;
varying float gradient_param5;
varying float gradient_param6;

uniform sampler2D texture0;
uniform sampler2D gradients;
uniform vec2 gradients_size;
uniform float time;

#define LINEAR 0
#define RADIAL 1

#define PAD 1
#define REPEAT 2
#define REFLECT 3

#define USER_SPACE 1
#define OBJECT_BBOX 2

float linear_gradient(vec2 pos) {
    vec2 x1 = vec2(gradient_param1, gradient_param3);
    vec2 x2 = vec2(gradient_param2, gradient_param4);
    vec2 dt = x2 - x1;
    vec2 pt = pos - x1;
    return dot(pt, dt) / dot(dt, dt);
}

float radial_gradient(vec2 pos) {
    // return 0.;
    float cx = gradient_param1;
    float cy = gradient_param2;
    float rx = gradient_param3;
    float ry = gradient_param4;
    float fx = gradient_param5;
    float fy = gradient_param6;

    vec2 d = vec2(fx, fy) - pos;
    vec2 center = vec2(cx, cy);
    vec2 radius = vec2(rx, ry);

    // return length(d) / 100.;
    float l = length(d);
    center /= l;
    radius /= l;

    d /= l;

    float cd = dot(center, vec2(-d.y, d.x)),
          cl = sqrt(radius.x * radius.x - cd * cd) + dot(center, d);

    float a_cl = 1. / cl;

    // special case for when focale point is outside of radius
    if (a_cl < 0.)
        a_cl = 1.;

    return a_cl;
}

float g(int index){
    return texture2D(
        gradients,
        vec2(
            float(index) / gradients_size.x,
            gradient / gradients_size.y
        )
    ).r;
}

int ig(int index) {
    return int(g(index) * 255.);
}

vec4 interp() {
    vec4 col1, col2;
    float t;

    int i = 0;
    int type = ig(i++);
    // return texture2D(gradients, texcoord);
    // return vec4(0., 0., float(type), 1.);

    int spread = ig(i++);
    int units = ig(i++);

    // XXX either use units here, or on python side and remove them from
    // texture

    // return vec4(coord.x, 0., 0., 1.);
    if (type == LINEAR) {
        /* return vec4(1., 1., 0., 1.); */
        t = linear_gradient(coord);
        /* return vec4(t, 0., 0., 1.); */
    }

    else if (type == RADIAL) {
        return vec4(0., 1., 0., 1.);
        t = radial_gradient(coord);
    } else {
        // show that something is wrong
        float xxr, xxg, xxb;
        xxr = float(type & 4);
        xxg = float(type & 2);
        xxb = float(type & 1);
        return vec4(xxr, xxg, xxb, 1.);
        // return vec4(1., 0., 1., 1.);
    }

    // t = 1. - t;
    /* return vec4(t, 0., 0., 1); */

    int stops = ig(i++);
    // don't increment for these two calls, to avoid breaking the next
    // loop
    float first_stop = g(i);
    // first index of last stop XXX is it really though?
    float last_stop = g(i + 5 * (stops - 1));

    // now we have first and last stop value, and spread, we can fix it if needed
    if (!(first_stop < t && t < last_stop)) {
        if (spread == PAD)
            t = max(0., min(1., t));
        else if (spread == REPEAT)
            // XXX check for negative numbers
            t = fract(t);
        else if (spread ==  REFLECT) {
            float n = floor(t);
            float r = fract(t);
            if (mod(n, 2.) >= 1.)
                t = 1. - r;
            else
                t = r;
        }
     }

    // search the correct stop with a corrected t (between first and
    // last stop)
    float previous_stop = g(i++);
    col1 = vec4(
        g(i++), // R
        g(i++), // G
        g(i++), // B
        g(i++)  // A
    );

    if (previous_stop > t)
        return col1;

    for (int i_s=1; i_s < stops; i_s++) {
        float stop = g(i++);

        col2 = col1;
        col1 = vec4(g(i++), g(i++), g(i++), g(i++));

        if (previous_stop < t && t < stop)
            /* return col2; */
            return mix(col2, col1, (t - previous_stop) * (stop - previous_stop));

        else if (t < stop)
            return col1;

        previous_stop = stop;
    }
    // we didn't find a last stop superior to t, so we must be in padding mode
    return col1;
}

void main (void) {
    if (gradient >= 1.) {
        // debug gradient ids, only good up to 4 ids, requires #version 130
        // int gid = int(gradient - 1.);
        // float xxr, xxg, xxb;
        // xxr = float(gid & 4);
        // xxg = float(gid & 2);
        // xxb = float(gid & 1);
        // gl_FragColor = vec4(xxr, xxg, xxb, 1.);

        // check that the texture is correctly uploaded
        // gl_FragColor = texture2D(gradients, coord / (gradients_size);
        gl_FragColor = interp();
    } else
        gl_FragColor = texture2D(texture0, texcoord) * (vertex_color / 255.);
}
