#define TYPE_qiu 5.
#define TYPE_qigan 6.
#define TYPE_hongqi 7.
#define TYPE_xingxing 8.
#define TYPE_rocket 9.
#define TYPE_fire 10.

#define EPSILON 0.0001
#define MAX_DIST 200.
#define MAX_ITER 200

#define ANIMATION_SPEED 1.5
#define MOVEMENT_SPEED 1.0
#define MOVEMENT_DIRECTION vec2(0.7, 1.0)

#define PARTICLE_SIZE 0.005

#define PARTICLE_SCALE (vec2(1.2, 1.9))
#define PARTICLE_SCALE_VAR (vec2(0.25, 0.2))

#define PARTICLE_BLOOM_SCALE (vec2(0.5, 0.8))
#define PARTICLE_BLOOM_SCALE_VAR (vec2(0.3, 0.1))

#define SPARK_COLOR vec3(1.0, 0.8, 0.8) * 1.5
#define BLOOM_COLOR vec3(1.0, 0.8, 0.8) * 0.8
#define SMOKE_COLOR vec3(1.0, 0.8, 0.8) * 0.8

#define SIZE_MOD 1.05
#define ALPHA_MOD 0.9
#define LAYERS_COUNT 15

vec2 fixUV(vec2 uv)
{
    return (2. * uv - iResolution.xy) / iResolution.x;
}

float random_1d(float p)
{
    return abs(fract(982164.87415 * sin(p * 167.547 + 9184.517)));
}

float random(vec2 pos)
{
    vec2 p2 = fract(pos * 10.1321513) * 95.1876653;
    return fract((p2.x + p2.y) * p2.x * p2.y);
}

vec3 noise(vec2 pos)
{
    vec2 i = floor(pos);
    vec2 f = fract(pos);
    vec2 u = f * f * (3.0 - 2.0 * f);
    vec2 du = 6. * u * (1. - u);

    float a = random(i);
    float b = random(i + vec2(1.0, 0.0));
    float c = random(i + vec2(0.0, 1.0));
    float d = random(i + vec2(1.0, 1.0));

    float k0 = a;
    float k1 = b - a;
    float k2 = c - a;
    float k3 = a - b - c + d;

    return vec3(k0 + k1 * u.x + k2 * u.y + k3 * u.x * u.y,
                du * (vec2(k1, k2) + k3 * u.yx));
}

mat2 rotate2D = mat2(0.6, -0.8, 0.8, 0.6);
// mat2 rotate2D=mat2(0.69465837,-0.71934,0.71934,0.69465837);

float ground(vec2 x)
{
    vec2 p = 0.003 * x;
    float a = 0.;
    float b = 1.;
    vec2 d = vec2(0);

    for (int i = 0; i < 8; i++)
    {
        vec3 n = noise(p);
        d += n.yz;
        a += b * n.x / (1. + dot(d, d));
        p = rotate2D * p * 2.;
        b *= 0.5;
    }

    return 120. * a;
}

float groundH(vec2 x)
{
    vec2 p = 0.003 * x;
    float a = 0.;
    float b = 1.;
    vec2 d = vec2(0);

    for (int i = 0; i < 12; i++)
    {
        vec3 n = noise(p);
        d += n.yz;
        a += b * n.x / (1. + dot(d, d));
        p = rotate2D * p * 2.;
        b *= 0.5;
    }

    return 120. * a;
}

float groundL(vec2 x)
{
    vec2 p = 0.003 * x;
    float a = 0.;
    float b = 1.;
    vec2 d = vec2(0);

    for (int i = 0; i < 3; i++)
    {
        vec3 n = noise(p);
        d += n.yz;
        a += b * n.x / (1. + dot(d, d));
        p = rotate2D * p * 2.;
        b *= 0.5;
    }

    return 120. * a;
}

// 并集
vec2 OpU(in vec2 sdf1, in vec2 sdf2)
{
    if (sdf1.x < sdf2.x)
        return sdf1;
    else
        return sdf2;
}

/*-------------------- sdf ----------------------------*/
// 山体sdf
float sdfMountain(vec3 p)
{
    return (p.y - ground(p.xz));
}

// 球sdf
float sdfSphere(in vec3 p, float r)
{
    return length(p) - r;
}

// 星星 star
float sdfSphere1(in vec3 p, float r)
{
    float timeFactor = abs(fract(iTime) - 0.5);
    float zFactor = (abs(fract(p.z * 0.3) - 0.5) * 4. * timeFactor);
    float powFactor = pow((-322.3 - p.z) / 4., 1.0);

    p.x += 0.012 * powFactor * sin(zFactor) + 0.2;
    p.y += 0.008 * powFactor * sin(zFactor);

    return length(p) - r;
}

