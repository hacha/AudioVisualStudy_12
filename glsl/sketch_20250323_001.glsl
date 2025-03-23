// for shadertoy

// 距離関数：立方体
float sdBox(vec3 p,vec3 b)
{
    vec3 d=abs(p)-b;
    return length(max(d,0.))+min(max(d.x,max(d.y,d.z)),0.);
}

// シーンのSDF
float map(vec3 p)
{
    return sdBox(p,vec3(1.));// 1x1x1の立方体
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
    
    // カメラを回転
    float time=iTime*.5;
    mat3 rotX=mat3(
        1.,0.,0.,
        0.,cos(time),-sin(time),
        0.,sin(time),cos(time)
    );
    mat3 rotY=mat3(
        cos(time),0.,sin(time),
        0.,1.,0.,
        -sin(time),0.,cos(time)
    );
    rd=rotX*rotY*rd;
    
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
            
            // 単純な拡散反射モデル
            vec3 col=vec3(.8,.3,.2)*diff+vec3(.1);
            fragColor=vec4(col,1.);
            return;
        }
        
        if(t>tmax)break;
        t+=d;
    }
    
    // 背景色（空）
    vec3 bg=vec3(.5,.7,1.)-.3*rd.y;
    fragColor=vec4(bg,1.);
}