function FitMultiStateSMA


% data1 = [time data] 1st col = time, 2nd col = data
    load('dataset1'); load('model1'); % dataset 1 

%% Fitting variables 
    params = [{'SPRSMA_KA1'}, {'SPRSMA_KD1'}, {'SPRSMA_NU1'}, {'SPRSMA_SIGMA1'},...
        {'SPRSMA_KA2'}, {'SPRSMA_KD2'}, {'SPRSMA_NU2'}, {'SPRSMA_SIGMA2'}, ...
        {'SPRSMA_K12'}, {'SPRSMA_K21'}];%
    comps = [2 2 2 2 2 2 2 2 2 2];
    secs = -ones(1,length(comps)); 

    fitData = cell(1,1);

    fit = [];
    fit.idxComp = [2]; 
    fit.outMeas = data1(:,2); % data
    fit.tOut = data1(:,1); % time
    fit.sim = createModel(fit.tOut,model1);
    fitData{1} = fit;

    % Set parameters for all simulators
    for i = 1:length(fitData)
        fitData{i}.sim.setParameters(params, comps, secs, true(length(params), 1)); % optimiztion variables  ... true: auch ableitungen berechnen
        fitData{i}.task = fitData{i}.sim.prepareSimulation(); % setting for faster calculation
    end
    
    % Fit the data
    quietMode = false;      % Disable quiet mode
    loBound   = [];%
    upBound   = [];%
    
    initParams = [1 1 1 1 1 1 1 1 1 1];%
    logScale = false(length(initParams), 1); % Enable log scaling
 
    opt = getOpts(initParams);
    opt.nObserv = length(fit.tOut);
    
    [params, residual] = fitColumn(fitData, initParams, loBound, upBound, logScale,[], quietMode, opt);
end

function data = generateArtificialData(fit)

result = fit.sim.simulate();
data = result.solution.outlet(:,2:end);
end

function [sim] = createModel(tOut,inletmodel)
%LOADWASHELUTIONSPREADING Simple Load-Wash-Elution cycle with 4 component Spreading SMA

    model = ModelGRM();
    
  % General
    model.nComponents = (inletmodel.nComponents/2 -1)*2 +1; % 1 (Salt) + 2 * nRealComponents

  % Initial conditions
	model.initialMobileConcentration = [inletmodel.initialMobileConcentration(1),0,0];
    model.initialSolidConcentration = 2*[inletmodel.initialSolidConcentration(1),0,0];

    
    % Adsorption
    model.kineticBindingModel = true;
    model.bindingModel = SpreadingStericMassActionBinding();
    model.bindingParameters.SPRSMA_LAMBDA      = 2*inletmodel.bindingParameters.BISMA_LAMBDA1 ;
    model.bindingParameters.SPRSMA_KA1         = [0 0];
    model.bindingParameters.SPRSMA_KD1         = [0 1e-30];
    model.bindingParameters.SPRSMA_NU1         = [0 8.76];
    model.bindingParameters.SPRSMA_SIGMA1      = [0 0.0];
    
    model.bindingParameters.SPRSMA_KA2         = [0 0];
    model.bindingParameters.SPRSMA_KD2         = [0 0];
    model.bindingParameters.SPRSMA_NU2         = [0 43.067];
    model.bindingParameters.SPRSMA_SIGMA2      = [0 21.6888];
    model.bindingParameters.SPRSMA_K12         = [0.0 0];
    model.bindingParameters.SPRSMA_K21         = [0.0 0]; 

    % Transport
    model.dispersionColumn          = inletmodel.dispersionColumn;
    model.filmDiffusion             = [inletmodel.filmDiffusion(1) inletmodel.filmDiffusion(2) inletmodel.filmDiffusion(2)]; 
    model.diffusionParticle         = [inletmodel.diffusionParticle(1) inletmodel.diffusionParticle(2) inletmodel.diffusionParticle(2)];
    model.diffusionParticleSurface  = [inletmodel.diffusionParticleSurface(1) inletmodel.diffusionParticleSurface(2) inletmodel.diffusionParticleSurface(2)];
    model.interstitialVelocity      = inletmodel.interstitialVelocity(1);

    % Geometry
    model.columnLength        = inletmodel.columnLength;
    model.particleRadius      = inletmodel.particleRadius;
    model.porosityColumn      = inletmodel.porosityColumn;
    model.porosityParticle    = inletmodel.porosityParticle;
    
    % Inlet
    model.nInletSections = inletmodel.nInletSections;
    model.sectionTimes = [inletmodel.sectionTimes(1:end-1)',tOut(end)];
    model.sectionContinuity = inletmodel.sectionContinuity';
    
    model.sectionConstant       = zeros(model.nComponents, model.nInletSections);
    model.sectionLinear         = zeros(model.nComponents, model.nInletSections);
    model.sectionQuadratic      = zeros(model.nComponents, model.nInletSections);
    model.sectionCubic          = zeros(model.nComponents, model.nInletSections);

    % Sec 1
    model.sectionConstant(1,1)  = inletmodel.sectionConstant(1,1);  % Salt component
    model.sectionConstant(2:(model.nComponents-1)/2+1,1)  = inletmodel.sectionConstant(2,1); % First half of components 
                                                                 % (i.e., "real components")
    % Sec 2
    model.sectionConstant(1,2)  = inletmodel.sectionConstant(1,2);  % Salt component

    % Sec 3
    model.sectionConstant(1,3)  = inletmodel.sectionConstant(1,3);  % Salt component
    model.sectionLinear  (1,3)  = inletmodel.sectionLinear(1,3);   % Salt component

    % Discretization
    disc = DiscretizationGRM();
    disc.nCellsColumn   = 30;
    disc.nCellsParticle = 4;
    % Simulator
    sim = Simulator(model, disc);
    sim.solutionTimes = tOut;
    sim.solverOptions.time_integrator.MAX_STEPS = 100000;
    sim.nThreads = 4;
end

function opt = getOpts(initParams)

    opt.initParams        = initParams;
    opt.nCol              = length(initParams);
    opt.nsamples          = 10000; 
    opt.bounds            = [10  1  6 1e-7 1000  1  45  8  1e-2 1e-20; 
                             14  2  8 1    2000  2  50  14 1e30 1e2];
    opt.idxParam          = [1, 5];
    opt.idxConst          = [3, 7];
    opt.burnin            = 500;
    opt.printint          = 100;
    opt.convergint        = 200;
    opt.Swapint           = 100;
    opt.iterMax           = 1000000;
    
    opt.temperature       = [1];
    opt.Nchain            = length(opt.temperature);
    opt.epsilon           = 0.15;
    opt.iterationNum      = 0;
    opt.accepted          = 0;
    opt.continueIteration = true;
    opt.converged         = false;
    opt.saveMetricTensor  = true;

    if fix(opt.nsamples/opt.convergint) ~= opt.nsamples/opt.convergint
        error('please let the number of samples devided by the index of convergence diagnostics');
    end
    
end
% =============================================================================
%  CADET - The Chromatography Analysis and Design Toolkit
%  
%  Copyright © 2008-2014: Eric von Lieres¹, Joel Andersson,
%                         Andreas Puettmann¹, Sebastian Schnittert¹,
%                         Samuel Leweke¹
%                                      
%    ¹ Forschungszentrum Juelich GmbH, IBG-1, Juelich, Germany.
%  
%  All rights reserved. This program and the accompanying materials
%  are made available under the terms of the GNU Public License v3.0 (or, at
%  your option, any later version) which accompanies this distribution, and
%  is available at http://www.gnu.org/licenses/gpl.html
% =============================================================================