// 圆柱sdf
float sdfCappedCylinder(vec3 p, float h, float r)
{
    vec2 d = abs(vec2(length(p.xz), p.y)) - vec2(r, h);
    return min(max(d.x, d.y), 0.0) + length(max(d, 0.0));
}

// 旗面sdf
float sdBox(vec3 p, vec3 b)
{
    float timeFactor = abs(fract(iTime) - 0.5);
    float zFactor = (abs(fract(p.z * 0.3) - 0.5) * 4. * timeFactor);
    float powFactor = pow((-322.3 - p.z) / 4., 1.0);

    p.x += 0.012 * powFactor * sin(zFactor);
    p.y += 0.008 * powFactor * sin(zFactor);

    vec3 q = abs(p) - b;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}

// 国旗sdf
vec2 flag(vec3 p)
{
    vec2 d = vec2(sdfCappedCylinder(p + vec3(-48, -95, -322), 8.0, 0.3), TYPE_qigan); // 旗杆

    d = OpU(d, vec2(sdfSphere(p + vec3(-48, -103, -322), 0.5), TYPE_qiu)); // 旗杆顶球

    d = OpU(d, vec2(sdBox(p + vec3(-48, -100.5, -326.3), vec3(0.15, 2.5, 4.0)), TYPE_hongqi)); // 红旗

    vec3 starBasePos = p + vec3(-47.5, -101.7, -324);
    float starSizes[5] = float[](0.35, 0.15, 0.15, 0.15, 0.15);
    vec3 starOffsets[5] = vec3[](vec3(0, 0, 0), vec3(0, -0.5, -0.9), vec3(0, 0, -1.3), vec3(0, 0.5, -1.3), vec3(0, 1.0, -0.9));

    for (int i = 0; i < 5; i++)
    { // 星星
        d = OpU(d, vec2(sdfSphere1(starBasePos + starOffsets[i], starSizes[i]), TYPE_xingxing));
    }

    return d;
}

// 火箭圆柱sdf
float sdfCappedCylinder_rocket(vec3 p, float h, float r)
{
    p.y -= 2. * pow(iTime + 1., 1.2);
    vec2 d = abs(vec2(length(p.xz), p.y)) - vec2(r, h);
    return min(max(d.x, d.y), 0.0) + length(max(d, 0.0));
}

// 火箭圆锥sdf
float sdCappedCone(vec3 p, float h, float r1, float r2)
{
    p.y -= 2. * pow(iTime + 1., 1.2);
    vec2 q = vec2(length(p.xz), p.y);
    vec2 k1 = vec2(r2, h);
    vec2 k2 = vec2(r2 - r1, 2.0 * h);
    vec2 ca = vec2(q.x - min(q.x, (q.y < 0.0) ? r1 : r2), abs(q.y) - h);
    vec2 cb = q - k1 + k2 * clamp(dot(k1 - q, k2) / dot(k2, k2), 0.0, 1.0);
    float s = (cb.x < 0.0 && ca.y < 0.0) ? -1.0 : 1.0;
    return s * sqrt(min(dot(ca, ca), dot(cb, cb)));
}

// 旗面sdf
float sdBox_rocket(vec3 p, vec3 b)
{
    p.y -= 2. * pow(iTime + 1., 1.2);
    vec3 q = abs(p) - b;
    return length(max(q, 0.0)) + min(max(q.x, max(q.y, q.z)), 0.0);
}

