% ex12.m
% This example shows the effect of ill-conditioning on derivatives
% This considers a few different methods of approximation
%
% Specifically, the function we are considering here is
%   u(x,y) = sinh(x)cosh(y)
% And we consider different methods of approximating the Laplacian
% on the domain [-1,1]^2
% The Laplacian of that function is Lap(u) = 2u
%
% The methods we consider are:
%   Trefethen: Cheb
%   Collocation 2D
%   Collocation 1D
%   GaussQR 2D
%   GaussQRr 2D

rbfsetup
global GAUSSQR_PARAMETERS
GAUSSQR_PARAMETERS.ERROR_STYLE = 2; % Use absolute error

ufunc = @(x,y) sinh(x).*cosh(y);
N = 24;

rbf = @(e,r) exp(-(e*r).^2);
drbf = @(e,r,dx) -2*e^2*dx.*exp(-(e*r).^2);
d2rbf = @(e,r) 2*e^2*(2*(e*r).^2-1).*exp(-(e*r).^2);
Lrbf = @(e,r) 4*e^2*((e*r).^2-1).*exp(-(e*r).^2);

[D,x] = cheb(N);
y = x;
[xx,yy] = meshgrid(x,y);
xx = xx(:); yy = yy(:);
u = ufunc(xx,yy);
D2 = D^2;
I = eye(N+1);
L = kron(I,D2) + kron(D2,I);
err_Trefethen = errcompute(L*u,2*u);

epvec = logspace(-1,1,40);
pts = [xx,yy];
rp = DistanceMatrix(pts,pts);
r = DistanceMatrix(x,x);
errvec1D = [];
errvec2D = [];
k = 1;
for ep=epvec
  Amat = rbf(ep,rp);
  b = Amat\u;
  Lmat = Lrbf(ep,rp);
  errvec2D(k) = norm(2*u-Lmat*b);
  A = rbf(ep,r);
  d2A = d2rbf(ep,r);
  I = eye(size(r));
  D = d2A/A;
  L = kron(I,D) + kron(D,I);
  errvec1D(k) = norm(2*u-L*u);
  k = k + 1;
end

epvec = logspace(-8,0,25);
err_GQR_interp = [];
err_GQR_deriv = [];
alpha = 1;
errvecQ2d = [];
k = 1;
for ep=epvec
  GQR = rbfqrr_solve(pts,u,ep,alpha);
  Lu = rbfqr_eval(GQR,pts,[2,0]) + rbfqr_eval(GQR,pts,[0,2]);
  errvecQ2d(k) = norm(2*u-Lu);
%  uqr = rbfqr_eval(GQR,pts);
%  err_GQR_interp(k) = errcompute(uqr,u);
%  udqr = rbfqr_eval(GQR,pts,[1,1]);
%  err_GQR_deriv(k) = errcompute(udqr,cosh(xx).*sinh(yy));
  k = k + 1;
end

% loglog(epvec,errvec1D,'b','LineWidth',3),hold on
% loglog(epvec,errvec2D,'g','LineWidth',3)
% loglog(epvec,err_Trefethen*ones(size(epvec)),'--k','LineWidth',2),hold off
% legend('kron Collocation','2D Collocation','Trefethen')