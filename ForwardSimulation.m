function plotProfiles()
%PLOTPROFILES Simple Load-Wash-Elution cycle with 4 component SMA
%
% Parameters:
%   - gradientSlope: Optional. Slope of the gradient (default: 0.2)
%
% Copyright: © 2008-2015 Eric von Lieres, Joel Andersson, Andreas Püttmann, Sebastian Schnittert, Samuel Leweke
%            See the license note at the end of the file.
    load('dataset4'); load('model4'); % dataset 1 

    fit = [];
    fit.idxComp = [2]; 
    fit.outMeas = data4(:,2); % data
    fit.tOut = data4(:,1); % time
    sim = createModel(fit.tOut,model4);
    sim.solverOptions.WRITE_SOLUTION_ALL = true;
    
    % Run
    result = sim.simulate();
%     result = correctOrdering(result);

    column   = permute(result.solution.column, [3 2 1]);
    particle = permute(result.solution.particle, [5 4 3 2 1]);
    flux     = permute(result.solution.flux, [3 2 1]);


    for i=1:sim.model.nComponents
        figure('name', ['Comp ' num2str(i)]);

        % Plot column
        subplot(2,4,1);
        hCol = sim.model.columnLength / sim.discretization.nCellsColumn;
        surf([hCol*0.5:hCol:sim.model.columnLength], result.solution.time, squeeze(column(:,i,:)), 'EdgeColor', 'none');
        xlabel('Position [m]');
        ylabel('Time [s]');
        zlabel('Concentration [mol/m^3]');
        grid on;
        title('Column');

        % Plot first bead of column (axial position), liquid
        subplot(2,4,2);
        hPar = sim.model.particleRadius / sim.discretization.nCellsParticle;
        surf([sim.model.particleRadius-0.5*hPar:-hPar:0], result.solution.time, squeeze(particle(:,1,:,1,i)), 'EdgeColor', 'none');
        xlabel('Position [m]');
        ylabel('Time [s]');
        zlabel('Concentration [mol/m^3]');
        grid on;
        title(['Liquid in bead 1']);

        % Plot mid bead of column (axial position), liquid
        subplot(2,4,3);
        surf([sim.model.particleRadius-0.5*hPar:-hPar:0], result.solution.time, squeeze(particle(:,floor(sim.discretization.nCellsColumn/2),:,1,i)), 'EdgeColor', 'none');
        xlabel('Position [m]');
        ylabel('Time [s]');
        zlabel('Concentration [mol/m^3]');
        grid on;
        title(['Liquid in bead ' num2str(floor(sim.discretization.nCellsColumn/2))]);

        % Plot last besqueeze(result.solution.column(:,i,:))ad of column (axial position), liquid
        subplot(2,4,4);
        surf([sim.model.particleRadius-0.5*hPar:-hPar:0], result.solution.time, squeeze(particle(:,end,:,1,i)), 'EdgeColor', 'none');
        xlabel('Position [m]');
        ylabel('Time [s]');
        zlabel('Concentration [mol/m^3]');
        grid on;
        title(['Liquid in bead ' num2str(sim.discretization.nCellsColumn)]);

        % Plot flux
        subplot(2,4,5);
        surf([hCol*0.5:hCol:sim.model.columnLength], result.solution.time, squeeze(flux(:,i,:)), 'EdgeColor', 'none');
        xlabel('Position [m]');
        ylabel('Time [s]');
        zlabel('Concentration [mol/m^3]');
        grid on;
        title(['Flux in beads']);

        % Plot first bead of column (axial position), solid
        subplot(2,4,6);
        surf([sim.model.particleRadius-0.5*hPar:-hPar:0], result.solution.time, squeeze(particle(:,1,:,2,i)), 'EdgeColor', 'none');
        xlabel('Position [m]');
        ylabel('Time [s]');
        zlabel('Concentration [mol/m^3]');
        grid on;
        title(['Liquid in bead 1']);

        % Plot mid bead of column (axial position), solid
        subplot(2,4,7);
        surf([sim.model.particleRadius-0.5*hPar:-hPar:0], result.solution.time, squeeze(particle(:,floor(sim.discretization.nCellsColumn/2),:,2,i)), 'EdgeColor', 'none');
        xlabel('Position [m]');
        ylabel('Time [s]');
        zlabel('Concentration [mol/m^3]');
        grid on;
        title(['Solid in bead ' num2str(floor(sim.discretization.nCellsColumn/2))]);

        % Plot last bead of column (axial position), solid
        subplot(2,4,8);
        surf([sim.model.particleRadius-0.5*hPar:-hPar:0], result.solution.time, squeeze(particle(:,end,:,2,i)), 'EdgeColor', 'none');
        xlabel('Position [m]');
        ylabel('Time [s]');
        zlabel('Concentration [mol/m^3]');
        grid on;
        title(['Solid in bead ' num2str(sim.discretization.nCellsColumn)]);
    end