vec2 rocket(vec3 p, vec3 offset)
{
    vec3 pOffset = p + offset;
    vec2 d = vec2(sdfCappedCylinder_rocket(pOffset, 40., 7.), TYPE_rocket); // 主舰体

    vec3 redFlagOffset = vec3(10., -5., 0.);
    vec3 mainConeOffset = vec3(0., -45., 0.);
    vec3 sideBody1Offset = vec3(-7, 30., -7.);
    vec3 sideCone1Offset = vec3(-7, 5., -7.);
    vec3 sideBody2Offset = vec3(7, 30., 7.);
    vec3 sideCone2Offset = vec3(7, 5., 7.);
    vec3 flame1Offset = vec3(0., 55., 0.);
    vec3 flame2Offset = vec3(-7., 59., -7.);
    vec3 flame3Offset = vec3(7., 59., 7.);

    d = OpU(d, vec2(sdBox_rocket(pOffset + redFlagOffset, vec3(0.15, 2.5, 4.)), TYPE_hongqi));   // 红旗
    d = OpU(d, vec2(sdCappedCone(pOffset + mainConeOffset, 10., 7., 0.01), TYPE_rocket));        // 主箭头
    d = OpU(d, vec2(sdfCappedCylinder_rocket(pOffset + sideBody1Offset, 20., 7.), TYPE_rocket)); // 副舰体1
    d = OpU(d, vec2(sdCappedCone(pOffset + sideCone1Offset, 10., 4., 0.01), TYPE_rocket));       // 副箭头1
    d = OpU(d, vec2(sdfCappedCylinder_rocket(pOffset + sideBody2Offset, 20., 7.), TYPE_rocket)); // 副舰体2
    d = OpU(d, vec2(sdCappedCone(pOffset + sideCone2Offset, 10., 4., 0.01), TYPE_rocket));       // 副箭头2
    d = OpU(d, vec2(sdfCappedCylinder_rocket(pOffset + flame1Offset, 16., 5.), TYPE_fire));      // 火焰1
    d = OpU(d, vec2(sdfCappedCylinder_rocket(pOffset + flame2Offset, 6., 3.5), TYPE_fire));      // 火焰2
    d = OpU(d, vec2(sdfCappedCylinder_rocket(pOffset + flame3Offset, 6., 3.5), TYPE_fire));      // 火焰3

    return d;
}

vec2 map(in vec3 p)
{
    // x负越大 后  y负越大 上   z负越大 右
    vec2 d = flag(p);                                               // 国旗
    d = OpU(d, rocket(p, vec3(-400., -15. - ground(p.xz), -190.))); // 火箭
    d = OpU(d, vec2(sdfMountain(p), 2.));                           // 2代表山
    return d;
}

float fbm(vec2 p)
{
    float f = 0.0;
    float fac = 0.5;
    for (int i = 0; i < 4; i++)
    {
        f += fac * noise(p).x;
        p = rotate2D * p * 2.0;
        fac *= 0.5;
    }
    return f;
}

vec2 rayMarch(vec3 ro, vec3 rd, float tmin, float tmax)
{
    float t = tmin;
    float mytype = 3.0;
    for (int i = 0; i < MAX_ITER; i++)
    {
        vec3 p = ro + t * rd;
        float d = map(p).x;
        float retype = map(p).y;
        if (abs(d) < EPSILON * t || t > tmax)
        {
            mytype = retype;
            break;
        }
        t += 0.3 * d;
    }
    return vec2(t, mytype);
}

float softShadow(in vec3 ro, in vec3 rd)
{ // 软阴影： ro阴影计算点， rd光源方向 ，dis距离
    // float minStep = clamp(0.01 * dis, 0.5, 50.0); //最小步长
    float res = 1.0;
    float t = 0.001;
    for (int i = 0; i < 80; i++)
    {
        vec3 p = ro + t * rd;
        // float h = p.y - ground(p.xz);
        float h = map(p).x;
        res = min(res, 8.0 * h / t);
        // t += max(minStep, h);
        t += h;
        if (res < 0.001 || p.y > 200.0)
            break;
    }
    return clamp(res, 0.0, 1.0);
}

vec3 calcNorm_obj(vec3 p, float t)
{
    float h = 0.0027 * t;
    vec2 k = vec2(1, -1);
    return normalize(k.xyy * map(p + k.xyy * h).x +
                     k.yyx * map(p + k.yyx * h).x +
                     k.yxy * map(p + k.yxy * h).x +
                     k.xxx * map(p + k.xxx * h).x);
}

vec3 calcNorm(vec3 p, float t)
{
    vec2 epsilon = vec2(0.0027 * t, 0);
    return normalize(vec3(groundH(p.xz - epsilon.xy) - groundH(p.xz + epsilon.xy),
                          2.0 * epsilon.x,
                          ground(p.xz - epsilon.yx) - ground(p.xz + epsilon.yx)));
}

mat3 setCamera(vec3 ro, vec3 target, float cr)
{
    vec3 z = normalize(target - ro);
    vec3 up = normalize(vec3(sin(cr), cos(cr), 0));
    vec3 x = cross(z, up);
    vec3 y = cross(x, z);
    return mat3(x, y, z);
}

