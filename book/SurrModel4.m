% SurrModel4.m
% This considers the development of a surrogate model for the empirical
% distribution function (EDF) of data drawn from a random distribution.
% The data we consider again comes from the carsmall data set, where we
% consider the probability of finding a car with a given set of
% Acceleration, Displacement, Horsepower and Weight values.
% We use this density to help us compute a marginal model, studying the
% relevance of the parameters Horsepower and Weight averaged over all
% possible Acceleration and Displacement values which occur with
% probability density defined through the ECDF surrogate model.
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% Idea - Is it possible to introduce a constraint into the optimization
%%% problem so that, for fixed epsilon, a mu can be found to minimize the
%%% residual subject to enforcing positivity of the PDF?  Maybe, we would
%%% need test points at which the positivity is enforced, and an
%%% approximation to the derivative which is linear (maybe).  I guess it
%%% could be nonlinear within fmincon
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% Standardize the random results
global GAUSSQR_PARAMETERS
GAUSSQR_PARAMETERS.RANDOM_SEED(0);
GAUSSQR_PARAMETERS.ERROR_STYLE = 2;
GAUSSQR_PARAMETERS.NORM_TYPE = inf;

% Define some RBFs for use on this problem
rbfM2 = @(r) (1+r).*exp(-r);
rbfM2dx = @(r,dx,ep) -ep^2*exp(-r).*dx;
rbfM2dxdy = @(r,dx,dy,ep) prod(ep.^2)*exp(-r).*dx.*dy./(r+eps);
rbfM4 = @(r) (3+3*r+r.^2).*exp(-r);
rbfM4dx = @(r,dx,ep) -ep^2*exp(-r).*(1+r).*dx;
rbfM4dxdy = @(r,dx,dy,ep) prod(ep.^2)*exp(-r).*dx.*dy;
rbfM6 = @(r) (15+15*r+6*r.^2+r.^3).*exp(-r);
rbfM6dx = @(r,dx,ep) -ep^2*exp(-r).*(r.^2+3*r+3).*dx;
rbfM6dxdy = @(r,dx,dy,ep) prod(ep.^2)*exp(-r).*dx.*dy.*(1+r);

