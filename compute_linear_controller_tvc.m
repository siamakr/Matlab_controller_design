clc
clear

syms x y z vx vy vz p q u wx wy wz      % States
syms Ft Fx Fy dp dr wtm wtrw 
% Ft= Thrust (N) Fx, Fy =TVC Force dp,dr= pitch,roll angle, wtm = EDF motor
% angular speed (rad/s), wtrw = Reaction Wheel angular speed (rad/s) 
syms r2n_p1 r2n_p2 m Jx Jy Jz Jprop Jrw ltvc lrw g kmrw kmedf     
% r2n_p1 and r2n_p1 = polynomial regression coeff. 
% m = mass 
% Jx, Jy, Jz = Moments of Inertia 
% Jprop = moment of inertia of edf prop 
% Jrw = moment of inertial of reaction wheel 
% ltvc = COM-to-TVC distance 
% lrw = COM-to-RW distance 
% km = rw motor constant (test)



%% Definitions

%% Matricies 
% Transformation matrix from body angular velocity to Tait-Bryan rates
W =    [1,      0,          -sin(q)       ;
        0,      cos(p),     cos(q)*sin(p) ;
        0,      -sin(p),    cos(q)*cos(p) ];

%rotation about the x-axis 
rx =   [1       0                  0; 
        0      cos(dr)     -sin(dr) ; 
        0      sin(dr)     cos(dr)] ;

%rotation matrix about y-axis 
ry =   [cos(dp)     0       sin(dp) ; 
        0           1             0 ;   
        -sin(dp)    0       cos(dp) ];

