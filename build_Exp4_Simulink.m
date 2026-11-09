%% build_Exp4_Simulink.m
% Experiment 4 : Economic Load Dispatch of a home energy system
%                Hopfield neural network vs Lambda-iteration
% Builds Exp4_Home_ELD_Hopfield_vs_Lambda.slx, runs it, exports the model
% image and all report graphs to ./Exp4_Simulink/figures, and prints measured
% vs expected (Table 4.3) readings.
%
% Requires: MATLAB R2018b+ and Simulink (no other toolbox).
% Run from the working folder:   >> build_Exp4_Simulink
%
% Model idea: one Simulink time step = one hour (Ts = 1 s, 24 steps).
%   Demand / PV limit / battery limit  -> Repeating Sequence Stair blocks
%   Lambda_Iteration  (MATLAB Function) -> P1..P4, lambda, iterations, cost, dP
%   Hopfield_NN       (MATLAB Function) -> P1..P4, iterations, cost, dP
%   Scopes + To Workspace logging for every result.

clc; close all;
mdl    = 'Exp4_Home_ELD_Hopfield_vs_Lambda';
outDir = fullfile(pwd,'Exp4_Simulink');
figDir = fullfile(outDir,'figures');
if ~exist(figDir,'dir'), mkdir(figDir); end
addpath(outDir);