% This function allows you to evaluate the EDF
% Here, xe are the evaluation points, x are the observed locations
Fhat = @(xe,x) reshape(sum(all(repmat(x,[1,1,size(xe,1)])<=repmat(reshape(xe',[1,size(xe,2),size(xe,1)]),[size(x,1),1,1]),2),1),size(xe,1),1)/size(x,1);

% Choose the problem you want to study by setting test_opt
%   1 - 1D CDF fit to a generalized Pareto distribution
%   2 - 2D CDF fit to a normal distribution
%   3 - 4D CDF fit to carsmall data
%   4 - Order of convergence test for Pareto data
test_opt = 4;

switch test_opt
    case 1
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%% Below is a 1D example for creating an EDF response surface
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        % Create some random samples from a generalized pareto
        N = 800;
        gp_k = -1/2;
        gp_sigma = 1;
        gp_theta = 0;
        x = sort(icdf('gp',rand(N,1),gp_k,gp_sigma,gp_theta));
        
        % Evaluate the EDF at the given points
        % I guess this could be other points instead, but whatever
        y = Fhat(x,x);
        
        % Plot the EDF from the randomly generated data
        Nplot = 500;
        xplot = pickpoints(gp_theta,gp_theta-gp_sigma/gp_k,Nplot);
        h_cdf_ex = figure;
        subplot(1,3,1)
        plot(xplot,cdf('gp',xplot,gp_k,gp_sigma,gp_theta),'r','linewidth',3);
        hold on
        plot(x,y,'linewidth',3)
        hold off
        title('Empirical CDF')
        legend('True','Empirical')
        
        % Choose an RBF to work with
        rbf = rbfM4;
        rbfdx = rbfM4dx;
        
        % Create the surrogate model
        ep = .3;
        mu = 1e-2;
        K_cdf = rbf(DistanceMatrix(x,x,ep));
        cdf_coef = (K_cdf+mu*eye(N))\y;
        cdf_eval = @(xeval) rbf(DistanceMatrix(xeval,x,ep))*cdf_coef;
        pdf_eval = @(xeval) rbfdx(DistanceMatrix(xeval,x,ep),DifferenceMatrix(xeval,x),ep)*cdf_coef;
        
        % Evaluate and plot the surrogate CDF
        cplot = cdf_eval(xplot);
        subplot(1,3,2)
        plot(xplot,cplot,'linewidth',3);
        title('Surrogate CDF')
        
        % Evaluate and plot the surrogate PDF
        pplot = pdf_eval(xplot);
        subplot(1,3,3)
%         plot(xplot,pdf('beta',xplot,beta_a,beta_b),'r','linewidth',3);
        plot(xplot,pdf('gp',xplot,gp_k,gp_sigma,gp_theta),'r','linewidth',3);
        hold on
        plot(xplot,pplot,'linewidth',3);
        title('Surrogate PDF')
        legend('True','Computed')
        hold off
    case 2
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%% Below is a 2D example for creating an EDF response surface
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        % Create some random samples from a 2D standard normal
        N = 400;
        x = randn(N,2);
        
        % Evaluate the EDF at some points to create data for the model
        Ndata = 20;
        xdata = pick2Dpoints(min(x(:))*[1 1],max(x(:))*[1 1],Ndata*[1;1]);
        ydata = Fhat(xdata,x);
        
        % Plot the EDF from the randomly generated data
        h_cdf_ex = figure;
        subplot(1,3,1)
        surf(reshape(xdata(:,1),Ndata,Ndata),reshape(xdata(:,2),Ndata,Ndata),reshape(ydata,Ndata,Ndata))
        title('Empirical CDF')
        
        % Choose an RBF to work with
        rbf = rbfM6;
        rbfdxdy = rbfM6dxdy;
        
        % Create a surrogate model for the EDF
        ep = [1,1];
        mu = 4e-2;
        K_cdf = rbf(DistanceMatrix(xdata,xdata,ep));
        % cdf_coef = K_cdf\ydata;
        cdf_coef = (K_cdf+mu*eye(Ndata^2))\ydata;
        % cdf_coef = (K_cdf'*K_cdf+mu*eye(Ndata^2))\K_cdf'*ydata;
        cdf_eval = @(xeval) rbf(DistanceMatrix(xeval,xdata,ep))*cdf_coef;
        pdf_eval = @(xeval) max(rbfdxdy(DistanceMatrix(xeval,xdata,ep),DifferenceMatrix(xeval(:,1),xdata(:,1)),...
            DifferenceMatrix(xeval(:,2),xdata(:,2)),ep)*cdf_coef,0);
        
        % Evaluate and plot the surrogate CDF on a grid
        Nplot = 40;
        xplot = pick2Dpoints(min(x(:))*[1 1],max(x(:))*[1 1],Nplot*[1;1]);
        cplot = cdf_eval(xplot);
        subplot(1,3,2)
        surf(reshape(xplot(:,1),Nplot,Nplot),reshape(xplot(:,2),Nplot,Nplot),reshape(cplot,Nplot,Nplot))
        title('Surrogate CDF')
        
        % Evaluate and plot the surrogate PDF on a grid
        pplot = pdf_eval(xplot);
        subplot(1,3,3)
        surf(reshape(xplot(:,1),Nplot,Nplot),reshape(xplot(:,2),Nplot,Nplot),reshape(pplot,Nplot,Nplot))
        title('Surrogate PDF')
    case 3
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%% Below is a 4D example for creating an EDF response surface
        %%% This example uses data distributed from the carsmall data set
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        % Load, clean and scale the data
        load carsmall
        xdirty = [Acceleration Displacement Horsepower Weight];
        xstr = {'Acceleration','Displacement','Horsepower','Weight'};
        ydirty = MPG;
        [x,y,shift,scale] = rescale_data(xdirty,ydirty);
        x_mean = mean(x);
        
        % Try to compute a 2D density over acceleration and horsepower
        xAD = x(:,1:2);
        NAD = size(xAD,1);
        N2d = 35;
        x2d = pick2Dpoints([-1 -1],[1 1],N2d*[1;1]);
        % Sorting may be useful but I haven't figured out why yet
        [c,i] = sort(sum(x2d - ones(N2d^2,1)*[-1,-1],2));
        x2d_sorted = x2d(i,:);
        [c,i] = sort(sum(xAD - ones(NAD,1)*[-1,-1],2));
        xAD_sorted = xAD(i,:);
        h_scatter = figure;
        scatter(xAD_sorted(:,1),xAD_sorted(:,2),exp(3*c))
        ecdf2d = zeros(N2d^2,1);
        for k=1:N2d^2
            ecdf2d(k) = sum(all(xAD<=repmat(x2d(k,:),NAD,1),2))/NAD;
        end
        h_ecdf = figure;
        surf(reshape(x2d(:,1),N2d,N2d),reshape(x2d(:,2),N2d,N2d),reshape(ecdf2d,N2d,N2d))
        
        rbf = rbfM6;
        rbfdxdy = rbfM6dxdy;
        
        ep = [3,3];
        mu = 1e-3;
        K_cdf = rbf(DistanceMatrix(x2d,x2d,ep));
        cdf2d_coef = (K_cdf+mu*eye(N2d^2))\ecdf2d;
        cdf2d_eval = @(xx) rbf(DistanceMatrix(xx,x2d,ep))*cdf2d_coef;
        pdf2d_eval = @(xx) max(rbfdxdy(DistanceMatrix(xx,x2d,ep),DifferenceMatrix(xx(:,1),x2d(:,1)),...
            DifferenceMatrix(xx(:,2),x2d(:,2)),ep)*cdf2d_coef,0);
        Neval = 50;
        x2d_eval = pick2Dpoints([-1 -1],[1 1],Neval*[1;1]);
        y_eval = cdf2d_eval(x2d_eval);
        surf(reshape(x2d_eval(:,1),Neval,Neval),reshape(x2d_eval(:,2),Neval,Neval),reshape(y_eval,Neval,Neval))
        y_eval = pdf2d_eval(x2d_eval);
        surf(reshape(x2d_eval(:,1),Neval,Neval),reshape(x2d_eval(:,2),Neval,Neval),reshape(y_eval,Neval,Neval))
    case 4
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        %%% Below is a convergence test on 1D data
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        
        % Choose whether or not to display plots
        plots_on = 'on';
                
        % Choose an RBF to work with
        rbf = rbfM2;
        rbfdx = rbfM2dx;
        
        % Choose generalized pareto parameters
        gp_k = -1/2;
        gp_sigma = 1;
        gp_theta = 0;
        
        % Test over a range of points, and several experiments per point
        Nvec = floor(logspace(1,3,16));
        Nexp = 30;
        
        % Choose points at which to test the error
        NN = 200;
        xx = pickpoints(0,2,NN);
        cdf_true = cdf('gp',xx,gp_k,gp_sigma,gp_theta);
        pdf_true = pdf('gp',xx,gp_k,gp_sigma,gp_theta);
        
        cerrmat = zeros(Nexp,length(Nvec));
        perrmat = zeros(Nexp,length(Nvec));
        if strcmp(plots_on,'on')
            h_waitbar = waitbar(0,'Initializing','Visible',plots_on);
        end
        i = 1;
        for N=Nvec
            if strcmp(plots_on,'on')
                waitbar(0,h_waitbar,sprintf('N=%d',N));
            end
            j = 1;
            for Ne=1:Nexp
                % Create some random samples from a generalized pareto
                x = sort(icdf('gp',rand(N,1),gp_k,gp_sigma,gp_theta));
                
                % Evaluate the EDF at the given points
                y = Fhat(x,x);
                
                % We need to perform cross-validation to find the optimal
                % epsilon and mu values
                % Choose a set of cross-validation indices
                % We'll hard-wire leave 1/4 out and reevaluate later
                % We also need to think about the initial guess ...
                cvind = {1:4:N,2:4:N,3:4:N,4:4:N};
                optim_opt.Display = 'off';
                warning off
                epmu_opt = fminunc(@(epmu)SurrModel4_CV(exp(epmu),rbf,x,y,cvind),log([1;1e-5]),optim_opt);
                warning on
                ep = exp(epmu_opt(1));
                mu = exp(epmu_opt(2));
                
                % Create the surrogate model
                K_cdf = rbf(DistanceMatrix(x,x,ep));
                cdf_coef = (K_cdf+mu*eye(N))\y;
                cdf_eval = @(xeval) rbf(DistanceMatrix(xeval,x,ep))*cdf_coef;
                pdf_eval = @(xeval) rbfdx(DistanceMatrix(xeval,x,ep),DifferenceMatrix(xeval,x),ep)*cdf_coef;
                
                % Evaluate the error in the cdf and pdf
                cerrmat(j,i) = errcompute(cdf_eval(xx),cdf_true);
                perrmat(j,i) = errcompute(pdf_eval(xx),pdf_true);
                
                if strcmp(plots_on,'on')
                    progress = floor(100*Ne/Nexp)/100;
                    waitbar(progress,h_waitbar,sprintf('N=%d, Exp #%d',N,Ne));
                else
                    fprintf('%d\t%d\n',i,j)
                end
                j = j + 1;
            end
            pause
            i = i + 1;
        end
        if strcmp(plots_on,'on')
            close(h_waitbar)
        end
        
        % Average the errors computed to smooth out randomness
        cerrvec = mean(cerrmat);
        perrvec = mean(perrmat);
        
        % Compute the slopes of the convergence behaviors
        polyfit_cdf = polyfit(log(Nvec),log(cerrvec),1);
        polyfit_pdf = polyfit(log(Nvec),log(perrvec),1);
        
        % Plot the convergence and display the slopes
        h = figure('Visible',plots_on);
        loglog(Nvec,cerrvec,'linewidth',3);
        hold on
        loglog(Nvec,perrvec,'r','linewidth',3);
        hold off
        title(sprintf('ep=%g, mu=%g',ep,mu))
        legend(sprintf('CDF, slope=%3.2f',polyfit_cdf(1)),...
               sprintf('PDF, slope=%3.2f',polyfit_pdf(1)))
        if ~strcmp(plots_on,'on')
            gqr_savefig(h,sprintf('SurrModelEDFtest'));
            plot_command = 'loglog(Nvec,[cerrvec,perrvec])';
            save('SurrModelEDFtest','Nvec','cerrvec','perrvec','cerrmat','perrmat','plot_command');
        end
    otherwise
        error('No such example exists')
end
