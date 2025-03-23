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

// RGB -> HSV変換
vec3 rgb2hsv(vec3 c){
    vec4 K=vec4(0.,-1./3.,2./3.,-1.);
    vec4 p=mix(vec4(c.bg,K.wz),vec4(c.gb,K.xy),step(c.b,c.g));
    vec4 q=mix(vec4(p.xyw,c.r),vec4(c.r,p.yzx),step(p.x,c.r));
    
    float d=q.x-min(q.w,q.y);
    float e=1.e-10;
    return vec3(abs(q.z+(q.w-q.y)/(6.*d+e)),d/(q.x+e),q.x);
}

// HSV -> RGB変換
vec3 hsv2rgb(vec3 c){
    vec4 K=vec4(1.,2./3.,1./3.,3.);
    vec3 p=abs(fract(c.xxx+K.xyz)*6.-K.www);
    return c.z*mix(K.xxx,clamp(p-K.xxx,0.,1.),c.y);
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
    float displacement=fbm(p*3.+time*.2)*.6;
    
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
            
            // FBMを計算して変位量を取得
            vec3 origPosition=rotateY(iTime*.5)*rotateX(iTime*.7*.5)*p;
            float boxDist=sdBox(origPosition,vec3(1.));
            float displacement=fbm(origPosition*3.+iTime*.2)*.6;
            
            // ベースカラーをHSVに変換
            vec3 baseColor=vec3(.8,.3,.2);
            vec3 hsvColor=rgb2hsv(baseColor);
            
            // 変位に基づいてHueをシフト（-0.3 ~ +0.3のシフト）
            hsvColor.x+=displacement*1.;
            
            // Saturationを1.8倍に
            hsvColor.y=min(hsvColor.y*1.8,1.);
            
            // RGBに戻す
            vec3 col=hsv2rgb(hsvColor)*diff+vec3(.1);
            
            fragColor=vec4(col,1.);
            return;
        }
        
        if(t>tmax)break;
        t+=d;
    }
    
    // 背景色（黒）
    fragColor=vec4(0.,0.,0.,1.);
}