vec3 linear_lighting_common(vec3 p, vec3 light, vec3 norm, vec3 difColor, vec3 ambColor, vec3 bacColor)
{
    vec3 lin = vec3(0.0);
    float dif = clamp(dot(light, norm), 0.0, 1.0);
    float sh = softShadow(p + 0.01 * light, light);
    float amb = clamp(0.5 + 0.5 * norm.y, 0.0, 1.0);
    float bac = clamp(0.2 + 0.8 * dot(vec3(-light.x, 0.0, light.z), norm), 0.0, 1.0);
    lin += dif * difColor * vec3(sh, sh * sh * 0.5 + 0.5 * sh, sh * sh * 0.8 + 0.2 * sh);
    lin += amb * ambColor;
    lin += bac * bacColor;
    return lin;
}

vec3 linear_lighting_moon(vec3 p, vec3 moonlight, vec3 norm)
{
    return linear_lighting_common(p, moonlight, norm,
                                  vec3(1.1, 1.2, 1.02) * 1.34,
                                  vec3(54. / 255., 81. / 255., 135. / 255.) * 1.3,
                                  vec3(87. / 255., 104. / 255., 124. / 255.));
}

vec3 linear_lighting_sun(vec3 p, vec3 sunlight, vec3 norm)
{
    return linear_lighting_common(p, sunlight, norm,
                                  vec3(8.0, 5.0, 3.0) * 1.8,
                                  vec3(0.4, 0.6, 1.0) * 1.2,
                                  vec3(0.4, 0.5, 0.6));
}

vec3 calculate_lighting(vec3 p, vec3 rd, vec3 norm, vec3 base_col, vec3 sunlight, vec3 moonlight, float lightscale, float moonscale, float t)
{
    vec3 lin = linear_lighting_sun(p, sunlight, norm);
    vec3 lin_moon = linear_lighting_moon(p, moonlight, norm);
    vec3 col = base_col * (lin * min(1., (lightscale + 0.2)) + lin_moon * min(1., (moonscale + 0.2)));
    col = mix(col, 0.65 * vec3(0.5, 0.75, 1.0) * min(1., (lightscale + 0.2)), 1. - exp(-pow(0.003 * t, 1.5)));
    return col;
}