%rotation matrix about z-axis (won't be needed in our case)
% rz =   [cos(dy)    -sin(dy)         0; 
%         sin(dy)     cos(dy)         0; 
%         0           0               1];

%Rotation Matrix from Body-to-TVC frames 
Rbt = rx*ry;                      %(rotate about X-axis and then about Y-axis - from Body frame to TVC frame

%Rotation Matrix from TVC-to-Body frames 
Rtb = simplify(inv(rx*ry));       %or Rtb = simplify(inv(Rbt))


Winv = simplify(inv(W));
  
% Rotation matrix from body to world frame, input: roll, pitch, yaw
R = [cos(q)*cos(u), sin(p)*sin(q)*cos(u)-cos(p)*sin(u), cos(p)*sin(q)*cos(u)+sin(p)*sin(u) ;
     cos(q)*sin(u), sin(p)*sin(q)*sin(u)+cos(p)*cos(u), cos(p)*sin(q)*sin(u)-sin(p)*cos(u) ;
     -sin(q),       sin(p)*cos(q),                      cos(p)*cos(q)                     ];
 

% Matrix of mass inertia
J = [Jx 0  0  ;
     0  Jy 0  ;
     0  0  Jz];

%% Forces

%Converts wtm in rad/s to FT in Newtons by way of a polynomial regression
%coeff values r2n_p1 and r2n_p2
Ft = r2n_p1*wtm + r2n_p2;   %total motor force produce by props 

% Body forces
fb = Rtb * transpose([0 0 Ft]);     %rotate the thrust-vector Ft to body frame 


%% Torques
%torque of reaction-wheel 
trw = kmrw * wtrw ;     %this is just a placeholder and of course wrong 


%torque of EDF motor Prop 
tprop = kmedf * wtm ;  %this is just a placeholder and of course wrong 

%test case: 



%Body-Torque matrix 
tb = [ fb(1)*ltvc            ;
      -fb(2)*ltvc            ;
       tprop-trw];

%% States + Input Vectors 
% State vectors used for derivation
nw = [p q u].';     % Attitude (world frame)
wb = [wx wy wz].';  % Angular velocity (body frame)
pw = [x y z].';     % Position (world frame)
vb = [vx vy vz].';  % Velocity (body frame)

% Total state vector
X = [nw; wb; pw; vb];                   % full state 
X_att = [nw; wb];                       % attitude only 
X_red = [nw; wb; pw(3); vb(3)];         % Reduced state vector (only attitude and altitude)
%X_hor = [ pw(1); pw(2); vb(1); vb(2) ]; % Reduced state vector for horizontal movements
%X_roll = [nw(1); wb(1); pw(1); vb(1)];

% Full Input vector (TVC + EDF + Reaction Wheel)
U = [dp; dr; wtm; wtrw];

% Attitude only input (TVC + EDF) 
U_att = [dp; dr; wtm];

% Input vector for horizontal model
% U_hor = [p; q];

% Roll 
% U_roll = [wtm; wtrw];



%% Rotational dynamics

nw_dot = Winv * wb; %transform wb to tair-bryon 
wb_dot = inv(J) * (tb - cross(wb, J * wb)  );

%% Translational dynamics

pw_dot = R * vb;
vb_dot = 1/m * ( fb -  R.' * [0 0 m*g].');

% Translational dynamics in world
vw_dot = 1/m * R * fb - [0 0 m*g].';

%% Combined non-linear model

% Full 12 state vector 
f = [ nw_dot  ;
      wb_dot  ;
      pw_dot  ;
      vb_dot ];

% Reduced non-linear model (8 states)
f_red = [ nw_dot     ;
          wb_dot     ;
          pw_dot(3)  ;
          vb_dot(3) ];
      
% Reduced Attitude only non-linear model (6 states)
f_att = [ nw_dot     ;
          wb_dot     ];
         
      
% Horizontal non-linear model
% f_hor = [ pw_dot(1) ;
%           pw_dot(2) ;
%           vb_dot(1) ;
%           vb_dot(2)];
      
      
% f_roll = [ nw_dot(1) ;
%           wb_dot(1)  ;
%           pw_dot(1)  ;
%           vb_dot(1) ];
  
%% Linearization

% Using the Jacobian method, the set of nonlinear system equations are
% linearized around the hover point

A = jacobian(f_red, X_red);
B = jacobian(f_red, U_att);

% Reduced model (only z-axis in position)
A2 = jacobian(f_red, X_red);
B2 = jacobian(f_red, U);

%Reduced model for attitude only 
A5 = jacobian(f_att, X_att);
B5 = jacobian(f_att, U_att);

% Horizontal model (only x- and y-direction)
% A3 = jacobian( f_hor, X_hor );
% B3 = jacobian( f_hor, U_hor );


% Single dimension model (roll/x axis)
% A4 = jacobian( f_roll, X_roll );
% B4 = jacobian( f_roll, U_roll );


%% Constants + Linearization Point Def 
% The A and B matrixes are now filled with partial derivatives, similar to
% an taylor expansion to approximate a nonlinear function/ODE
% We must insert the state- and input-values at the operating point

% All the states is zero at the hover point
x = 0; y = 0; z = 0; vx = 0; vy = 0; vz = 0; p = 0; q = 0; u = 0; wx = 0; wy = 0; wz = 0;

% vehicle Constants
r2n_p1 = 0.018566536813619;
r2n_p2 = -22.506778362213;
pitchp1 = -20.4054981741083;
pitchp2 = 1530.81204806643;
rollp1 = -29.2198405328854;
rollp2 = 1453.88991021228;
m = 2.457;                      %kg
Jx = 6.85563961956689;
Jy = 7.08910783725713;
Jz = 0.0120276855157049;
Jprop = 0.000174454522116462;
Jrw = 0.00174245619164574;
ltvc = 0.1335;                  %COM to TVC (m)
lrw = 0.09525;                  % COM to RW (m)    
g= 9.807;
kmedf = .00001;
kmrw = .010;

% All input is not zero!
dp=0; dr=0; wtrw = 0;
%the rad/s value that represents hover thrust of m*g
wtm = (m*g - r2n_p2)/r2n_p1; % rad/s



%% System Definition 
% Now the A and B matrixes can be evaluted, yield the full linear model
% around the hover point.
A_sys = vpa(subs(A), 4);
B_sys = vpa(subs(B), 4);
C_sys = eye(8);
D_sys = zeros(8,3);

A_sys = double(A_sys);
B_sys = double(B_sys);
C_sys = double(C_sys);
D_sys = double(D_sys);

% Reduced model 
A_red = vpa(subs(A2), 4);
B_red = vpa(subs(B2), 4);
C_red = eye(8);
D_red = zeros(8,4);
 
 A_red = double(A_red);
 B_red = double(B_red);
 C_red = double(C_red);
 D_red = double(D_red);

%reduced model for attitude only 
A_att = vpa(subs(A5), 4);
B_att = vpa(subs(B5), 4);
C_att = eye(6);
D_att = zeros(6,3);

 A_att = double(A_att);
 B_att = double(B_att);
 C_att = double(C_att);
 D_att = double(D_att);


% Horizontal model
% A_hor = vpa(subs(A3),4);
% B_hor = vpa(subs(B3),4);
% C_hor = eye(4);
% D_hor = zeros(4,2);

% % Reduced model with integral action states
% G_hov = [ 0 0 0 0 0 0 1 0 ]; % z
%    
% A_int = [A_red; G_hov];
% A_int = [A_int zeros(9,1) ];
% B_int = [B_red; zeros(1,5) ];
% C_int = eye(9);
% D_int = zeros(9,5);

% % Horizontal model with integral action states
% G_pos = [ 1 0 0 0; 
%          0 1 0 0 ];
% 
% A_hint = [A_hor; G_pos];
% A_hint = [A_hint zeros(6,2) ];
% B_hint = [B_hor; zeros(2,2) ];
% C_hint = eye(6);
% D_hint = zeros(6,2);

     
%% Open Loop dynamics
% 
sys = ss(A_sys,B_sys,C_sys,D_sys);
sys_red = ss(A_red,B_red,C_red,D_red);
sys_att = ss(A_att,B_att,C_att,D_att);
% % sys_int = ss(A_int,B_int,C_int, D_int);
% sys_hor = ss(A_hor, B_hor, C_hor, D_hor);
% % sys_hint = ss(A_hint, B_hint, C_hint, D_hint);


%% Design controller

%% Bryson's Rule. 
% Max angle of 0.3 radians. Maximum angular rate of 5 rad/second
Q = [ 1/.1^2     0       0        0      0      0      0        0       ;  % Roll
      0        1/0.1^2   0        0      0      0      0        0       ;  % Pitch
      0        0        1/1^2    0      0      0      0        0       ;  % Yaw
      0        0        0        1/1^2  0      0      0        0       ;  % omega_x
      0        0        0        0      1/1^2  0      0        0       ;  % omega_y
      0        0        0        0      0      1/1^2  0        0       ;  % omega_z
      0        0        0        0      0      0      1/0.5^2    0       ;  % z
      0        0        0        0      0      0      0        1/1^2     ]; % v_z

Q_red = Q;  
Q_att = Q(1:6,1:6);
  
% Integral action  
% Q(9,9) = [ 1/0.15^2 ]; % z
      
% Max actuation angle of +-15 degress
R = [ 1/20.46^2   0       0       0           ; % dr
      0        1/20.46^2  0       0          ; % dp
      0        0       1/.1^2  0           ; % wtm
      0        0       0       1/.75^2     ]; % wtrw

 R_att = R(1:3,1:3);
  % Max actuation angle of +-15 degress
% R_att = [ 1/3^2        0       0           ; % dr
%             0        1/3^2     0           ; % dp
%             0        0       1/.1^2       ]; % wtm


%% Optimal Controller 
% Compute "optimal" controller
 K = lqr(sys_red, Q, R);
K_red = lqr(sys_red, Q, R);
K_att = lqr(sys_att, Q_att, R_att);

% Compute integral limit matching the steady-state motor velocity
% int_lim = wt/K_hov(5,9) + wt*0.005;
% 
% sys_d = c2d(sys_int, 0.008, 'zoh' );
% 
% K_lqrd = dlqr(sys_d.A, sys_d.B, Q, R);

% matrix_to_cpp( K_hov )

%% Closed Loop System Calculation 
% Calcuate closed loop system
 figure(1)
cl_sys_att = ss((A_att - B_att*K_att), B_att, C_att, D_att );
% sys_cl_hov = feedback( sys_red*K_red, eye(8));
sys_clfb_att = feedback( sys_att*K_att, eye(6));

 cl_sys_red = ss((A_red - B_red*K_red), B_red, C_red, D_red );
 %sys_cl_hov = feedback( sys_red*K_red, eye(8));
 sys_clfb_red = feedback( sys_red*K_red, eye(8));
 
%  cl_sys = ss((A_sys - B_sys*K), B_sys, C_sys, D_sys );
% 
%  sys_clfb_sys = feedback( sys*K, eye(8));

%% Pole-Zero Mapping 
 figure(1)
 pzmap(sys_clfb_att,'o');
 [p_att,z_att] = pzmap(sys_clfb_att)
 grid on
 
 figure(2)
 pzmap(sys_clfb_red,'o');
 [p_red,z_red] = pzmap(sys_clfb_red)
 grid on
%  
%   figure(3)
%  pzmap(sys_clfb_sys,'o');
%  [p_sys,z_sys] = pzmap(sys_clfb_sys)
%  grid on
  
 K_att
 K_red 

 
 figure(4)
 opt = stepDataOptions; 
 opt.StepAmplitude = 1; 
 step(sys_clfb_att, sys_clfb_red, opt, .5)
 
 figure(5)
  step(sys_clfb_red, opt, .5)
% 
% Q_pos = [ 1/0.5^2  0         0        0        ;
%           0         1/0.5^2  0        0        ;
%           0         0         1/2^2  0        ;
%           0         0         0        1/2^2 ];
% 
% Q_hor = Q_pos;      
%       
% Q_pos(5:6,5:6) = [ 1/1^2  0
%                    0        1/1^2];
%      
% R_pos = [ 1/0.05^2  0;
%           0          1/0.05^2];
% 
% K_pos = lqr(sys_hint, Q_pos, R_pos);
% K_hor = lqr(sys_hor, Q_hor, R_pos);
% 
% 
% sys_cl_pos = feedback( sys_hor*K_hor, eye(4));
% 
% figure(2)
% pzmap(sys_cl_pos);
% [p2,z2] = pzmap(sys_cl_pos)
% % grid on



% sys_total = series( sys_cl_pos, sys_cl_pos )

% matrix_to_cpp( K_pos )

%% Symbolic Discretization

% syms dt;
% M = expm([A_sym, B_sym; zeros(5,12), zeros(5,5) ]*dt);
% 
% Ad = M(1:12, 1:12);
% Bd = M(1:12, 13:17);