end

function result = correctOrdering(result)
% Convert nD-arrays / tensors from row-major to Matlab's column-major
% storage format

    if ~isempty(result.solution.column)
        temp = result.solution.column(:);
        
        nTime = size(result.solution.column,1);
        nComp = size(result.solution.column,2);
        nCol = size(result.solution.column,3);
        
        result.solution.column = zeros([nCol, nComp, nTime]);
        for i = 1:nCol %nTime
            for j = 1:nComp
                idxOffset = (j-1) * nCol + (i-1);
                result.solution.column(i,j,:) = temp(idxOffset+[1:nComp * nCol:length(temp)]);
            end
        end
    end
    
    if ~isempty(result.solution.particle)
        temp = result.solution.particle(:);

        if ndims(result.solution.particle) == 4
            nTime = size(result.solution.particle,1);
            nCol = size(result.solution.particle,2);
            nPar = size(result.solution.particle,3);
            nPhase = size(result.solution.particle,4);
            nComp = 1;
        else
            nTime = size(result.solution.particle,1);
            nCol = size(result.solution.particle,2);
            nPar = size(result.solution.particle,3);
            nPhase = size(result.solution.particle,4);
            nComp = size(result.solution.particle,5);
        end
        
        result.solution.particle = zeros([nComp,nPhase,nPar,nCol,nTime]);
        step = nComp * nPhase * nPar * nCol;
        for i = 1:nComp
            for j = 1:nCol
                for k = 1:nPar
                    for l = 1:nPhase
                        idxOffset = (j-1) * nPhase * nPar * nComp + (k-1) * nPhase * nComp + (l-1)*nComp + (i-1);
                        result.solution.particle(i,l,k,j,:) = temp(idxOffset+[1:step:length(temp)]);
                    end
                end
            end
        end
    end
    
    if ~isempty(result.solution.flux)
        temp = result.solution.flux(:);
        
        nTime = size(result.solution.column,1);
        nComp = size(result.solution.column,2);
        nCol = size(result.solution.column,3);
        
        result.solution.flux = zeros([nCol, nComp, nTime]);
        for i = 1:nCol
            for j = 1:nComp
                idxOffset = (j-1) * nCol + (i-1);
                result.solution.flux(i,j,:) = temp(idxOffset+[1:nComp * nCol:length(temp)]);
            end
        end
    end
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
    model.bindingParameters.SPRSMA_KA1         = [0 4.6987e-13];
    model.bindingParameters.SPRSMA_KD1         = [0 3.2259e-14];
    model.bindingParameters.SPRSMA_NU1         = [0 6.28836];
    model.bindingParameters.SPRSMA_SIGMA1      = [0 1.8499e-8];
    
    model.bindingParameters.SPRSMA_KA2         = [0 5.87287e13];
    model.bindingParameters.SPRSMA_KD2         = [0 2.60843e12];
    model.bindingParameters.SPRSMA_NU2         = [0 34.2227];
    model.bindingParameters.SPRSMA_SIGMA2      = [0 40.6784];
    model.bindingParameters.SPRSMA_K12         = [0.0 2.1856e47];
    model.bindingParameters.SPRSMA_K21         = [0.0 1.682e-23]; 

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
    disc.nCellsColumn   = 50;
    disc.nCellsParticle = 5;
    % Simulator
    sim = Simulator(model, disc);
    sim.solutionTimes = tOut;
    sim.solverOptions.time_integrator.MAX_STEPS = 10000;
    sim.nThreads = 4;
end

% =============================================================================
%  CADET - The Chromatography Analysis and Design Toolkit
%  
%  Copyright © 2008-2015: Eric von Lieres¹, Joel Andersson¹,
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
