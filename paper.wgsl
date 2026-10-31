// The Paper theme's worn sheet, laid over a drawer's cream body. Its box is the drawer's, grown by a margin on every side (s.a.z), and it does three things:
//   - the TORN EDGE: a ragged fringe of paper just outside the clean body, its outline moving in and out like a tear, with a pale line of fibres along it;
//   - the WEAR: the edge rubbed darker, to a depth that wanders along it;
//   - the GRAIN: long fibres, a few specks and a faint stain or two.
// The fringe is only painted in a thin ring at the body's edge, so nothing drawn inside the drawer is covered. Everything comes from the point's place:
// it never moves and costs nothing while nothing changes (it does not read `time`).
//
// s.a.x how strong the grain is (0 to 1) · s.a.y a seed, so two sheets are not the same · s.a.z the margin round the drawer · s.a.w the corner radius
// s.color the paper (the body's colour) · s.color2 the brown of the wear

fn hash(p: vec2<f32>) -> f32 {
    var q = fract(p * vec2<f32>(0.1031, 0.1030));
    q = q + dot(q, q.yx + vec2<f32>(33.33, 33.33));
    return fract((q.x + q.y) * q.x);
}

fn vnoise(p: vec2<f32>) -> f32 {
    let i = floor(p);
    let f = fract(p);
    let u = f * f * (3.0 - 2.0 * f);
    return mix(mix(hash(i), hash(i + vec2<f32>(1.0, 0.0)), u.x),
               mix(hash(i + vec2<f32>(0.0, 1.0)), hash(i + vec2<f32>(1.0, 1.0)), u.x), u.y);
}

fn shade(s: Shader) -> vec4<f32> {
    let m = s.a.z;
    let seed = vec2<f32>(s.a.y * 91.7, s.a.y * 37.3);
    let p = s.pos + seed;

    // How far this point is from the drawer's edge (negative inside), as a rounded rectangle.
    let half = (s.size - vec2<f32>(2.0 * m, 2.0 * m)) * 0.5;
    let q = abs(s.pos - s.size * 0.5) - half + vec2<f32>(s.a.w, s.a.w);
    let d = length(max(q, vec2<f32>(0.0, 0.0))) + min(max(q.x, q.y), 0.0) - s.a.w;

    // Where along the nearest edges this point is. The pattern is tied to the panel, not to the box: a side's noise runs along that side from its top or left
    // corner, with a key of its own for each of the four, so when the panel opens, closes or wobbles the tear travels with it instead of crawling.
    let dxl = s.pos.x - m;
    let dxr = s.size.x - m - s.pos.x;
    let dyt = s.pos.y - m;
    let dyb = s.size.y - m - s.pos.y;
    let key_v = mix(31.0, 7.0, step(dxl, dxr)) * 13.7 + s.a.y * 3.1;
    let key_h = mix(53.0, 19.0, step(dyt, dyb)) * 13.7 + s.a.y * 3.1;
    let near_v = min(dxl, dxr);
    let near_h = min(dyt, dyb);
    let on_v = smoothstep(-8.0, 8.0, near_h - near_v);       // 1 where a left or right side is the nearer, 0 for a top or bottom one
    let av = s.pos.y;
    let ah = s.pos.x;

    // The tear: the outline sits between 1.5 and 7 px outside the body, wandering slowly and fraying finely.
    let tear_v = vnoise(vec2<f32>(av * 0.11, key_v)) * 0.5 + vnoise(vec2<f32>(av * 0.5, key_v + 3.7)) * 0.32 + vnoise(vec2<f32>(av * 1.9, key_v + 9.1)) * 0.18;
    let tear_h = vnoise(vec2<f32>(ah * 0.11, key_h)) * 0.5 + vnoise(vec2<f32>(ah * 0.5, key_h + 3.7)) * 0.32 + vnoise(vec2<f32>(ah * 1.9, key_h + 9.1)) * 0.18;
    let tear = mix(tear_h, tear_v, on_v);
    let reach = 1.5 + 5.5 * tear;
    let into = reach - d;                                   // how far inside the torn outline (negative: outside it)
    let cover = clamp(into + 0.5, 0.0, 1.0);
    let ring = smoothstep(-4.0, -2.0, d);                   // the fringe is only painted where the body ends, never inside the drawer

    // The wear: rubbed darker at the edge, to a depth that wanders (along the sides, like the tear).
    let wander = mix(vnoise(vec2<f32>(ah * 0.06, key_h + 5.3)), vnoise(vec2<f32>(av * 0.06, key_v + 5.3)), on_v);
    let depth = 4.0 + 10.0 * wander + 3.0 * tear;
    let wear = pow(clamp(1.0 - into / depth, 0.0, 1.0), 1.6);
    // The grain.
    let fib = vnoise(vec2<f32>(p.x * 0.85, p.y * 0.1)) * vnoise(vec2<f32>(p.x * 0.09, p.y * 0.75));
    let speck = step(0.988, hash(floor(p * 0.8)));
    let stain = smoothstep(0.66, 0.92, vnoise(p * 0.017 + vec2<f32>(7.0, 2.0)));

    let over = clamp((wear * 0.34 + fib * 0.075 + speck * 0.2 + stain * 0.08) * s.a.x, 0.0, 0.6) * cover;
    // The pale line of fibres along the tear, broken up so it is not a stroke.
    let pale = (1.0 - smoothstep(0.0, 2.4, into)) * smoothstep(0.25, 0.7, vnoise(p * 0.9)) * cover;
    let paper = mix(s.color.rgb, vec3<f32>(1.0, 0.985, 0.94), pale * 0.75);

    let under = cover * ring;
    let alpha = over + under * (1.0 - over);
    let rgb = (s.color2.rgb * over + paper * under * (1.0 - over)) / max(alpha, 0.0001);
    return vec4<f32>(rgb, alpha);
}