vec3 render(vec2 uv)
{
    vec3 col = vec3(0);
    /////////////////////////////////////////   camera  ///////////////////////////////////////////////////////////
    //修改此处选择是否让摄像机移动
    float an =  iTime * 0.035;
    //float an = 0.06;
    float r = 310.;
    vec2 pos2d = vec2(r * sin(an) - 10., r * cos(an));
    float h = groundL(pos2d) + 25.; // 保持在高于山体25的方向上摄像
    vec3 ro = vec3(pos2d.x, h, pos2d.y);
    vec3 target = vec3(r * sin(an + 0.01), h, r * cos(an + 0.01));
    mat3 cam = setCamera(ro, target, 0.);

    float fl = 1.;
    vec3 rd = normalize(cam * vec3(uv, fl));

    float tmin = 0.001;
    float tmax = 1000.;
    float maxh = 300.;

    float tp = (maxh - ro.y) / rd.y;
    if (tp > 0.)
    {
        if (maxh > ro.y)
            tmax = min(tmax, tp);
        else
            tmin = max(tmin, tp);
    }
    vec2 t = rayMarch(ro, rd, tmin, tmax);

    // vec3 fire = normalize(vec3(2., -1., -2.) + vec3(0., 2. * pow(iTime + 1., 1.2), 0.)); //火焰位置 p.y -=  2. * pow(iTime + 1., 1.2);
    // float firedot =  clamp(dot(rd, fire), 0., 1.);

    vec3 sunlight = normalize(vec3(30., 30. * cos(0.3 * iTime), 30. * sin(0.3 * iTime))); // 太阳位置
    float lightscale = (sunlight.y + 0.5774) / 1.1548;
    float sundot = clamp(dot(rd, sunlight), 0., 1.); // 太阳系数，与太阳越近越亮

    vec3 moonlight = normalize(vec3(30., -30. * cos(0.3 * iTime), -30. * sin(0.3 * iTime))); // 月亮位置
    float moonscale = (moonlight.y + 0.5774) / 1.1548;
    float moondot = clamp(dot(rd, moonlight), 0., 1.); // 月亮系数，与月亮越近越亮

    // 夜空星星
    vec3 starlight[20];
    float stardot[20];
    float itime[20];
    starlight[0] = normalize(vec3(0.8, 0.4, -0.2));
    stardot[0] = clamp(dot(rd, starlight[0]), 0., 2.);
    starlight[1] = normalize(vec3(3., 1.1, -1.));
    stardot[1] = clamp(dot(rd, starlight[1]), 0., 2.);
    starlight[2] = normalize(vec3(7., 1., -6.));
    stardot[2] = clamp(dot(rd, starlight[2]), 0., 2.);
    starlight[3] = normalize(vec3(5., 1.5, 5.));
    stardot[3] = clamp(dot(rd, starlight[3]), 0., 2.);
    starlight[4] = normalize(vec3(5., 1.2, 3.));
    stardot[4] = clamp(dot(rd, starlight[4]), 0., 2.);
    itime[0] = iTime * 0.1;
    itime[1] = iTime * 1.2;
    itime[2] = iTime * 0.5;
    itime[3] = iTime * 2.1;
    itime[4] = iTime * 1.8;
    // for(int i=5; i<10; i++){
    //     float randx = random_1d(starlight[i-5].x);
    //     float randy = random_1d(starlight[i-5].y);
    //     float randz = random_1d(starlight[i-5].z);
    //     starlight[i] = normalize(vec3(fract(sin(randx)) * 19489.21, fract(cos(randy)) * 7718.16, fract(sin(randz)) * 476164.54479));
    //     stardot[i] = clamp(dot(rd, starlight[i]), 0., 2.);
    //}

    if (t.x > tmax)
    {
        // sky
        col = vec3(0.3 * min(1., (lightscale + 0.3)), 0.5 * min(1., (lightscale + 0.1)), 0.85 * min(1., (lightscale + 0.05))) - rd.y * rd.y * 0.5; // 蓝，越往上更蓝 往下变浅
        col = mix(col, 0.85 * vec3(0.7, 0.75, 0.85) * min(1., (lightscale + 0.1)), pow(1.0 - max(rd.y, 0.0), 4.0));                                // 下半部分偏向白色
        // col *= min(1., (lightscale + 0.2));

        // sun
        col *= (1. - pow(sundot, 64.0));
        col += 0.4 * vec3(0.9, 0.9, 0.7 * min(1., (lightscale + 0.1))) * pow(sundot, 64.0) * min(1., (lightscale + 0.1)); // 光晕
        col += 0.4 * vec3(1., 0.8, 0.7 * min(1., (lightscale + 0.1))) * pow(sundot, 64.0) * min(1., (lightscale + 0.1));  // 太阳高光
        col += 0.4 * vec3(1., 0.7, 0.5 * min(1., (lightscale + 0.1))) * pow(sundot, 512.0) * min(1., (lightscale + 0.1));
        col += 0.5 * vec3(1, 0.7, 0.5 * min(1., (lightscale + 0.1))) * pow(sundot, 1024.0) * min(1., (lightscale + 0.1));
        float duskscale = -8.163265306122 * pow(lightscale - 0.6, 2.) + 1.;
        if (lightscale >= 0.25 && lightscale <= 0.95)
        {
            col += 0.75 * vec3(1.0, 0.7, 0.3) * pow(sundot, 8.) * duskscale;
            col += 0.75 * vec3(1.0, 0.7, 0.3) * pow(sundot, 8.) * duskscale;
        }

        // moon
        if (lightscale < 0.6)
        {
            col *= (1. - pow(moondot, 1024.0));
            col += 1. * vec3(0.9, 0.8, 0.5) * pow(clamp(moondot + 0.006, 0., 1.), 1024.0);
        }

        // stars
        if (lightscale < 0.3)
        {
            // 归一化
            float starscale = pow(((0.3 - lightscale) / 0.3), 2.) + 0.01;
            // col += 2. * vec3(255./255., 255./255., 245./255.) * pow(stardot, 4096.0) * starscale + vec3(0.9, 0.9, 0.9) * 0.005;
            for (int i = 0; i < 5; i++)
            {
                col += abs(sin(2. * itime[i])) * 1.1 * vec3(245. / 255., 250. / 255., 245. / 255.) * pow(clamp(stardot[i] - 0.00001, 0., 1.), 60000.0) * starscale + vec3(.8, .8, .8) * 0.0015;
                //+ vec3(.9, .9, .9) * 0.003 保证星星消失时不至于全黑 加多了在出现和最终消失时会闪烁 加少了消失时有明显黑斑
            }
        }

        // clouds
        vec2 skyPos = ro.xz + rd.xz * (120. - ro.y) / rd.y + iTime * 5.;
        col = mix(col, vec3(1.0, 0.95, 1.0) * min(1., (lightscale + 0.2)), 0.75 * smoothstep(0.4, 0.8, fbm(0.01 * skyPos)));
    }
    else
    {
        vec3 p = ro + t.x * rd;
        vec3 n = calcNorm_obj(p, t.x);

        if (t.y == TYPE_qigan)
        {
            // 旗杆
            col = calculate_lighting(p, rd, n, vec3(128. / 255., 128. / 255., 128. / 255.), sunlight, moonlight, lightscale, moonscale, t.x);
        }
        else if (t.y == TYPE_qiu)
        {
            // 杆顶
            col = calculate_lighting(p, rd, n, vec3(0.67, 0.719, 0.8104), sunlight, moonlight, lightscale, moonscale, t.x);
        }
        else if (t.y == TYPE_hongqi)
        {
            // 红旗
            col = calculate_lighting(p, rd, n, vec3(1., 0., 0.), sunlight, moonlight, lightscale, moonscale, t.x);
        }
        else if (t.y == TYPE_xingxing)
        {
            // 星星
            col = calculate_lighting(p, rd, n, vec3(1., 1., 0.), sunlight, moonlight, lightscale, moonscale, t.x);
        }
        else if (t.y == TYPE_rocket)
        {
            // 火箭
            col = calculate_lighting(p, rd, n, vec3(0.7, 0.6, 0.65), sunlight, moonlight, lightscale, moonscale, t.x);
        }
        else if (t.y == TYPE_fire)
        {
            vec3 p = ro + t.x * rd;
            float firedot = clamp(dot(rd, p), 0., 1.);
            col += 0.4 * vec3(0.8, 0.7, 0.1) * pow(firedot, 32.0); // 光晕
            col += 0.4 * vec3(1., 0.2, 0.1) * pow(firedot, 64.0);  // 光晕
            col += 0.4 * vec3(1., 0.2, 0.1) * pow(firedot, 512.0); // 光晕
            col += 0.75 * vec3(1.0, 0.7, 0.3) * pow(firedot, 8.0);
            col += 0.75 * vec3(1.0, 0.7, 0.3) * pow(firedot, 8.0);
            // col += 1. * vec3(1.0, 0.7, 0.3) * pow(firedot, 32.0);
        }
        else
        {
            vec3 p = ro + t.x * rd;
            vec3 n = calcNorm(p, t.x);                                                                 // 计算法向量
            vec3 difColor = mix(vec3(0.08, 0.05, 0.03), vec3(0.10, 0.09, 0.08), noise(p.xz * 0.02).x); // 随机深浅色变换
            float r = noise(p.xz * 0.1).x;                                                             // 随机数

            // 岩石
            col = (r * 0.25 + 0.75) * 0.9 * difColor;                                                // 基础岩石颜色，0.75-1之间的随机深浅变换
            col = mix(col, vec3(0.065, 0.06, 0.03) * (0.5 + 0.5 * r), smoothstep(0.7, 0.9, n.y));    // 岩石顶部平缓地方着色
            col = mix(col, vec3(0.04, 0.045, 0.015) * (0.25 + 0.75 * r), smoothstep(0.95, 1., n.y)); // 草地
            // col = mix(col, vec3(2.85/255., 1.02/255., 1.78/255.) * (0.5 + 0.5 * (r+1.)), smoothstep(0.3,0.5, n.y)); //花
            col *= 0.1 + 1.8 * sqrt(fbm(p.xz * 0.04) * fbm(p.xz * 0.005)); // 深浅变化

            // Snow
            float h = smoothstep(35.0, 80.0, p.y + 35.0 * fbm(0.01 * p.xz));
            float e = smoothstep(1.0 - 0.5 * h, 1.0 - 0.1 * h, n.y);
            float o = 0.3 + 0.7 * smoothstep(0.0, 0.1, n.y + h * h);
            float s = h * e * o;
            col = mix(col, 0.29 * vec3(0.62, 0.65, 0.7), smoothstep(0.1, 0.9, s));

            // Linear Lighting
            vec3 lin = vec3(0.);
            float dif = clamp(dot(sunlight, n), 0., 1.);           // 漫反射
            float sh = softShadow(p + 0.01 * sunlight, sunlight);  // 软阴影
            lin = linear_lighting_sun(p, sunlight, n);             // 太阳光照计算
            vec3 lin_moon = linear_lighting_moon(p, moonlight, n); // 月亮光照
            col *= lin * min(1., (lightscale + 0.2)) + lin_moon * min(1., (moonscale + 0.2));

            // half-angle
            vec3 hal = normalize(sunlight - rd);

            col += (0.7 + 0.3 * s) * (0.04 + 0.96 * pow(clamp(1.0 + dot(hal, rd), 0.0, 1.0), 5.0)) *
                   vec3(7.0, 5.0, 3.0) * sh * dif *
                   pow(clamp(dot(n, hal), 0.0, 1.0), 16.0) * min(1., (lightscale + 0.2)); // 镜面光

            col = mix(col, 0.65 * vec3(0.5, 0.75, 1.0) * min(1., lightscale - 0.1) + 0.5 * vec3(60. / 255., 70. / 255., 80. / 255.) * min(0.85, moonscale),
                      1. - exp(-pow(0.003 * t.x, 1.5))); // 山体雾气
        }
    }

    return col;
}

