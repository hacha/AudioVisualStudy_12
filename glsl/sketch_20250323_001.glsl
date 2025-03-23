// for shadertoy

// ハッシュ関数（ランダム値生成）
float hash(float n){
    return fract(sin(n)*43758.5453);
}

float hash(vec3 p){
    p=fract(p*vec3(.1031,.1030,.0973));
    p+=dot(p,p.yxz+33.33);
    return fract((p.x+p.y)*p.z);
}

// 3次元値ノイズ
float valueNoise(vec3 p){
    vec3 i=floor(p);
    vec3 f=fract(p);
    
    // 8つの頂点での補間
    float a=hash(i);
    float b=hash(i+vec3(1.,0.,0.));
    float c=hash(i+vec3(0.,1.,0.));
    float d=hash(i+vec3(1.,1.,0.));
    float e=hash(i+vec3(0.,0.,1.));
    float f1=hash(i+vec3(1.,0.,1.));
    float g=hash(i+vec3(0.,1.,1.));
    float h=hash(i+vec3(1.,1.,1.));
    
    // スムーズな補間
    vec3 u=f*f*(3.-2.*f);
    
    return mix(mix(mix(a,b,u.x),
    mix(c,d,u.x),u.y),
    mix(mix(e,f1,u.x),
    mix(g,h,u.x),u.y),u.z);
}

// FBM（Fractional Brownian Motion）
float fbm(vec3 p){
    float value=0.;
    float amplitude=.5;
    float frequency=1.;
    
    // 複数のノイズを重ね合わせる
    for(int i=0;i<5;i++){
        value+=amplitude*valueNoise(p*frequency);
        frequency*=2.;
        amplitude*=.5;
    }
    
    return value;
}

// 距離関数：立方体
float sdBox(vec3 p,vec3 b)
{
    vec3 d=abs(p)-b;
    return length(max(d,0.))+min(max(d.x,max(d.y,d.z)),0.);
}

// 回転行列
mat3 rotateY(float angle){
    float s=sin(angle);
    float c=cos(angle);
    return mat3(
        c,0,s,
        0,1,0,
        -s,0,c
    );
}

mat3 rotateX(float angle){
    float s=sin(angle);
    float c=cos(angle);
    return mat3(
        1,0,0,
        0,c,-s,
        0,s,c
    );
}

// シーンのSDF
float map(vec3 p)
{
    // 時間で回転
    float time=iTime*.5;
    p=rotateY(time)*rotateX(time*.7)*p;
    
    // 基本の立方体SDF
    float box=sdBox(p,vec3(1.));
    
    // FBMによるディスプレースメント
    float displacement=fbm(p*3.+time*.2)*.3;
    
    return box+displacement;// ディスプレースメントを適用
}

// 法線計算
vec3 calcNormal(vec3 p)
{
    const float h=.0001;
    const vec2 k=vec2(1,-1);
    return normalize(
        k.xyy*map(p+k.xyy*h)+
        k.yxy*map(p+k.yxy*h)+
        k.yyx*map(p+k.yyx*h)+
        k.xxx*map(p+k.xxx*h)
    );
}

void mainImage(out vec4 fragColor,in vec2 fragCoord)
{
    // Normalized pixel coordinates (from 0 to 1)
    vec2 uv=(fragCoord-.5*iResolution.xy)/iResolution.y;
    
    // カメラ設定
    vec3 ro=vec3(0.,0.,-3.);// レイの原点（カメラ位置）
    vec3 rd=normalize(vec3(uv,1.));// レイの方向
    
    // レイマーチング
    float t=0.;
    float tmax=20.;
    float t_min=.01;
    
    for(int i=0;i<100;i++){
        vec3 p=ro+rd*t;
        float d=map(p);
        
        if(d<t_min){
            // オブジェクトにヒット
            vec3 normal=calcNormal(p);
            vec3 lightDir=normalize(vec3(1.,1.,-1.));
            float diff=max(dot(normal,lightDir),0.);
            
            // ノイズを色にも反映
            float noiseFactor=fbm(p*2.+iTime*.1);
            vec3 baseColor=vec3(.8,.3,.2);
            vec3 noiseColor=vec3(.2,.5,.8);
            vec3 col=mix(baseColor,noiseColor,noiseFactor)*diff+vec3(.1);
            
            fragColor=vec4(col,1.);
            return;
        }
        
        if(t>tmax)break;
        t+=d;
    }
    
    // 背景色（黒）
    fragColor=vec4(0.,0.,0.,1.);
}