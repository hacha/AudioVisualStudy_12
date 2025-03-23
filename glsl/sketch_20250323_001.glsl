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

// 丸みを持った立方体
float sdRoundBox(vec3 p,vec3 b,float r)
{
    vec3 d=abs(p)-b;
    return length(max(d,0.))-r+min(max(d.x,max(d.y,d.z)),0.);
}

// サイン波による変形を加えた有機的な立方体
float sdOrganicBox(vec3 p,vec3 b,float r,float amp,float freq)
{
    // サイン波による変形を追加
    float wave=amp*sin(p.x*freq)*sin(p.y*freq)*sin(p.z*freq);
    
    // 基本の丸い立方体
    float box=sdRoundBox(p,b,r);
    
    return box+wave;
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

// 跳ね回るPointLightの位置を計算
vec3 getPointLightPos(float time){
    // 箱のサイズに合わせて、バウンドする範囲を設定
    float boxSize=9.;// 実際の立方体サイズ10.0より少し小さめ
    
    // 初速度と重力
    vec3 velocity=vec3(5.,7.,6.);
    vec3 gravity=vec3(0.,-9.8,0.);
    
    // 時間の経過による位置変化（単純なバウンス物理を近似）
    vec3 pos=vec3(0.);
    
    // X, Y, Z方向それぞれで独立してバウンス計算
    // sin/cosベースの周期的な動きと、跳ねる効果を組み合わせる
    pos.x=boxSize*sin(time*velocity.x*.1);
    
    // Y方向は重力を意識した上下運動
    float bounceHeight=abs(sin(time*2.))*.8+.2;
    pos.y=boxSize*bounceHeight*sin(time*velocity.y*.15);
    
    pos.z=boxSize*cos(time*velocity.z*.12);
    
    return pos;
}

// シーンのSDF
float map(vec3 p)
{
    // 時間で回転（速度を0.2倍に減速）
    float time=iTime*.1;// 0.5→0.1に変更
    p=rotateY(time)*rotateX(time*.7)*p;
    
    // 有機的な丸い立方体SDF（内外反転）
    // 丸みをより大きく、周波数を小さくしてなだらかに
    float box=sdOrganicBox(p,vec3(10.),2.,.3,.15);
    
    // FBMによるディスプレースメント（周波数も小さく）
    float displacement=fbm(p*.8+iTime*.2)*.6;
    
    return-(box+displacement);// 反転して内側から見るように
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
    
    // カメラ設定（立方体の中央に配置）
    vec3 ro=vec3(0.,0.,0.);// レイの原点（カメラ位置）を中央に
    vec3 rd=normalize(vec3(uv,1.));// レイの方向
    
    // PointLightの位置と色
    vec3 pointLightPos=getPointLightPos(iTime);
    vec3 pointLightColor=vec3(1.,.2,.1)*2.;// 明るい赤色
    
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
            
            // 通常のディレクショナルライト
            vec3 lightDir=normalize(vec3(1.,1.,-1.));
            float diff=max(dot(normal,lightDir),0.);
            
            // PointLightからの照明計算
            vec3 lightVec=pointLightPos-p;
            float lightDistance=length(lightVec);
            vec3 pointLightDir=normalize(lightVec);
            
            // 逆二乗則による減衰
            float attenuation=1./(1.+.1*lightDistance+.01*lightDistance*lightDistance);
            
            // PointLightの拡散反射
            float pointDiff=max(dot(normal,pointLightDir),0.);
            
            // FBMを計算して変位量を取得
            vec3 origPosition=rotateY(iTime*.1)*rotateX(iTime*.07)*p;
            // 有機的な立方体のSDF計算（色の計算用）
            float boxDist=sdOrganicBox(origPosition,vec3(10.),2.,.3,.15);
            float displacement=fbm(origPosition*.8+iTime*.2)*.6;
            
            // ベースカラーをHSVに変換
            vec3 baseColor=vec3(.8,.3,.2);
            vec3 hsvColor=rgb2hsv(baseColor);
            
            // 変位に基づいてHueをシフト（-0.3 ~ +0.3のシフト）
            hsvColor.x+=displacement*1.;
            
            // Saturationを1.8倍に
            hsvColor.y=min(hsvColor.y*1.8,1.);
            
            // RGBに戻す
            vec3 surfaceColor=hsv2rgb(hsvColor);
            
            // 最終的な色計算：通常ライトとポイントライトの組み合わせ
            vec3 col=surfaceColor*diff*vec3(.6,.6,.8)+vec3(.1);// 通常ライト（青みがかった色）
            col+=surfaceColor*pointDiff*pointLightColor*attenuation*4.;// 赤いポイントライト
            
            // ポイントライト自体も表示（小さな光の球として）
            float lightGlow=smoothstep(.2,0.,length(p-pointLightPos)-.1);
            col=mix(col,pointLightColor,lightGlow);
            
            fragColor=vec4(col,1.);
            return;
        }
        
        if(t>tmax)break;
        t+=d;
    }
    
    // 背景色（黒）
    fragColor=vec4(0.,0.,0.,1.);
}