float hash1_2(in vec2 x)
{
    return fract(sin(dot(x, vec2(52.127, 61.2871))) * 521.582);
}

vec2 hash2_2(in vec2 x)
{
    return fract(sin(x * mat2x2(20.52, 24.1994, 70.291, 80.171)) * 492.194);
}

// Simple interpolated noise
vec2 noise2_2(vec2 uv)
{
    // vec2 f = fract(uv);
    vec2 f = smoothstep(0.0, 1.0, fract(uv));

    vec2 uv00 = floor(uv);
    vec2 uv01 = uv00 + vec2(0, 1);
    vec2 uv10 = uv00 + vec2(1, 0);
    vec2 uv11 = uv00 + 1.0;
    vec2 v00 = hash2_2(uv00);
    vec2 v01 = hash2_2(uv01);
    vec2 v10 = hash2_2(uv10);
    vec2 v11 = hash2_2(uv11);

    vec2 v0 = mix(v00, v01, f.y);
    vec2 v1 = mix(v10, v11, f.y);
    vec2 v = mix(v0, v1, f.x);

    return v;
}

// Simple interpolated noise
float noise1_2(in vec2 uv)
{
    vec2 f = fract(uv);
    // vec2 f = smoothstep(0.0, 1.0, fract(uv));

    vec2 uv00 = floor(uv);
    vec2 uv01 = uv00 + vec2(0, 1);
    vec2 uv10 = uv00 + vec2(1, 0);
    vec2 uv11 = uv00 + 1.0;

    float v00 = hash1_2(uv00);
    float v01 = hash1_2(uv01);
    float v10 = hash1_2(uv10);
    float v11 = hash1_2(uv11);

    float v0 = mix(v00, v01, f.y);
    float v1 = mix(v10, v11, f.y);
    float v = mix(v0, v1, f.x);

    return v;
}