%% 1. Data (Table 4.1 and the report's load / PV profile)
names = {'Solar PV','Battery','Grid','DG set'};
a = [0 0 0 0];  b = [0.5 3.0 6.0 25.0];  c = [0.02 0.40 0.30 1.00];
Pmin  = [0 0 0 0];
PmaxR = [3.0 1.5 3.0 3.0];                    % PV kWp, battery, grid, DG (kW)
hrs   = 1:24;
base  = [1.2 1.0 0.9 0.9 1.0 1.6 2.8 3.4 2.9 2.4 2.3 2.6 ...
         3.1 3.3 3.0 2.7 2.9 3.8 5.2 6.4 6.8 6.0 4.2 2.2];
load_kW = round(0.7*base,2);
pv      = round(max(3.0*sin(pi*(hrs-6.5)/13),0)*0.92,2);
battWin = (hrs>=18) & (hrs<=23);
battLim = PmaxR(2)*double(battWin);

assignin('base','Exp4_load',   load_kW);
assignin('base','Exp4_pv',     pv);
assignin('base','Exp4_battlim',battLim);

%% 2. Create the model
if bdIsLoaded(mdl), close_system(mdl,0); end
slxFile = fullfile(outDir,[mdl '.slx']);
if exist(slxFile,'file'), delete(slxFile); end
new_system(mdl);  open_system(mdl);
set_param(mdl,'Solver','FixedStepDiscrete','FixedStep','1','StartTime','0','StopTime','23');

lib.stair = 'simulink/Sources/Repeating Sequence Stair';
lib.mux   = 'simulink/Signal Routing/Mux';
lib.goto  = 'simulink/Signal Routing/Goto';
lib.from  = 'simulink/Signal Routing/From';

% ---- inputs: one value per hour ----
addb(mdl,lib.stair,'Demand_kW',        [30  60 130  90]);   setp([mdl '/Demand_kW'],'OutValues','Exp4_load');    setp([mdl '/Demand_kW'],{'SampleTime','tsamp'},'1');
addb(mdl,lib.stair,'PV_Available_kW',  [30 150 130 180]);   setp([mdl '/PV_Available_kW'],'OutValues','Exp4_pv');  setp([mdl '/PV_Available_kW'],{'SampleTime','tsamp'},'1');
addb(mdl,lib.stair,'Battery_Limit_kW', [30 240 130 270]);   setp([mdl '/Battery_Limit_kW'],'OutValues','Exp4_battlim'); setp([mdl '/Battery_Limit_kW'],{'SampleTime','tsamp'},'1');
addb(mdl,lib.goto,'Goto_PD',    [160  65 220  85],'GotoTag','PD',    'ShowName','off');
addb(mdl,lib.goto,'Goto_PVmax', [160 155 220 175],'GotoTag','PVmax', 'ShowName','off');
addb(mdl,lib.goto,'Goto_BATmax',[160 245 220 265],'GotoTag','BATmax','ShowName','off');
addb(mdl,lib.from,'From_PD_L',    [250  40 310  60],'GotoTag','PD',    'ShowName','off');
addb(mdl,lib.from,'From_PV_L',    [250  90 310 110],'GotoTag','PVmax', 'ShowName','off');
addb(mdl,lib.from,'From_BAT_L',   [250 140 310 160],'GotoTag','BATmax','ShowName','off');
addb(mdl,lib.from,'From_PD_H',    [250 350 310 370],'GotoTag','PD',    'ShowName','off');
addb(mdl,lib.from,'From_PV_H',    [250 400 310 420],'GotoTag','PVmax', 'ShowName','off');
addb(mdl,lib.from,'From_BAT_H',   [250 450 310 470],'GotoTag','BATmax','ShowName','off');
ln(mdl,'Demand_kW/1','Goto_PD/1');
ln(mdl,'PV_Available_kW/1','Goto_PVmax/1');
ln(mdl,'Battery_Limit_kW/1','Goto_BATmax/1');

% ---- the two solvers (MATLAB Function blocks) ----
addMLFunction(mdl,'Lambda_Iteration',[350  30 500 290],lambdaCode(),3,8);
addMLFunction(mdl,'Hopfield_NN',     [350 330 500 540],hopfieldCode(),3,7);
for s = {'L','H'}
    ln(mdl,['From_PD_'  s{1} '/1'],[solverName(s{1}) '/1']);
    ln(mdl,['From_PV_'  s{1} '/1'],[solverName(s{1}) '/2']);
    ln(mdl,['From_BAT_' s{1} '/1'],[solverName(s{1}) '/3']);
end

% ---- outputs -> Goto tags ----
Ltags = {'L_P1','L_P2','L_P3','L_P4','L_lam','L_it','L_cost','L_dP'};
Htags = {'H_P1','H_P2','H_P3','H_P4','H_it','H_cost','H_dP'};
gotoOutputs(mdl,lib,'Lambda_Iteration',Ltags,30,260);
gotoOutputs(mdl,lib,'Hopfield_NN',     Htags,330,210);

% ---- logging ----
addLogger(mdl,lib,{'PD','PVmax','BATmax'},'Mux_log_in',  'log_in',     720,  30);
addLogger(mdl,lib,Ltags,                  'Mux_log_L',   'log_lambda', 720, 180);
addLogger(mdl,lib,Htags,                  'Mux_log_H',   'log_hnn',    720, 470);

% ---- scopes ----
addScope(mdl,lib,'Scope_Demand_PV',        {'PD','PVmax'},                1050,  30);
addScope(mdl,lib,'Scope_Dispatch_Lambda',  {'L_P1','L_P2','L_P3','L_P4'}, 1050, 130);
addScope(mdl,lib,'Scope_Dispatch_HNN',     {'H_P1','H_P2','H_P3','H_P4'}, 1050, 300);
addScope(mdl,lib,'Scope_Hourly_Cost',      {'L_cost','H_cost'},           1050, 470);
addScope(mdl,lib,'Scope_Lambda_Star',      {'L_lam'},                     1050, 570);
addScope(mdl,lib,'Scope_Iterations',       {'L_it','H_it'},               1050, 640);
addScope(mdl,lib,'Scope_HNN_Mismatch',     {'H_dP'},                      1050, 740);

note(mdl,'Experiment 4 - Home economic load dispatch (1 step = 1 hour)',[30 -40]);
note(mdl,'Lambda iteration',[120 5]);
note(mdl,'Hopfield neural network',[120 305]);

save_system(mdl,slxFile);
fprintf('Created %s\n',slxFile);

try
    set_param(mdl,'ZoomFactor','FitSystem');
    set_param(mdl,'PaperPositionMode','auto');
    print(['-s' mdl],'-dpng','-r300',fullfile(figDir,'model_top_level.png'));
    % close-up of the inputs and the two solver blocks (left part of the fixed layout)
    img = imread(fullfile(figDir,'model_top_level.png'));
    [hI,wI,~] = size(img);
    imwrite(img(1:round(0.75*hI),1:round(0.48*wI),:),fullfile(figDir,'model_solvers_closeup.png'));
catch ME
    warning('Model image export failed: %s',ME.message);
end

%% 3. Simulate and collect results
simOut = sim(mdl,'ReturnWorkspaceOutputs','on');
Sl = simOut.get('log_lambda');  Sh = simOut.get('log_hnn');
assert(size(Sl.Data,1)==24,'Expected 24 hourly samples, got %d',size(Sl.Data,1));
PL = Sl.Data(:,1:4);  lam = Sl.Data(:,5);  itL = Sl.Data(:,6);  cL = Sl.Data(:,7);  dPL = Sl.Data(:,8);
PH = Sh.Data(:,1:4);  itH = Sh.Data(:,5);  cH = Sh.Data(:,6);  dPH = Sh.Data(:,7);

T = table(hrs',load_kW',PL(:,1),PL(:,2),PL(:,3),PL(:,4),lam,cL,itL,cH,itH,1000*dPH, ...
    'VariableNames',{'Hour','PD','PV','Batt','Grid','DG','lambda','Cost_LI','It_LI','Cost_HNN','It_HNN','dP_HNN_W'});
disp(T);

%% 4. Offline replica of both algorithms (convergence histories + cross-check)
h = 21;  PD21 = load_kW(h);
Pmax21 = [pv(h) battLim(h) PmaxR(3) PmaxR(4)];
[V21,k21,histV,histE] = hnnRun(PD21,Pmax21,a,b,c,Pmin);
[P21,~,kL21,lamHist,misHist] = lamRun(PD21,Pmax21,b,c,Pmin);
fprintf('\nCross-check hour 21 (Simulink vs offline): max |dispatch diff| HNN = %.2e kW, LI = %.2e kW; iterations HNN %d vs %d, LI %d vs %d\n', ...
    max(abs(PH(h,:)-V21)),max(abs(PL(h,:)-P21)),itH(h),k21,itL(h),kL21);

%% 5. Report graphs
col = [0.95 0.72 0.02; 0.18 0.53 0.76; 0.49 0.24 0.60; 0.75 0.22 0.17];
cLI = [0.85 0.15 0.15];  cHN = [0 0.447 0.741];

f = figure('Color','w','Position',[100 100 900 420]); hold on; grid on;
area(hrs,pv,'FaceColor',col(1,:),'FaceAlpha',0.4,'EdgeColor','none');
bar(hrs(battWin),battLim(battWin),0.9,'FaceColor',col(2,:),'FaceAlpha',0.25,'EdgeColor','none');
plot(hrs,load_kW,'k-o','LineWidth',1.3,'MarkerSize',4);
yline(PmaxR(3),'--','Grid limit 3 kW','Color',col(3,:));
xlabel('Hour of day'); ylabel('Power (kW)'); xticks(hrs); xlim([0.5 24.5]);
title('24-hour load and solar availability');
legend('PV available P_{1,max}','Battery window (\leq1.5 kW)','Household load P_D','Location','northwest');
saveFig(f,fullfile(figDir,'fig4_3_load_pv_profile.png'));

f = figure('Color','w','Position',[100 100 950 400]);
subplot(1,2,1); hold on; grid on;
for i = 1:4, xm = linspace(0,PmaxR(i),100); plot(xm,a(i)+b(i)*xm+c(i)*xm.^2,'Color',col(i,:),'LineWidth',1.8); end
xlabel('P_i (kW)'); ylabel('Cost (Rs/h)'); title('Cost functions F_i(P_i)'); legend(names,'Location','northwest');
subplot(1,2,2); hold on; grid on;
for i = 1:4, xm = linspace(0,PmaxR(i),100); plot(xm,b(i)+2*c(i)*xm,'Color',col(i,:),'LineWidth',1.8); end
xlabel('P_i (kW)'); ylabel('Rs/kWh'); title('Incremental cost dF_i/dP_i'); legend(names,'Location','southeast');
saveFig(f,fullfile(figDir,'fig4_4_cost_curves.png'));

f = figure('Color','w','Position',[100 100 1000 420]);
it = (1:size(histV,1))';
subplot(1,2,1); hold on; grid on;
for i = 1:4, semilogx(it,histV(:,i),'Color',col(i,:),'LineWidth',1.6); end
semilogx(it,sum(histV,2),'k--','LineWidth',1.2); yline(PD21,':','Color',[.5 .5 .5]);
set(gca,'XScale','log'); xlabel('Iteration'); ylabel('Neuron output V_i (kW)');
title(sprintf('HNN outputs, hour 21 (P_D = %.2f kW)',PD21)); legend([names {'\SigmaP_i'}],'Location','best');
subplot(1,2,2); loglog(it,histE,'Color',cHN,'LineWidth',1.6); grid on;
xlabel('Iteration'); ylabel('Energy E'); title(sprintf('Energy function (converged in %d iterations)',k21));
saveFig(f,fullfile(figDir,'fig4_5_hnn_convergence.png'));

f = figure('Color','w','Position',[100 100 1000 380]);
subplot(1,2,1); plot(1:numel(lamHist),lamHist,'o-','Color',cLI,'LineWidth',1.5,'MarkerFaceColor',cLI); grid on;
xlabel('Iteration'); ylabel('\lambda (Rs/kWh)'); title('\lambda-iteration: \lambda, hour 21');
subplot(1,2,2); semilogy(1:numel(misHist),max(abs(misHist),1e-12),'s-','Color',cLI,'LineWidth',1.5,'MarkerFaceColor',cLI); grid on;
xlabel('Iteration'); ylabel('|\DeltaP| (kW)'); title('Power mismatch');
saveFig(f,fullfile(figDir,'fig4_6_lambda_convergence.png'));

f = figure('Color','w','Position',[100 100 950 700]);
for s = 1:2
    subplot(2,1,s); M = {PL,PH};  bb = bar(hrs,M{s},'stacked'); hold on; grid on;
    for i = 1:4, bb(i).FaceColor = col(i,:); end
    plot(hrs,load_kW,'k.-','LineWidth',1.2); ylabel('Power (kW)'); ylim([0 5.4]); xticks(hrs);
    ttl = {'(a) Lambda-iteration','(b) Hopfield neural network'};  title(ttl{s});
    if s==1, legend([names {'Load'}],'Orientation','horizontal','Location','north'); else, xlabel('Hour of day'); end
end
saveFig(f,fullfile(figDir,'fig4_7_dispatch.png'));

f = figure('Color','w','Position',[100 100 950 780]);
subplot(3,1,1); bar(hrs,[cL cH]); grid on; ylabel('Cost (Rs/h)'); title('Hourly operating cost'); legend('\lambda-iteration','HNN','Location','northwest'); xticks(hrs);
subplot(3,1,2); stairs(hrs,lam,'Color',[0.5 0.24 0.6],'LineWidth',1.5); grid on; ylabel('\lambda (Rs/kWh)'); title('System incremental cost \lambda^*'); xticks(hrs);
subplot(3,1,3); bar(hrs,1000*dPH,'FaceColor',cHN); grid on; ylabel('\DeltaP (W)'); xlabel('Hour of day'); xticks(hrs);
title('HNN power-balance mismatch (\lambda-iteration < 10^{-3} W)');
saveFig(f,fullfile(figDir,'fig4_8_cost_lambda_mismatch.png'));

f = figure('Color','w','Position',[100 100 1000 400]);
subplot(1,2,1); bar(hrs,[itL itH]); set(gca,'YScale','log'); grid on; xlabel('Hour'); ylabel('Iterations (log)');
title('Iterations to converge'); legend('\lambda-iteration','HNN','Location','northwest');
subplot(1,2,2); bar(1:4,[sum(PL,1)' sum(PH,1)']); xticks(1:4); xticklabels(names); grid on;
ylabel('Energy (kWh/day)'); ylim([0 30]); title('Daily energy share per source'); legend('\lambda-iteration','HNN');
saveFig(f,fullfile(figDir,'fig4_9_comparison.png'));

%% 6. Readings: measured (this Simulink model) vs expected (report Table 4.3)
costL = sum(cL);  costH = sum(cH);  costHc = costH + sum(lam.*dPH);
EL = sum(PL,1);   EH = sum(PH,1);
rows = {
 'LI daily cost (Rs)',            costL,             195.14, 0.05
 'HNN raw daily cost (Rs)',       costH,             194.82, 0.05
 'HNN cost at lambda* (Rs)',      costHc,            195.16, 0.05
 'LI max mismatch (W)',           1000*max(abs(dPL)),0.00,   0.0011
 'HNN max mismatch (W)',          1000*max(abs(dPH)),6.38,   0.10
 'LI iterations mean',            mean(itL),         6.4,    0.10
 'LI iterations min',             min(itL),          4,      0
 'LI iterations max',             max(itL),          10,     0
 'HNN iterations mean',           mean(itH),         14089,  150
 'HNN iterations min',            min(itH),          3564,   40
 'HNN iterations max',            max(itH),          47171,  470
 'LI energy PV (kWh)',            EL(1),             19.34,  0.02
 'LI energy Battery (kWh)',       EL(2),             9.00,   0.02
 'LI energy Grid (kWh)',          EL(3),             22.22,  0.02
 'LI energy DG (kWh)',            EL(4),             0.26,   0.02
 'HNN energy Grid (kWh)',         EH(3),             22.20,  0.02
 'HNN energy DG (kWh)',           EH(4),             0.25,   0.02
 'LI lambda* at hour 21 (Rs/kWh)',lam(21),           25.52,  0.02 };
fprintf('\n===== Measured (this Simulink model) vs expected (Table 4.3) =====\n');
for r = 1:size(rows,1)
    ok = abs(rows{r,2}-rows{r,3}) <= rows{r,4};
    fprintf('  %-32s measured %10.3f | expected %10.3f | %s\n',rows{r,1},rows{r,2},rows{r,3},ternary(ok,'OK','CHECK'));
end
fprintf('\nFiles written to %s\n',outDir);

%% ---------------- local functions ----------------
function n = solverName(s)
    if s=='L', n = 'Lambda_Iteration'; else, n = 'Hopfield_NN'; end
end
function addb(mdl,lib,name,pos,varargin)
    add_block(lib,[mdl '/' name],'Position',pos,varargin{:});
end
function ln(mdl,src,dst)
    add_line(mdl,src,dst,'autorouting','smart');
end
function setp(blk,names,val)
    if ischar(names), names = {names}; end
    dp = get_param(blk,'DialogParameters');
    for i = 1:numel(names)
        if isstruct(dp) && isfield(dp,names{i}), set_param(blk,names{i},val); return; end
    end
    warning('%s: none of {%s} is a dialog parameter.',blk,strjoin(names,','));
end
function addMLFunction(mdl,name,pos,codeLines,nIn,nOut)
    blk = [mdl '/' name];
    add_block('simulink/User-Defined Functions/MATLAB Function',blk,'Position',pos);
    rt = sfroot;
    ch = rt.find('-isa','Stateflow.EMChart','Path',blk);
    if isempty(ch), error('Cannot access the MATLAB Function block %s.',name); end
    ch(1).Script = strjoin(codeLines,newline);
    ph = get_param(blk,'PortHandles');
    if numel(ph.Inport)~=nIn || numel(ph.Outport)~=nOut
        try, set_param(mdl,'SimulationCommand','update'); catch, end
        ph = get_param(blk,'PortHandles');
    end
    if numel(ph.Inport)~=nIn || numel(ph.Outport)~=nOut
        error('%s has %d inputs / %d outputs, expected %d / %d. Open the block once and re-run.', ...
            name,numel(ph.Inport),numel(ph.Outport),nIn,nOut);
    end
end
function gotoOutputs(mdl,lib,solver,tags,y0,h)
    n = numel(tags);
    for i = 1:n
        gn = ['Goto_' tags{i}];
        yc = y0 + round((i-0.5)*h/n);
        addb(mdl,lib.goto,gn,[540 yc-8 600 yc+8],'GotoTag',tags{i},'ShowName','off');
        ln(mdl,[solver '/' num2str(i)],[gn '/1']);
    end
end
function addLogger(mdl,lib,tags,muxName,wsName,x,y)
    n = numel(tags);
    addb(mdl,lib.mux,muxName,[x+90 y x+96 y+22*n],'Inputs',num2str(n));
    for i = 1:n
        fn = sprintf('%s_from%d',wsName,i);
        addb(mdl,lib.from,fn,[x y+22*(i-1) x+60 y+22*(i-1)+16],'GotoTag',tags{i},'ShowName','off');
        ln(mdl,[fn '/1'],[muxName '/' num2str(i)]);
    end
    addb(mdl,'simulink/Sinks/To Workspace',wsName, ...
        [x+140 y+round(11*n)-15 x+230 y+round(11*n)+15],'VariableName',wsName,'SaveFormat','Timeseries');
    setp([mdl '/' wsName],'SampleTime','1');
    ln(mdl,[muxName '/1'],[wsName '/1']);
end
function addScope(mdl,lib,name,tags,x,y)
    n = numel(tags);
    addb(mdl,'simulink/Sinks/Scope',name,[x+110 y x+150 y+max(30,22*n)]);
    try, set_param([mdl '/' name],'NumInputPorts',num2str(n)); catch, end
    for i = 1:n
        fn = sprintf('%s_from%d',name,i);
        addb(mdl,lib.from,fn,[x y+22*(i-1) x+60 y+22*(i-1)+16],'GotoTag',tags{i},'ShowName','off');
        ln(mdl,[fn '/1'],[name '/' num2str(i)]);
    end
end
function note(mdl,txt,pos)
    try
        an = Simulink.Annotation(mdl,txt);  an.Position = pos;  an.FontSize = 14;  an.FontWeight = 'bold';
    catch
    end
end
function saveFig(fig,file)
    try, exportgraphics(fig,file,'Resolution',300);
    catch, print(fig,file,'-dpng','-r300'); end
end
function s = ternary(c,x,y)
    if c, s = x; else, s = y; end
end

% ---- offline replicas of the two algorithms (same maths as the blocks) ----
function [P,L,k,hist,mis] = lamRun(PD,Pmax,b,c,Pmin)
    lo = min(b+2*c.*Pmin);  hi = max(b+2*c.*Pmax);  L = (lo+hi)/2;
    hist = L;  mis = [];
    for k = 1:100
        P = min(max((L-b)./(2*c),Pmin),Pmax);
        d = PD-sum(P);  mis(end+1) = d; %#ok<AGROW>
        if abs(d) < 1e-6, break; end
        if d > 0, lo = L; else, hi = L; end
        free = (P > Pmin+1e-12) & (P < Pmax-1e-12);
        if any(free), Ln = L + d/sum(1./(2*c(free))); else, Ln = Inf; end
        if Ln > lo && Ln < hi, L = Ln; else, L = (lo+hi)/2; end
        hist(end+1) = L; %#ok<AGROW>
    end
end
function [V,k,histV,histE] = hnnRun(PD,Pmax,a,b,c,Pmin)
    A = 1; B = 5e-4; u0 = 1; tol = 1e-7; maxit = 1e5;
    rg = max(Pmax-Pmin,1e-9);  eta = 0.9/(A*sum(rg)/(2*u0));
    U = zeros(1,4);  V = Pmin+0.5*rg;
    histV = zeros(maxit,4);  histE = zeros(maxit,1);
    for k = 1:maxit
        g  = -A*(PD-sum(V)) + (B/2)*(b+2*c.*V);
        U  = U - eta*g;
        Vn = Pmin + 0.5*rg.*(1+tanh(U/u0));
        histV(k,:) = Vn;
        histE(k)   = 0.5*A*(PD-sum(Vn))^2 + 0.5*B*sum(a+b.*Vn+c.*Vn.^2);
        if max(abs(Vn-V)) < tol, V = Vn; break; end
        V = Vn;
    end
    histV = histV(1:k,:);  histE = histE(1:k);
end

% ---- code placed inside the two MATLAB Function blocks ----
function code = lambdaCode()
code = {
'function [P1,P2,P3,P4,lam,it,cost,dP] = ELD_Lambda(PD,PmaxPV,PmaxBat)'
'% Lambda-iteration economic dispatch for one hour'
'b = [0.5 3 6 25];  c = [0.02 0.4 0.3 1];  Pmin = [0 0 0 0];'
'Pmax = [PmaxPV PmaxBat 3 3];'
'tol = 1e-6;  maxit = 100;'
'lo = min(b + 2*c.*Pmin);  hi = max(b + 2*c.*Pmax);  L = (lo+hi)/2;'
'P = zeros(1,4);  k = 0;'
'for k = 1:maxit'
'    P = min(max((L-b)./(2*c),Pmin),Pmax);'
'    d = PD - sum(P);'
'    if abs(d) < tol'
'        break'
'    end'
'    if d > 0'
'        lo = L;'
'    else'
'        hi = L;'
'    end'
'    free = (P > Pmin+1e-12) & (P < Pmax-1e-12);'
'    if any(free)'
'        Ln = L + d/sum(1./(2*c(free)));'
'    else'
'        Ln = Inf;'
'    end'
'    if Ln > lo && Ln < hi'
'        L = Ln;'
'    else'
'        L = (lo+hi)/2;'
'    end'
'end'
'P1 = P(1);  P2 = P(2);  P3 = P(3);  P4 = P(4);'
'lam = L;  it = k;'
'cost = sum(b.*P + c.*P.^2);'
'dP = PD - sum(P);'
'end'
};
end
function code = hopfieldCode()
code = {
'function [P1,P2,P3,P4,it,cost,dP] = ELD_Hopfield(PD,PmaxPV,PmaxBat)'
'% Hopfield neural-network economic dispatch for one hour'
'b = [0.5 3 6 25];  c = [0.02 0.4 0.3 1];  Pmin = [0 0 0 0];'
'Pmax = [PmaxPV PmaxBat 3 3];'
'A = 1;  B = 5e-4;  u0 = 1;  tol = 1e-7;  maxit = 100000;'
'rg  = max(Pmax-Pmin,1e-9);'
'eta = 0.9/(A*sum(rg)/(2*u0));'
'U = zeros(1,4);  V = Pmin + 0.5*rg;  q = 0;'
'for q = 1:maxit'
'    g  = -A*(PD-sum(V)) + (B/2)*(b + 2*c.*V);'
'    U  = U - eta*g;'
'    Vn = Pmin + 0.5*rg.*(1+tanh(U/u0));'
'    if max(abs(Vn-V)) < tol'
'        V = Vn;'
'        break'
'    end'
'    V = Vn;'
'end'
'P1 = V(1);  P2 = V(2);  P3 = V(3);  P4 = V(4);'
'it = q;'
'cost = sum(b.*V + c.*V.^2);'
'dP = PD - sum(V);'
'end'
};
end
