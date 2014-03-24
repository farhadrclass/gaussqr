% Initial example for support-vector machines
if exist('rng','builtin')
    rng(0);
else
    rand('state',0);
    randn('state',0);
end

% Define our Gaussian RBF
rbf = @(e,r) exp(-(e*r).^2);
ep = 1;

% Define our normal distributions
grnmean = [1,0];
redmean = [0,1];
grncov = eye(2);
redcov = eye(2);

% How many points of each model do we want to classify and learn from
grn_test_N = 10;
red_test_N = 10;
grn_train_N = 100;
red_train_N = 100;

% How much fudge factor do we want in our training set
grn_buffer = .2;
red_buffer = .2;

% Whether or not the user wants the results plotted
plot_results = 1;

% Generate some manufactured data and attempt to classify it
% The data will be generated by normal distributions with different means
% Half of the data will come from [1,0] and half from [0,1]
grnpop = mvnrnd(grnmean,grncov,grn_test_N);
redpop = mvnrnd(redmean,redcov,red_test_N);

% Generate a training set from which to learn the classifier
grnpts = zeros(grn_train_N,2);
redpts = zeros(red_train_N,2);
for i = 1:grn_train_N
    grnpts(i,:) = mvnrnd(grnpop(ceil(rand*grn_test_N),:),grncov*grn_buffer);
end
for i = 1:red_train_N
    redpts(i,:) = mvnrnd(redpop(ceil(rand*red_test_N),:),redcov*red_buffer);
end

% Create a vector of data and associated classifications
% Green label 1, red label -1
train_data = [grnpts;redpts];
train_class = ones(grn_train_N+red_train_N,1);
train_class(grn_train_N+1:grn_train_N+red_train_N) = -1;
test_data = [grnpop;redpop];
test_class = ones(grn_test_N+red_test_N,1);
test_class(grn_test_N+1:grn_test_N+red_test_N) = -1;

% Design the necessary quadratic programming problem
box_constraint = .2;
DM = DistanceMatrix(train_data,train_data);
K = rbf(ep,DM);
H_QP = (train_class*train_class').*K;
H_QP = .5*(H_QP + H_QP'); % To make sure it symmetric at machine precision
f_QP = -ones(size(train_class)); % quadprog solves the min, not the max problem
A_QP = zeros(size(f_QP'));
b_QP = 0;
Aeq_QP = train_class';
beq_QP = 0;
lb_QP = zeros(size(train_class));
ub_QP = box_constraint*ones(size(train_class));
x0_QP = zeros(size(train_class));
optimopt_QP = optimset('LargeScale','off','Display','off','MaxIter',1000);

% Solve the quadratic program
[sol_QP,fval,exitflag,output] = quadprog(H_QP,f_QP,A_QP,b_QP,Aeq_QP,beq_QP,lb_QP,ub_QP,x0_QP,optimopt_QP);

% Create the coefficients and identify the support vectors
% A fudge factor is created to allow for slightly nonzero values
svm_fuzzy_logic = 1e-3;
svm_coef = train_class.*sol_QP;
support_vectors = sol_QP>svm_fuzzy_logic;

% To solve for b, we can just compute
%    b = y_i - sum_j=1^n alpha_i*y_i K(x_i,x_j)
% but only for i such that 0<alpha_i<C, not <=
% I take the mean of all such values, but they should all be the same
% NOTE: It's possible no such point will exist, maybe
bias_find_coef = find(sol_QP>svm_fuzzy_logic & sol_QP<1-svm_fuzzy_logic);
bias = mean(train_class(bias_find_coef) - K(bias_find_coef,:)*svm_coef);

% Create a function to evaluate the SVM
svm_eval = @(x) sign(rbf(ep,DistanceMatrix(x,train_data))*svm_coef + bias);

% Evaluate the classifications of the test data
% Separate the correct classifications from the incorrect classifications
predicted_class = svm_eval(test_data);
correct = predicted_class==test_class;
incorrect = predicted_class~=test_class;

% Plot the results, if requested
if plot_results
    plot(grnpop(:,1),grnpop(:,2),'g+','markersize',12)
    hold on
    plot(redpop(:,1),redpop(:,2),'rx','markersize',12)
    plot(test_data(correct,1),test_data(correct,2),'ob','markersize',12)
    plot(test_data(incorrect,1),test_data(incorrect,2),'oc','markersize',12,'linewidth',2)
    plot(grnmean(1),grnmean(2),'gh','linewidth',3)
    plot(redmean(1),redmean(2),'rh','linewidth',3)
    plot(grnpts(:,1),grnpts(:,2),'g.')
    plot(redpts(:,1),redpts(:,2),'r.')
    plot(train_data(support_vectors,1),train_data(support_vectors,2),'ok','markersize',3)
    hold off
end