float layeredNoise1_2(in vec2 uv, in float sizeMod, in float alphaMod, in int layers, in float animation)
{
    float noise = 0.0;
    float alpha = 1.0;
    float size = 1.0;
    vec2 offset;
    for (int i = 0; i < layers; i++)
    {
        offset += hash2_2(vec2(alpha, size)) * 10.0;

        // Adding noise with movement
        noise += noise1_2(uv * size + iTime * animation * 8.0 * MOVEMENT_DIRECTION * MOVEMENT_SPEED + offset) * alpha;
        alpha *= alphaMod;
        size *= sizeMod;
    }

    noise *= (1.0 - alphaMod) / (1.0 - pow(alphaMod, float(layers)));
    return noise;
}

// Rotates point around 0,0
vec2 rotate(in vec2 point, in float deg)
{
    float s = sin(deg);
    float c = cos(deg);
    return mat2x2(s, c, -c, s) * point;
}

// Cell center from point on the grid
vec2 voronoiPointFromRoot(in vec2 root, in float deg)
{
    vec2 point = hash2_2(root) - 0.5;
    float s = sin(deg);
    float c = cos(deg);
    point = mat2x2(s, c, -c, s) * point * 0.66;
    point += root + 0.5;
    return point;
}

// Voronoi cell point rotation degrees
float degFromRootUV(in vec2 uv)
{
    return iTime * ANIMATION_SPEED * (hash1_2(uv) - 0.5) * 2.0;
}

vec2 randomAround2_2(in vec2 point, in vec2 range, in vec2 uv)
{
    return point + (hash2_2(uv) - 0.5) * range;
}

