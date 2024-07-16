#include "tg_common.glh" 

#ifdef _FRAGMENT_

//-----------------------------------------------------------------------------

float VolcanoNoiseFixed(vec3 point, float globalLand, float localLand) {
    noiseLacunarity = 2.218281828459;
    noiseH = 0.5;
    noiseOffset = 0.8;

    float frequency = 150.0 * volcanoFreq;
    float density = volcanoDensity;
    float size = volcanoRadius;
    float newLand = localLand;
    float globLand = globalLand - 1.0;
    float amplitude = 2.0 * volcanoMagn;
    vec2 cell;
    vec3 cellCenter = vec3(0.0);
    vec3 rotVec = normalize(Randomize);
    vec3 binormal = normalize(vec3(-point.z, 0.0, point.x)); // = normalize(cross(point, vec3(0, 1, 0)));
    float distFreq = 18.361 * volcanoFreq;
    float distMagn = 0.003;

    for(int i = 0; i < volcanoOctaves; i++) {
        noiseOctaves = 4;
        vec3 p = point + distMagn * Fbm3D(point * distFreq);

        cell = inverseSF(p, frequency, cellCenter);

        float h = hash1(cell.x);
        float r = 40.0 * cell.y;
        if((h < density) && (r < 1.0)) {
            float rnd = 48.3 * dot(cellCenter, Randomize);
            vec3 cen = normalize(cellCenter - p);
            float a = dot(p, cross(cen, binormal));
            float b = dot(cen, binormal);
            float fi1 = atan(a, b) / pi;
            float fi2 = atan(-a, -b) / pi;

            float volcano = globLand + amplitude * VolcanoHeightFunc(r, fi1, fi2, rnd, size);
            newLand = softPolyMax(newLand, volcano, 0.3);
        }

        if(volcanoOctaves > 1) {
            point = Rotate(pi2 * hash1(float(i)), rotVec, point);
            frequency *= 2.0;
            size *= 0.5;
            distFreq *= 2.0;
            distMagn *= 0.5;
        }
    }

    return newLand;
}

//-----------------------------------------------------------------------------

//	RODRIGO - SMALL CHANGES TO RIVERS AND RIFTS
// Modified Rodrigo's rivers

void _PseudoRivers(vec3 point, float global, float damping, inout float height) {
    noiseOctaves = 8.0;
    noiseH = 1.0;
    noiseLacunarity = 2.1;

    vec3 p = point * 2.0 * mainFreq + Randomize;
    vec3 distort = 0.325 * Fbm3D(p * riversSin);
    distort = 0.65 * Fbm3D(p * riversSin) +
        0.03 * Fbm3D(p * riversSin * 5.0) + 0.01 * RidgedMultifractalErodedDetail(point * 0.3 * (canyonsFreq + 1000) * (0.5 * (1 / montesSpiky + 1)) + Randomize, 8.0, erosion, 2);

    vec2 cell = 2.5 * Cell3Noise2(riversFreq * p + 0.5 * distort);

    float valleys = 1.0 - (saturate(0.36 * abs(cell.y - cell.x) * riversMagn));
    valleys = smoothstep(0.0, 1.0, valleys) * damping;
    height = mix(height, seaLevel + 0.03, valleys);

    float rivers = 1.0 - (saturate(6.5 * abs(cell.y - cell.x) * riversMagn));
    rivers = smoothstep(0.0, 1.0, rivers) * damping;
    height = mix(height, seaLevel + 0.015, rivers);
}

//-----------------------------------------------------------------------------
// Modified Rodrigo's rifts

void _Rifts(vec3 point, float damping, inout float height) {
    float riftsBottom = seaLevel;

    noiseOctaves = 6.6;
    noiseH = 1.0;
    noiseLacunarity = 4.0;
    noiseOffset = 0.95;

    // 2 slightly different octaves to make ridges inside rifts
    vec3 p = point * 0.12;
    float rifts = 0.0;
    for(int i = 0; i < 2; i++) {
        vec3 distort = 0.5 * Fbm3D(p * riftsSin) + 0.1 * Fbm3D(p * 3 * riftsSin);
        ;
        vec2 cell = Cell3Noise2(riftsFreq * p + distort);
        float width = 0.8 * riftsMagn * abs(cell.y - cell.x);
        rifts = softExpMaxMin(rifts, 1.0 - 2.75 * width, 32.0);
        p *= 1.02;
    }

    float riftsModulate = smoothstep(-0.1, 0.2, Fbm(point * 2.3 + Randomize));
    rifts = smoothstep(0.0, 1.0, rifts * riftsModulate) * damping;

    height = mix(height, riftsBottom, rifts);

    // Slope modulation
    if(rifts > 0.0) {
        float slope = smoothstep(0.1, 0.9, 1.0 - 2.0 * abs(rifts * 0.35 - 0.5));
        float slopeMod = 0.5 * slope * RidgedMultifractalErodedDetail(point * 5.0 * canyonsFreq + Randomize, 8.0, erosion, 8.0);
        slopeMod *= 0.05 * riftsModulate;
        height = softExpMaxMin(height - slopeMod, riftsBottom, 32.0);
    }
}

