function [y_new, forces, nextFz] = calcAngles2(car,x,y0,forces,xdot0)

n = round(car.TSmpc/car.TSdyn,0);
dt = car.TSdyn;
y = y0;

% tires 3 and 4 switched from jazar model

for i = 2:n+1    
    k_f = car.k;
    k_r = car.k;
    k_tf = car.k*5;
    k_tr = k_tf;
    c_f = car.c;
    c_r = car.c;
    m = car.M;
    m_f = m/10;
    m_r = m_f;
    k_rf = car.k_rf;
    k_rr = car.k_rr;
    Ix = car.Ixx;
    Iy = car.Iyy;
    a_1 = car.l_f;
    a_2 = car.l_r;
    b_1 = car.t_f/2;
    b_2 = car.t_f/2;
    w = car.t_f;
        
    m = diag([m Ix Iy m_f m_f m_r m_r]);
    
    c11 = 2*c_f+2*c_r;
    c21 = b_1*c_f-b_2*c_f-b_1*c_r+b_2*c_r;
    c12 = c21;
    c31 = 2*a_2*c_r-2*a_1*c_f;
    c13 = c31;
    c22 = b_1^2*c_f+b_2^2*c_f+b_1^2*c_r+b_2^2*c_r;
    c32 = a_1*b_2*c_f-a_1*b_1*c_f-a_2*b_1*c_r+a_2*b_2*c_r;
    c23 = c32;
    c33 = 2*c_f*a_1^2+2*c_r*a_2^2;
    
    c = [c11 c12 c13 -c_f -c_f -c_r -c_r;
        c21 c22 c23 -b_1*c_f b_2*c_f -b_2*c_r b_1*c_r;
        c31 c32 c33 a_1*c_f a_1*c_f -a_2*c_r -a_2*c_r;
        -c_f -b_1*c_f a_1*c_f c_f 0 0 0;
        -c_f b_2*c_f a_1*c_f 0 c_f 0 0;
        -c_r -b_2*c_r -a_2*c_r 0 0 c_r 0;
        -c_r b_1*c_r -a_2*c_r 0 0 0 c_r];
    
    k11 = 2*k_f+2*k_r;
    k21 = b_1*k_f-b_2*k_f-b_1*k_r+b_2*k_r;
    k12 = k21;
    k31 = 2*a_2*k_r - 2*a_1*k_f;
    k13 = k31;
    k22 = k_rf+b_1^2*k_f+b_2^2*k_f+b_1^2*k_r+b_2^2*k_r;
    k32 = a_1*b_2*k_f-a_1*b_2*k_f-a_2*b_1*k_r+a_2*b_2*k_r;
    k23 = k32;
    k42 = -b_1*k_f-k_rf/w;
    k24 = k42;
    k52 = b_2*k_f+k_rf/w;
    k25 = k52;
    k33 = 2*k_f*a_1^2+2*k_r+a_2^2;
    k44 = k_f+k_tf+k_rf/w^2;
    k55 = k44;
    
    k = [k11 k12 k13 -k_f -k_f -k_r -k_r;
        k21 k22 k23 k24 k25 -b_2*k_r b_1*k_r;
        k31 k32 k33 a_1*k_f a_1*k_f -a_2*k_r -a_2*k_r;
        -k_f k42 a_1*k_f k44 -k_rf/w^2 0 0;
        -k_f k52 a_1*k_f -k_rf/w^2 k55 0 0;
        -k_r -b_2*k_r -a_2*k_r 0 0 k_r+k_tr 0;
        -k_r b_1*k_r -a_2*k_r 0 0 0 k_r+k_tr];
    
    tireForceXY = forces.Ftires;
    tireForceXY(:,3) = 0;
    yawRate = x(2);
    longVel = x(3);
    latVel = x(4);
    
    lat_accel = longVel.*yawRate+xdot0(4,:);
    long_accel = -latVel.*yawRate+xdot0(3,:);
    rollMoment = -car.M*lat_accel*(car.h_g-car.h_rc);
    pitchMoment = -car.M*long_accel*(car.h_g-car.h_rc);
        
    jacking_rotation = [1 1 1 1; b_1 -b_2 b_1 -b_2; -a_1 -a_1 a_2 a_2];
    jacking_Fz = [car.h_rf/b_1; -car.h_rf/b_2; car.h_rr/b_1; -car.h_rr/b_2].*tireForceXY(:,2);
    % jacking_vec: [vertical force; roll moment; pitch moment]
    % ISO convention
    jacking_vec = jacking_rotation*jacking_Fz;
    
    %add up all applied moments, using given position vectors
    sumM = 0;
    for i = 1:size(forces.F,1)
        sumM = sumM+cross(forces.F(i,4:6),forces.F(i,1:3)); 
    end
    rollMoment = rollMoment+sumM(1);
    pitchMoment = pitchMoment-sumM(2);
    
    % transform from SAE coordinate system to ISO
    % [applied sprung mass vertical force, roll moment, pitch moment,
    % unsprung mass forces]
    F = [-sum(forces.F(:,3)) rollMoment pitchMoment 0 0 0 0]';
    F = F + [jacking_vec; jacking_Fz];

    % state vector: [x phi theta x1 x2 x3 x4]'
    yd = [y(8:end); m\(F-c*y(8:end)-k*y(1:7))];
    
    nextFz = -diag([k_tf k_tf k_tr k_tr])*y(4:7);
    y = y+yd*car.TSdyn;
end

y_new = y;

end