vec3 fireParticles(in vec2 uv, in vec2 originalUV)
{
    vec3 particles = vec3(0.0);
    vec2 rootUV = floor(uv);
    float deg = degFromRootUV(rootUV);
    vec2 pointUV = voronoiPointFromRoot(rootUV, deg);
    float dist = 2.0;
    float distBloom = 0.0;

    // UV manipulation for the faster particle movement
    vec2 tempUV = uv + (noise2_2(uv * 2.0) - 0.5) * 0.1;
    tempUV += -(noise2_2(uv * 3.0 + iTime) - 0.5) * 0.07;

    // Sparks sdf
    dist = length(rotate(tempUV - pointUV, 0.7) * randomAround2_2(PARTICLE_SCALE, PARTICLE_SCALE_VAR, rootUV));

    // Bloom sdf
    distBloom = length(rotate(tempUV - pointUV, 0.7) * randomAround2_2(PARTICLE_BLOOM_SCALE, PARTICLE_BLOOM_SCALE_VAR, rootUV));

    // Add sparks
    particles += (1.0 - smoothstep(PARTICLE_SIZE * 0.6, PARTICLE_SIZE * 3.0, dist)) * SPARK_COLOR;

    // Add bloom
    particles += pow((1.0 - smoothstep(0.0, PARTICLE_SIZE * 6.0, distBloom)) * 1.0, 3.0) * BLOOM_COLOR;

    // Upper disappear curve randomization
    float border = (hash1_2(rootUV) - 0.5) * 2.0;
    float disappear = 1.0 - smoothstep(border, border + 0.5, originalUV.y);

    // Lower appear curve randomization
    border = (hash1_2(rootUV + 0.214) - 1.8) * 0.7;
    float appear = smoothstep(border, border + 0.4, originalUV.y);

    return particles * disappear * appear;
}

// Layering particles to imitate 3D view
vec3 layeredParticles(in vec2 uv, in float sizeMod, in float alphaMod, in int layers, in float smoke)
{
    vec3 particles = vec3(0);
    float size = 1.0;
    float alpha = 1.0;
    vec2 offset = vec2(0.0);
    vec2 noiseOffset;
    vec2 bokehUV;

    for (int i = 0; i < layers; i++)
    {
        // Particle noise movement
        noiseOffset = (noise2_2(uv * size * 2.0 + 0.5) - 0.5) * 0.15;

        // UV with applied movement
        bokehUV = (uv * size + iTime * MOVEMENT_DIRECTION * MOVEMENT_SPEED) + offset + noiseOffset;

        // Adding particles								if there is more smoke, remove smaller particles
        particles += fireParticles(bokehUV, uv) * alpha * (1.0 - smoothstep(0.0, 1.0, smoke) * (float(i) / float(layers)));

        // Moving uv origin to avoid generating the same particles
        offset += hash2_2(vec2(alpha, alpha)) * 10.0;

        alpha *= alphaMod;
        size *= sizeMod;
    }

    return particles;
}

void mainImage(out vec4 fragColor, in vec2 fragCoord)
{
    vec2 uv = fixUV(fragCoord);
    // 大部分渲染都在render函数中进行
    vec3 col = render(uv);

    // 下面实现的是屏幕雪花特效，搬运和修改自(https://www.shadertoy.com/view/wl2Gzc)的火焰特效，可注释掉，几乎不会影响观感
    // uv = (1.2 * fragCoord - 0.6 * iResolution.xy) / iResolution.x;

    // float vignette = 1.0 - smoothstep(0.4, 1.4, length(uv + vec2(0.0, 0.3)));

    // uv *= 1.8;

    // float smokeIntensity = layeredNoise1_2(uv * 10.0 + iTime * 4.0 * MOVEMENT_DIRECTION * MOVEMENT_SPEED, 1.7, 0.7, 6, 0.2);
    // smokeIntensity *= pow(1.0 - smoothstep(-1.0, 1.6, uv.y), 2.0);
    // vec3 smoke = smokeIntensity * SMOKE_COLOR * 0.8 * vignette;

    // //Cutting holes in smoke
    // smoke *= pow(layeredNoise1_2(uv * 4.0 + iTime * 0.5 * MOVEMENT_DIRECTION * MOVEMENT_SPEED, 1.8, 0.5, 3, 0.2), 2.0) * 1.5;

    // vec3 particles = layeredParticles(uv, SIZE_MOD, ALPHA_MOD, LAYERS_COUNT, smokeIntensity);

    // vec3 color = particles + smoke + SMOKE_COLOR * 0.02;
    // color *= vignette;

    // color = smoothstep(-0.08, 1.0, color);

    // col += color;
    // 雪花特效到此实现完毕

    fragColor = vec4(1. - exp(-col * 2.), 1.);
}