//-----------------------------------------------------------------------------

void HeightMapTerra(vec3 point, out vec4 HeightBiomeMap) {
    // Assign a climate type
    noiseOctaves = (oceanType == 1.0) ? 5.0 : 12.0; // Reduce terrain octaves on oceanic planets (oceanType == 1)
    noiseH = 0.5;
    noiseLacunarity = 2.218281828459;
    noiseOffset = 0.8;
    float climate, latitude;
    if(tidalLock <= 0.0) {
        latitude = abs(point.y);
        latitude += 0.15 * (Fbm(point * 0.7 + Randomize) - 1.0);
        latitude = saturate(latitude);
        if(latitude < latTropic - tropicWidth)
            climate = mix(climateTropic, climateEquator, (latTropic - tropicWidth - latitude) / latTropic);
        else if(latitude > latTropic + tropicWidth)
            climate = mix(climateTropic, climatePole, (latitude - latTropic - tropicWidth) / (1.0 - latTropic));
        else
            climate = climateTropic;
    } else {
        latitude = 1.0 - point.x;
        latitude += 0.15 * (Fbm(point * 0.7 + Randomize) - 1.0);
        climate = mix(climateTropic, climatePole, saturate(latitude));
    }

    // Litosphere cells
    //float lithoCells = LithoCellsNoise(point, climate, 1.5);

    // Global landscape
    vec3 p = point * mainFreq + Randomize;
    noiseOctaves = 5;
    vec3 distort = 0.35 * Fbm3D(p * 0.73);
    noiseOctaves = 4;
    distort += 0.005 * (1.0 - abs(Fbm3D(p * 132.3)));
    float global = 1 - Cell3Noise(p + distort);

    // Make sea bottom more flat; shallow seas resembles those on Titan;
    // but this shrinks out continents, so value larger than 1.5 is unwanted
    global = softPolyMax(global, 0.0, 0.1);
    global = pow(global, 1.5);

    // Venus-like structure
    float venus = 0.0;

    noiseOctaves = 4;
    distort = Fbm3D(point * 0.3) * 1.5;
    noiseOctaves = 6;
    venus = Fbm((point + distort) * venusFreq) * (venusMagn + 0.3);

    global = (global + venus - seaLevel) * 0.5 + seaLevel;
    float shore = saturate(70.0 * (global - seaLevel));

    // Biome domains
    noiseOctaves = 6;
    vec3 pb = p * 2.3 + 0.5 * Fbm3D(p * 1.5);
    vec4 col;
    vec2 cell = Cell3Noise2Color(pb, col);
    float biome = col.r;
    float biomeScale = saturate(2.0 * (pow(abs(cell.y - cell.x), 0.7) - 0.05));
    float terrace = col.g;
    float terraceLayers = max(col.b * 10.0 + 3.0, 3.0);
    terraceLayers += Fbm(pb * 5.41);

    float montRange = saturate(DistNoise(point * 22.6 + Randomize, 2.5) + 0.5);
    montRange *= montRange;
    float montBiomeScale = min(pow(2.2 * biomeScale, 3.5), 1.0) * montRange;

    float inv2montesSpiky = 1.0 / (montesSpiky * montesSpiky);
    float heightD = 0.0;
    float height = 0.0;
    float landform = 0.0;
    float dist;

//	RODRIGO 

    noiseOctaves = 8;
    vec3 pp = (point + Randomize) * (0.0005 * hillsFreq / (hillsMagn * hillsMagn));

    noiseOctaves = 12.0;
    distort = Fbm3D((point + Randomize) * 0.07) * 1.5;

    noiseOctaves = 10.0;
    noiseH = 1.0;
    noiseLacunarity = 2.3;
    noiseOffset = montesSpiky;
    float rocks = -0.005 * iqTurbulence(point * 200.0, 1.0);

//small terrain elevations   
    noiseOctaves = 12.0;
    distort = Fbm3D((point + Randomize) * 0.07) * 1.5;
    noiseOctaves = 8.0;

    float fr = 0.20 * (1.5 - RidgedMultifractal(pp, 2.0)) +
        0.05 * (1.5 - RidgedMultifractal(pp * 10.0, 2.0));

    fr *= 1 - smoothstep(0.0, 0.02, seaLevel - global);

    global = mix(global, global + 0.2, fr);

//Mesas
    float zr = 1.0 + 2 * Fbm(point + distort) + 7 * (1.5 - RidgedMultifractalEroded(pp * 0.8, 8.0, erosion)) -
        6 * (1.5 - RidgedMultifractalEroded(pp * 0.1, 8.0, erosion)) - 0.01 * (1.5 - RidgedMultifractalEroded(pp * 4, 8.0, erosion));

    zr = smoothstep(0.0, 1.0, 0.2 * zr * zr);
    zr *= 1 - smoothstep(0.0, 0.02, seaLevel - global);
    zr = 0.1 * hillsFreq * smoothstep(0.0, 1.0, zr);
    global = mix(global, global + 0.0006, zr);

    noiseOctaves = 10.0;
    noiseH = 1.0;
    noiseLacunarity = 2.3;
    noiseOffset = montesSpiky;
    float rr = 0.3 * ((0.15 * iqTurbulence(point * 0.4 * montesFreq + Randomize, 0.45)) * (RidgedMultifractalDetail(point * point * montesFreq * 0.8 + venus + Randomize, 1.0, montBiomeScale)));

    rr *= 1 - smoothstep(0.0, 0.02, seaLevel - global);

    global += rr;

    if(biome < dunesFraction) {
        // Dunes
        noiseOctaves = 2.0;
        dist = dunesFreq + Fbm(p * 1.21);
        float desert = max(Fbm(p * dist), 0.0);
        float dunes = DunesNoise(point, 3);
        landform = (0.0002 * desert + dunes) * pow(biomeScale, 3);
        heightD += dunesMagn * landform;
    } else if(biome < hillsFraction) {
		// Mountains
		if (oceanType > 0)
		{
			noiseOctaves = 10.0;
			noiseH       = 1.0;
			noiseLacunarity = 2.0;
			noiseOffset  = montesSpiky * 1.2;
			height = hillsMagn * 2.4 * ((1.25 + iqTurbulence(point * 0.5 * hillsFreq * inv2montesSpiky * 1.25 + Randomize, 0.55)) * (0.05 * RidgedMultifractalErodedDetail(point * 1.0 * hillsFreq * inv2montesSpiky * 1.5 + Randomize, 1.0, erosion, montBiomeScale)));
		}
		else
		{
			noiseOctaves = 10.0;
			noiseH       = 1.0;
			noiseLacunarity = 2.0;
			noiseOffset  = montesSpiky * 1.2;
			height = hillsMagn * 7.5 * ((1.25 + iqTurbulence(point * 0.5 * (hillsFreq / 2) * inv2montesSpiky * 1.25 + Randomize, 0.55)) * (0.05 * RidgedMultifractalErodedDetail(point * 1.0 * (hillsFreq / 2) * inv2montesSpiky * 1.5 + Randomize, 1.0, erosion, montBiomeScale)));
		}
    } else if(biome < hills2Fraction) {
		// "Eroded" hills
		if (oceanType > 0)
		{
			noiseOctaves = 10.0;
			noiseH       = 1.0;
			noiseOffset  = venusFreq;
			noiseLacunarity = 2.1;
			height = (0.5 + 0.4 * iqTurbulence(point * 0.5 * hillsFreq *  + Randomize, 0.55)) * (biomeScale * hillsMagn * (0.05 - (0.4 * RidgedMultifractalDetail(point * hillsFreq + Randomize, 2.0, venus)) + 0.3 * RidgedMultifractalErodedDetail(point * hillsFreq + Randomize, 2.0, 1.1 * erosion, montBiomeScale)));
		}
		else
		{
			noiseOctaves = 8.0; // Decrease the number of octaves for smoother terrain
			noiseLacunarity = 2.0; // Slightly increase lacunarity for more variation in frequency
			height = biomeScale * hillsMagn * JordanTurbulence(point * hillsFreq + Randomize, 0.7, 0.5, 0.6, 0.35, 1.0, 0.8, 1.0);
		}
    } else if(biome < canyonsFraction) {
        // Canyons
        //	RODRIGO  - Edited canyons

        noiseOctaves = 8.0;
        noiseH = 0.9;
        noiseLacunarity = 4.0;
        noiseOffset = montesSpiky;
        height = -0.35 * canyonsMagn * montRange * RidgedMultifractalErodedDetail(point * 1.2 * canyonsFreq * inv2montesSpiky + Randomize, 2.0, erosion, montBiomeScale);

        //if (terrace < terraceProb)
        {
            float h = height * terraceLayers * 5.0;
            height = (floor(h) + smoothstep(0.5, 0.6, fract(h))) / (terraceLayers * 5.0);
        }
    } else {
		// Mountains
		if (oceanType > 0)
		{
			noiseOctaves = 10.0;
			noiseH       = 1.0;
			noiseLacunarity = 2.1;
			noiseOffset  = montesSpiky;
			// height = montesMagn * 5.0 * (0.5 + 0.4 * iqTurbulence(point * 0.5 * montesFreq + Randomize, 0.55))* 0.7* montesMagn * montRange * RidgedMultifractalErodedDetail(point * montesFreq * inv2montesSpiky + Randomize, 2.0, erosion, montBiomeScale)+ 0.6 * biomeScale * hillsMagn * JordanTurbulence(point/4 * hillsFreq/4 + Randomize, 0.8, 0.5, 0.6, 0.35, 1.0, 0.8, 1.0);
			height = (0.5 + 0.4 * iqTurbulence(point * 0.5 * (montesFreq * 3) + Randomize, 0.55)) * 0.4 * montesMagn * montRange * RidgedMultifractalErodedDetail(point * (montesFreq * 3) * inv2montesSpiky + Randomize, 2.0, erosion, montBiomeScale);
		}
		else
		{
			noiseOctaves = 10.0;
			noiseH       = 1.0;
			noiseLacunarity = 2.3;
			noiseOffset  = montesSpiky;
			height = montesMagn * 5.0 * ((0.5 + 0.8 * iqTurbulence(point * 0.5 * montesFreq + Randomize, 0.55)) * (0.1 * RidgedMultifractalDetail(point *  montesFreq + venus + Randomize, 1.0, montBiomeScale)));
		}
    }

    // Mare
//	RODRIGO - Edited Mare. Supress mare in terras
    float mare = global;
    float mareFloor = global;
    float mareSuppress = 1.0;

    if(riversMagn > 0.0) {
        mare = global;
    } else {

        if(mareSqrtDensity > 0.05) {
        //noiseOctaves = 2;
        //mareFloor = 0.6 * (1.0 - Cell3Noise(0.3*p));
            noiseH = 0.5;
            noiseLacunarity = 2.218281828459;
            noiseOffset = 0.8;
            craterDistortion = 1.0;
            noiseOctaves = 6.0;  // Mare roundness distortion
            mare = MareNoise(point, global, 0.0, mareSuppress);
        //lithoCells *= 1.0 - saturate(20.0 * mare);
        }
    }

    height *= saturate(20.0 * mare);        // suppress mountains, canyons and hills (but not dunes) inside mare
    height = (height + heightD) * shore;    // suppress all landforms inside seas
    //height *= lithoCells;                 // suppress all landforms inside lava seas

    // Ice caps
    // Make more steep slope on oceanic planets (oceanType == 0.1) and shallower on earth-like planets (oceanType == 1.0)
    float oceaniaFade = (oceanType == 1.0) ? 0.2 : 1.0;
    float iceCap = smoothstep(0.0, 1.0, saturate((latitude / latIceCaps - 1.0) * 50.0 * oceaniaFade));

    // Ice cracks
    float mask = 1.0;
    if(cracksOctaves > 0.0) {
        landform = CrackNoise(point, mask) * iceCap;
        height += landform;
    }

    // Craters
    float crater = 0.0;
    if(craterSqrtDensity > 0.05) {
        heightFloor = -0.1;
        heightPeak = 0.6;
        heightRim = 1.0;
        crater = CraterNoise(point, 0.5 * craterMagn, craterFreq, craterSqrtDensity, craterOctaves);
        noiseOctaves = 10.0;
        noiseLacunarity = 2.0;
        crater = 0.25 * crater + 0.05 * crater * iqTurbulence(point * montesFreq + Randomize, 0.55);

        // Young terrain - suppress craters
        noiseOctaves = 4.0;
        vec3 youngDistort = Fbm3D((point - Randomize) * 0.07) * 1.1;
        noiseOctaves = 4.0;
        float young = 1.0 - Fbm(point + youngDistort);
        young = smoothstep(0.0, 1.0, young * young * young);
        crater *= young;
    }

    height += mare + crater;

    // Sea bottom
    /*const float seaBottomTranstionStart = 0.0008;
    const float seaBottomTranstionEnd   = 0.0010;
    float depth = height - seaLevel;*/

    //	RODRIGO - Edited Rivers and Rifts. No more inverse rifts on mare

    float rodrigoDamping;

    rodrigoDamping = global - seaLevel - rodrigoDamping;
    float damping;

    // Pseudo rivers

    if(riversMagn > 0.0) {
        damping = (smoothstep(0.145, 0.135, rodrigoDamping)) *    // disable rivers inside continents
            (smoothstep(-0.0016, -0.018, seaLevel - height));  // disable rivers inside oceans
        _PseudoRivers(point, global, damping, height);
    }

    // Rifts
    if(riftsMagn > 0.0) {
        damping = (smoothstep(1.0, 0.1, height - seaLevel)) *
            (smoothstep(-0.1, -0.2, seaLevel - height));

        _Rifts(point, damping, height);
    }

    // Shield volcano
    if(volcanoOctaves > 0 && (height > seaLevel + 0.1 || oceanType == 0) && iceCap == 0.0)
        height = VolcanoNoiseFixed(point, global, height);

    // Mountain glaciers
    /*noiseOctaves = 5.0;
    noiseLacunarity = 3.5;
    float vary = Fbm(point * 1700.0 + Randomize);
    float snowLine = (height + 0.25 * vary - snowLevel) / (1.0 - snowLevel);
    height += 0.0005 * smoothstep(0.0, 0.2, snowLine);*/

    // Apply ice caps
    // Suppress everything except ice caps in oceanic planets
    height = height * oceaniaFade + (0.3 * seaLevel + icecapHeight) * iceCap;

//	RODRIGO - Terrain noise matching albedo noise

    noiseOctaves = 14.0;
    noiseLacunarity = 2.218281828459;
    distort = Fbm3D((point + Randomize) * 0.07) * 1.5;
    float vary = 1.0 - 5 * (Fbm((point + distort) * (1.5 - RidgedMultifractal(pp, 8.0) + RidgedMultifractal(pp * 0.999, 8.0))));

    // Equatorial ridge
    if(eqridgeMagn > 0.0) {
        float prevHeight = height;

        noiseOctaves = 5.0;
        float x = point.y / eqridgeWidth;
        float ridgeHeight = exp(-0.5 * x * x);
        float ridgeModulate = 1.0;
        for(int i = 0; i < 5; i++) {
            ridgeModulate -= eqridgeModMagn * (Fbm(point * eqridgeModFreq - Randomize) * 0.5);
        }
        height += eqridgeMagn * ridgeHeight * ridgeModulate;

        noiseOctaves = 10.0;
        ridgeModulate = 1.0;
        for(int i = 0; i < 5; i++) {
            ridgeModulate -= eqridgeModMagn * (Fbm(point * eqridgeModFreq - Randomize) * 0.5);
        }
        height += eqridgeMagn * ridgeHeight * ridgeModulate * 0.1;
        height = max(height, prevHeight);
    }

    float drivenMaterial = 0.0;

    if(abs(drivenDarkening) >= 0.55) {
        noiseOctaves = 3;
        drivenMaterial = -point.z * sign(drivenDarkening);
        drivenMaterial += 0.2 * Fbm(point * 1.63);
        drivenMaterial = saturate(drivenMaterial);
        drivenMaterial *= (1.0 / 0.45 * 0.9 - abs(point.y)) * (drivenDarkening - 0.55);
    }

    height = mix(height, height + 0.0001, vary) + drivenMaterial;

    // smoothly limit the height
    height = softPolyMin(height, 0.99, 0.3);
    height = softPolyMax(height, 0.05, 0.1);

    if(riversMagn > 0.0) {
        HeightBiomeMap = vec4(height - 0.06);
    } else {
        HeightBiomeMap = vec4(height);
    }

}

//-----------------------------------------------------------------------------

void main() {
    vec3 point = GetSurfacePoint();
    HeightMapTerra(point, OutColor);
}

//-----------------------------------------------------------------------------

#endif
