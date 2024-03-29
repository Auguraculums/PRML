function [result, outParams, res] = fitColumn(fitData, initParams, loBound, upBound, logScale, parameterTransform, quietMode, opt)
%FITCOLUMN Fits a model to the given datasets.
%
%

    if nargin <= 2
        loBound = [];
    end
    if nargin <= 3
        upBound = [];
    end

    if (nargin <= 4) || isempty(logScale)
        logScale = true(size(initParams));
    end
    if numel(logScale) == 1
        logScale = ones(size(initParams)) .* logScale;
    end
    
    customTransform = true;
    if (nargin <= 5) || isempty(parameterTransform)
        customTransform = false;
    end

    if (nargin <= 6) || isempty(quietMode)
        quietMode = false;
    end

    if (nargin <= 7) && islogical(parameterTransform) && (numel(parameterTransform) == 1) && ~isstruct(parameterTransform)
        quietMode = parameterTransform;
        customTransform = false;
        parameterTransform = [];
    end

    enablePlot = ~quietMode;  % Enables or disables plots in each iteration
    enableWeightedPlot = enablePlot;
    
    if customTransform && (~isfield(parameterTransform, 'transformBounds') || isempty(parameterTransform.transformBounds))
        parameterTransform.transformBounds = true;
    end

    % Convert param vector from column (n x 1) to row (1 x n)
    if size(initParams, 1) > 1
        initParams = initParams';
    end

    % Check fitData for errors
    [hasError, fitData, numJoins] = checkInput(fitData);
    if hasError
        disp('Aborting due to errors.');
        outParams = initParams;
        res = -1;
        return;
    end

    % Prepare conversions between global and local parameters in two passes
    % First pass: Resolve linked parameters and build local to global map
    ctrId = 1;
    maxParams = max(arrayfun(@(idx) length(fitData{idx}.sim.sensitivities) - numJoins(idx), 1:length(fitData)));
    localToGlobal = zeros(length(fitData), maxParams);  % Maps (idxFit, idxLocalParam) -> idxGlobalParam
    for i = 1:length(fitData)
        pi = fitData{i}.sim.sensitivities;
        for j = 1:length(pi) - numJoins(i)
            % Get parameter signature
            comp = pi{j}.SENS_COMP;
            sec = pi{j}.SENS_SECTION;
            pn = pi{j}.SENS_NAME;

            % Check if an Id has been assigned to a linked parameter
            if localToGlobal(i, j) <= 0
                linkId = 0;
                if isfield(fitData{i}, 'links') && ~isempty(fitData{i}.links)
                    % Find indices of linked parameters
                    [linkFit, linkParam] = getIndicesOfLinkedParams(fitData, pn, comp, sec, numJoins, fitData{i}.links{j});

                    % Assign ID to linked parameters
                    for lk = 1:length(linkFit)
                        val = localToGlobal(linkFit(lk), linkParam(lk));
                        if val > 0
                            linkId = val;
                            break;
                        end
                    end
                end
                
                % If a linked parameter has an Id, use it
                if linkId > 0
                    localToGlobal(i, j) = linkId;
                end
            end
            
            if localToGlobal(i, j) <= 0
                % Assign an ID
                localToGlobal(i, j) = ctrId;
                ctrId = ctrId + 1;
            end
            
            if isfield(fitData{i}, 'links') && ~isempty(fitData{i}.links)
                % Find indices of linked parameters
                [linkFit, linkParam] = getIndicesOfLinkedParams(fitData, pn, comp, sec, numJoins, fitData{i}.links{j});

                if length(linkFit) ~= length(fitData{i}.links{j})
                    warning('Could not find all linked parameters of fit %d parameter %d (%s) in the other fits', i, j, pn);
                end
                
                % Assign ID to linked parameters
                for lk = 1:length(linkFit)
                    localToGlobal(linkFit(lk), linkParam(lk)) = localToGlobal(i, j);
                end
            end
        end
    end
    
    % Second pass: Build global to local map
    globalToLocalFit = zeros(ctrId - 1, 1);    % Maps idxGlobalParam -> idxFit
    globalToLocalParam = zeros(ctrId - 1, 1);  % Maps idxGlobalParam -> idxLocalParam
    globalIdOrder = [];
    for i = 1:length(fitData)
        
        % Map global to local indices
        for j = 1:length(fitData{i}.sim.sensitivities) - numJoins(i)
            if localToGlobal(i, j) <= 0
                error('Internal error: Detected unmapped parameter.');
            end
            
            if ~any(globalIdOrder == localToGlobal(i, j))
                % Add Id to mapped list
                globalIdOrder = [globalIdOrder, localToGlobal(i, j)];

                % Add mapping info
                globalToLocalFit(localToGlobal(i, j)) = i;
                globalToLocalParam(localToGlobal(i, j)) = j;
            end
        end
    end
    
    % Collect weights
    globalWeights = zeros(length(fitData), 1);
    localWeights = cell(length(fitData), 1);
    hasWeightError = false;
    for i = 1:length(fitData)
        curFit = fitData{i};

        if ~isfield(curFit, 'weight')
            globalWeights(i) = 1;
        else
            globalWeights(i) = curFit.weight;
            if curFit.weight < 0
                disp(['Error in fit ' num2str(i) ' weights: Global weight is negative which is not allowed']);
                hasWeightError = true;
            end
        end
        
        if ~isfield(curFit, 'weightComponent')
            localWeights{i} = ones(1, size(curFit.outMeas, 2));
        else
            localWeights{i} = curFit.weightComponent;
            if length(curFit.weightComponent) ~= size(curFit.outMeas, 2)
                disp(['Error in fit ' num2str(i) ' weights: Number of weights in weightComponent (' num2str(length(curFit.weightComponent)) ') does not match number of observed components (' num2str(size(curFit.outMeas, 2)) ')']);
                hasWeightError = true;
            end
            if any(curFit.weightComponent < 0)
                disp(['Error in fit ' num2str(i) ' weights: Some weights in weightComponent are negative which is not allowed']);
                hasWeightError = true;
            end
        end
    end
    
    if any(~cellfun(@(x) isfield(x, 'weight'), fitData)) && any(cellfun(@(x) isfield(x, 'weight'), fitData))
        hasWeightError = true;
        disp('Error in fit setup: Experiments must either all have weights or none');
    end
    
    % Check parameters and bounds for errors
    [hasError] = checkParamSize(length(globalToLocalFit), length(initParams), length(loBound), length(upBound), length(logScale));
    if hasError || hasWeightError
        disp('Aborting due to errors.');
        outParams = initParams;
        res = -1;
        return;
    end

    % Transform to optimizer space
    if customTransform && ~parameterTransform.postLogTransform
        initParams = parameterTransform.transform(initParams);

        if parameterTransform.transformBounds
            if ~isempty(upBound)
                upBound = parameterTransform.transform(upBound);
            end
            if ~isempty(loBound)
                loBound = parameterTransform.transform(loBound);
            end
        end
    end

    % Convert parameters to log scale
    globalLogScale = zeros(1, length(globalToLocalFit));
    for i = 1:length(globalToLocalFit)
        idxFit = globalToLocalFit(i);
        if logScale(i)

            if initParams(i) == 0
                error('Error: Initial parameter %d must not be zero if using log scale for parameter %d in fit %d!', i, globalToLocalParam(i), idxFit);
            end

            globalLogScale(i) = 1 * (initParams(i) > 0) + (-1) * (initParams(i) < 0);
            initParams(i) = log(globalLogScale(i) .* initParams(i));

            % Convert bounds to log scale
            % Clip bounds to (0, inf) or (-inf, 0)
            if globalLogScale(i) == 1
                if ~isempty(loBound)
                    loBound(i) = max(loBound(i), 0);
                end
                if ~isempty(upBound)
                    upBound(i) = min(upBound(i), inf);
                end
            else
                if ~isempty(loBound)
                    tmp = loBound(i);
                    loBound(i) = max(-upBound(i), 0);
                end
                if ~isempty(upBound)
                    upBound(i) = min(-tmp, inf);
                end
            end

            if ~isempty(loBound)
                loBound(i) = log(loBound(i));
            end
            if ~isempty(upBound)
                upBound(i) = log(upBound(i));
            end
        end
    end
    
    % Transform to optimizer space
    if customTransform && parameterTransform.postLogTransform
        initParams = parameterTransform.transform(initParams);

        if parameterTransform.transformBounds
            if ~isempty(upBound)
                upBound = parameterTransform.transform(upBound);
            end
            if ~isempty(loBound)
                loBound = parameterTransform.transform(loBound);
            end
        end
    end

    % Fit
%    opts = optimset('TolFun', 1e-8, 'TolX', 1e-8, 'MaxIter', 100, 'Diagnostics', 'off');
%    options_monitor = optimset('Display', 'iter');
%    options_lsq = optimset('Jacobian','on');%, 'DerivativeCheck', 'on');
    
%    opts =  optimset(opts, options_lsq);
%    if ~quietMode
%        opts = optimset(opts, options_monitor);
%    end

%     opt = getOpts(initParams);
    
    lastParamsTried = [];

    % Call the optimizer
    try
        [result, cadetparams, res] = PT_mRMMALA(@residual, opt);
    catch exc
        disp('ERROR in lsqnonlin. Probably due to failed CADET simulation.');
        disp(exc.message);
        cadetparams = lastParamsTried;
        res = -1;
    end

    % Transform back to simulator space
    if customTransform && parameterTransform.postLogTransform
        cadetparams = parameterTransform.invTransform(cadetparams);
    end

    % Convert back to normal scale
    idxLog = globalLogScale ~= 0;
    outParams = cadetparams;
    outParams(idxLog) = globalLogScale(idxLog) .* exp(cadetparams(idxLog));

    % Transform back to simulator space
    if customTransform && ~parameterTransform.postLogTransform
        outParams = parameterTransform.invTransform(outParams);
    end

    function [globRes, globJac] = residual(cadetparams)
%    function SSR = residual(cadetparams)
    %RESIDUAL Calculates the residual of the optimization problem
        
        % Save the current parameters 
        lastParamsTried = cadetparams;
        lastParamsTriedExp = cadetparams;

        nf = length(fitData);

        % Transform back to simulator space
        if customTransform && parameterTransform.postLogTransform
            cadetparams = parameterTransform.invTransform(cadetparams);
        end

        % Convert from log scale to normal scale
        idxLog = globalLogScale ~= 0;
        cadetparams(idxLog) = globalLogScale(idxLog) .* exp(cadetparams(idxLog));
        lastParamsTriedExp(idxLog) = globalLogScale(idxLog) .* exp(lastParamsTriedExp(idxLog));

        % Transform back to simulator space
        if customTransform && ~parameterTransform.postLogTransform
            cadetparams = parameterTransform.invTransform(cadetparams);
        end

        globRes = [];
        globJac = [];

        for k = 1:nf

            % Get local params from global params
            idxLocal = localToGlobal(k, :);
            idxLocal = idxLocal(idxLocal > 0);
            localParams = cadetparams(idxLocal);

            [~, idxGlobal] = sort(idxLocal);
            
            curFit = fitData{k};
            
            
            % Simulate with current parameters
            if nargout > 1
                [out, jac] = forwardSim(curFit.tOut, curFit.sim, curFit.task, curFit.joins, localParams);
                
                if size(curFit.outMeas, 2) > 1
                    % Concatenate Jacobians of selected components
                    jacSim = squeeze(mat2cell(jac(:,:,curFit.idxComp), size(jac, 1), size(jac, 2), ones(length(curFit.idxComp), 1)));
                    jacSim = vertcat(jacSim{:});
                else
                    % Sum simulated Jacobians since only sum is observed
                    jacSim = sum(jac(:,:,curFit.idxComp), 3);
                end
            else
                out = forwardSim(curFit.tOut, curFit.sim, curFit.task, curFit.joins, localParams);
            end

            if size(curFit.outMeas, 2) > 1
                % Select observed components
                sim = out(:, curFit.idxComp);

                % Calculate local residual
                r = (sim - curFit.outMeas);
                locWeights = repmat(localWeights{k}, size(r,1), 1);
                r = r .* locWeights;
                r = globalWeights(k) * r(:);
                
                locWeights = locWeights(:);
            else
                % Sum simulated signals since only sum is observed
                sim = sum(out(:,curFit.idxComp), 2);

                % Calculate local residual
                r = globalWeights(k) * (sim - curFit.outMeas);
                
                locWeights = ones(length(r), 1);
            end
            
            if nargout > 1
                % Copy local Jacobian to reordered globalized Jacobian
                jacSimGlobalized = zeros(size(jacSim,1), length(cadetparams));
                jacSimGlobalized(:, idxLocal) = jacSim;

                if customTransform && parameterTransform.postLogTransform
                    jacSimGlobalized = parameterTransform.chainRuleInvTransform(jacSimGlobalized, lastParamsTried);
                end

                % Adapt Jacobian to log scale by chain rule
                idxMask = false(size(idxLog));
                idxMask(idxLocal) = true;
                jacSimGlobalized(:, idxLog & idxMask) = jacSim(:, idxLog(idxLocal)) .* repmat(localParams(idxLog(idxLocal)), size(jacSim,1), 1);

                if customTransform && ~parameterTransform.postLogTransform
                    jacSimGlobalized = parameterTransform.chainRuleInvTransform(jacSimGlobalized, lastParamsTriedExp);
                end

                % Apply weights
                jacSimGlobalized(:, idxLocal) = jacSimGlobalized(:, idxLocal) .* repmat(locWeights, 1, length(idxLocal)) .* globalWeights(k);
                
                % Concatenate local jacobians to obtain global Jacobian
                globJac = [globJac; jacSimGlobalized];
            end

            % Concatenate local residuals to obtain global residual
            globRes = [globRes; r];
            SSR = globRes' * globRes;

            % Plot
            if enablePlot
                
                numObserved = sum(curFit.idxComp);
                if ~all(islogical(curFit.idxComp))
                    numObserved = length(curFit.idxComp);
                end
                
                if (numObserved >= 2) && (size(curFit.outMeas, 2) <= 1)
                    % Plot simulated signals on the left
                    subplot(nf, 2, 2*k-1);

                    plot(curFit.tOut, out(:,curFit.idxComp));
                    grid on;

                    legNames = cell(numObserved, 1);
                    for num = 1:numObserved
                        legNames{num} = ['Comp ' num2str(num)];
                    end

                    handle = legend(legNames);
                    set(handle, 'Box', 'off')
                    set(handle, 'Location','NorthWest');

                    % Plot sum signal and fit on the right
                    subplot(nf, 2, 2*k);
                else
                    % Plot fits in a column from top to bottom
                    subplot(nf, 1, k);
                end
                
                if enableWeightedPlot && (size(curFit.outMeas, 2) > 1)
                    hdMeas = plot(curFit.tOut, repmat(localWeights{k}, size(curFit.outMeas, 1), 1) .* curFit.outMeas);
                    hold on;
                    hdSim = plot(curFit.tOut, repmat(localWeights{k}, size(sim, 1), 1) .* sim);
                else
                    hdMeas = plot(curFit.tOut, curFit.outMeas);
                    hold on;
                    hdSim = plot(curFit.tOut, sim);
                end
                hold off;
                grid on;
                
                if size(curFit.outMeas, 2) <= 1                
                    handle = legend('Meas', 'Sim Sum');
                    set(hdSim(1), 'Color', 'r');
                else
                    legNames = cell(size(curFit.outMeas, 2) * 2, 1);
                    for num = 1:size(curFit.outMeas, 2)
                        legNames{num} = ['Meas Comp ' num2str(num)];
                        legNames{num+size(curFit.outMeas, 2)} = ['Sim Comp ' num2str(num)];
                        
                        % Adapt line styles
                        set(hdSim(num), 'LineStyle', '--', 'LineWidth', 4.0);
                    end
                    
                    handle = legend(legNames);
                end
                
                set(handle, 'Box', 'off')
                set(handle, 'Location','NorthWest');
                
                str = sprintf('%g | ', localParams);
                title(str(1:end-3));
                drawnow;
            end
            
        end
    end
    
end

function [ sol, jac ] = forwardSim(tOut, sim, task, joins, localParams)
%FORWARDSIM Solve General Rate Model using CADET
%

    if ~isempty(joins)
        % Assign value to joined parameters
        nTrueParams = length(localParams);
        localParams = [localParams, zeros(1, length(sim.sensitivities) - length(localParams))];
        for i = 1:length(joins)
            localParams(joins{i}) = localParams(i);
        end
    end
    
    % Simulate
    result = sim.runWithParameters(task, localParams);
    sol = result.solution.outlet;
    jac = result.sensitivity.jacobian;
    
    if ~isempty(joins)
        % Apply chain rule by adding joined parameters
        jacNew = jac(:, 1:nTrueParams, :);
        for i = 1:length(joins)
            jacNew(:, i, :) = jacNew(:, i, :) + sum(jac(:, joins{i}, :), 2);
        end
        jac = jacNew;
    end
end

function [linkFit, linkParam] = getIndicesOfLinkedParams(fitData, pn, comp, sec, numJoins, idxSearch)
%GETINDICESOFLINKEDPARAMS Finds the fit and parameter index of matching linked parameters
    linkFit = [];
    linkParam = [];
    for i = idxSearch
        pi = fitData{i}.sim.sensitivities;
        for j = 1:length(pi) - numJoins(i)
            % Check if parameter matches
            if strcmpi(pn, pi{j}.SENS_NAME) && (comp == pi{j}.SENS_COMP) && (sec == pi{j}.SENS_SECTION)
                % Add indices to list
                linkFit = [linkFit, i];
                linkParam = [linkParam, j];
            end
        end
    end
end

function [hasError, fitData, numJoins] = checkInput(fitData)
%CHECKINPUT Checks the fitData array for errors

    numJoins = zeros(length(fitData), 1);

    hasError = false;
    for i = 1:length(fitData)

        % Check for necessary fields
        hasError = checkForField(fitData{i}, 'tOut', '', 'Field "tOut" is missing from struct', i) | hasError;
        hasError = checkForField(fitData{i}, 'outMeas', '', 'Field "outMeas" is missing from struct', i) | hasError;
        hasError = checkForField(fitData{i}, 'sim', '', 'Simulator is missing from struct', i) | hasError;
        hasError = checkForField(fitData{i}, 'idxComp', '', 'Indices of observed components is missing from struct', i) | hasError;

        % Check and create, if necessary, the task field
        if (~isfield(fitData{i}, 'task') || isempty(fitData{i}.task)) && isfield(fitData{i}, 'sim') && ~isempty(fitData{i}.sim)
            fitData{i}.task = fitData{i}.sim.prepareSimulation();
        else
            if ~isfield(fitData{i}, 'task') || isempty(fitData{i}.task)
                hasError = true;
                disp(['Error in fit ' num2str(i) ': Task field does not exist or is empty']);
            end
        end

        if ~isfield(fitData{i}, 'logScale')
            % Enable logScale by default
            fitData{i}.logScale = true;
        end
        
        if ~isfield(fitData{i}, 'joins')
            % No joins by default
            fitData{i}.joins = [];
        else
            
            % Check the joins
            for j = 1:length(fitData{i}.joins)
                curJoin = fitData{i}.joins{j};
                numJoins(i) = numJoins(i) + length(curJoin);

                if any((curJoin <= length(fitData{i}.sim.sensitivities) - numJoins(i)) | (curJoin > length(fitData{i}.sim.sensitivities)))
                    disp(['Error in fit ' num2str(i) ': Parameter indices of join ' num2str(j) ' are out of range']);
                    hasError = true;
                end
                
                % Check if joined parameters appear in other master
                % parameters
                for k = j+1:length(fitData{i}.joins)
                    if length(unique([curJoin(:); fitData{i}.joins{k}(:)])) ~= length(curJoin) + length(fitData{i}.joins{k})
                        disp(['Error in fit ' num2str(i) ': Joined parameters of parameter ' num2str(j) ' may not be joined to parameter' num2str(k)]);
                        hasError = true;
                    end
                end
            end
            
            % Check number of joins
            if length(fitData{i}.sim.sensitivities) - numJoins(i) ~= length(fitData{i}.joins)
                disp(['Error in fit ' num2str(i) ': Number of joins has to match number of parameters']);
                hasError = true;
            end
        end
        
        if ~isfield(fitData{i}, 'links')
            % No links by default
            fitData{i}.links = repmat({[]}, length(fitData{i}.sim.sensitivities) - numJoins(i), 1);
        else

            % Check number of links
            if length(fitData{i}.links) ~= length(fitData{i}.sim.sensitivities) - numJoins(i)
                disp(['Error in fit ' num2str(i) ': Number of links has to match number of parameters']);
                hasError = true;
            end

            for j = 1:length(fitData{i}.links)
                % Check if links have the correct range
                if any((fitData{i}.links{j} <= 0) | (fitData{i}.links{j} > length(fitData)))
                    disp(['Error in fit ' num2str(i) ': Link indices of parameter ' num2str(j) ' are out of range']);
                    hasError = true;
                end

                % Check if links include the current fit
                if any(fitData{i}.links{j} == i)
                    disp(['Error in fit ' num2str(i) ': Cannot link parameter ' num2str(j) ' to itself']);
                    hasError = true;
                end
            end
            
        end
        
        % Check for consistency
        % Time points should be strictly increasing
        hasError = checkTimePoints(fitData{i}.tOut, 'measurements', i) | hasError;

        if length(fitData{i}.tOut) ~= size(fitData{i}.outMeas, 1)
            disp(['Error in fit ' num2str(i) ' measurements: Number of time points and concentrations does not match']);
            hasError = true;
        end
        
        if size(fitData{i}.outMeas, 2) > 1
            if isfield('idxComp', fitData{i}) && (length(fitData{i}.idxComp) ~= size(fitData{i}.outMeas, 2))
                disp(['Error in fit ' num2str(i) ' measurements: Number of signals and number of indices of observed components do not match']);
                hasError = true;
            end
        end
    end
end

function hasError = checkParamSize(numParams, numInitParams, numLower, numUpper, numLogScale)
%CHECKPARAMSIZE Checks whether the initial params and bounds have the correct number of entries

    hasError = false;

    if numInitParams ~= numParams
        disp(['Error: Fit setup has ' num2str(numParams) ' parameters but ' num2str(numInitParams) ' initial parameters were given']);
        hasError = true;
    end
    
    if numLogScale ~= numParams
        disp(['Error: Fit setup has ' num2str(numParams) ' parameters but ' num2str(numLogScale) ' logScale settings were given']);
        hasError = true;
    end
    
    if (numLower > 0) && (numLower ~= numParams)
        disp(['Error: Fit setup has ' num2str(numParams) ' parameters but ' num2str(numLower) ' lower bounds were given']);
        hasError = true;
    end
    
    if (numUpper > 0) && (numUpper ~= numParams)
        disp(['Error: Fit setup has ' num2str(numParams) ' parameters but ' num2str(numUpper) ' upper bounds were given']);
        hasError = true;
    end
end

function isErroneous = checkForField(sct, fieldName, preText, text, noFit)
%CHECKFORFIELD Checks whether a given struct contains a field
    isErroneous = ~isfield(sct, fieldName);
    if isErroneous
        if ~isempty(preText) && (preText ~= '')
            preText = [' ' preText];
        end
        disp(['Error in fit ' num2str(noFit) preText ':' text]);
    end
end

function isErroneous = checkTimePoints(time, name, noFit)
%CHECKTIMEPOINTS Checks whether time points are monotonically increasing
    isErroneous = false;
    if any(time(2:end) - time(1:end-1) <= 0)
        idx = find(time(2:end) - time(1:end-1) <= 0);
        disp(['Error in fit ' num2str(noFit) ': Times of ' name ' are not strictly increasing. Look at the following indices (1-based):']);
        disp(idx+1);
        isErroneous = true;
    end
end

% =============================================================================
function [result, xValue, yValue] = PT_mRMMALA(FUNC, opt) 
% Parallel-tempering simplified Riemannian manifold Metropolis adjusted Langevin algorithm
    
    startTime = clock;

    if nargin < 2
        error('Objective function for optimization and options for the algorithm are required\n');
    end

%     pre-allocation    
    chain = zeros(opt.Nchain, opt.nCol+1, opt.nsamples);
    Population = cell(opt.Nchain,1);
    sigmaChain = zeros(opt.nsamples, opt.Nchain);
    
    Temperatures = zeros(opt.nsamples, opt.Nchain);
    
    Temperatures(:, 1) = ones(opt.nsamples, 1);
    Temperatures(1, :) = opt.temperature;

%     initialization 
    [states, MetricTensor] = initChainGenerator(FUNC, (1 ./ opt.temperature), opt);       
    
    sigmaSqu  = states(:,opt.nCol+1)/ (opt.nObserv - opt.nCol);
    sigmaSqu0 = sigmaSqu; n0 = 1;

%    main loop     
    for i = 1:opt.nsamples

        beta = 1 ./ Temperatures(i, :);
        
        if i/opt.printint == fix(i/opt.printint)
            fprintf('--- iter: %5d    done: %5d%%    accepted: %5d%% \n', i,...
                fix(i/opt.nsamples*100), fix(opt.accepted/i*100));
        end
        
%         sampler
        [states, MetricTensor, opt] = PT_mRMMALA_sampler(FUNC, states, MetricTensor, sigmaSqu, beta, opt);

%         SWAPS: at predetermined intervals
        if  fix(i/opt.Swapint) == i/opt.Swapint
            a = ceil(rand*opt.Nchain);%  a = randi([1 opt.Nchain]);

            if a == opt.Nchain
                b = 1;
            else
                b = a+1;
            end
	
            SSa = states(a, opt.nCol+1);
            SSb = states(b, opt.nCol+1);	

            rho = (exp(-0.5*(SSa-SSb)/sigmaSqu(a)))^(beta(b)-beta(a));

            if rand < min(rho, 1)
                temp         = states(a, :);
                states(a, :) = states(b, :);
                states(b, :) = temp;
                clear temp;
            end
        end
         
        chain(:,:,i) = states;

%         convergence diagnostics
        if fix(i/opt.convergint) == i/opt.convergint && i > opt.convergint
            R = GelmanR_statistic(i, chain(:,:,1:i), opt);
            if all(R < 1.1) || i == opt.nsamples
                opt.nsamples = i;
                break
            end
        end
        
%         variance of error distribution (sigma) was treated as a parameter
%         to be estimated.
        for k = 1:opt.Nchain
            sigmaSqu(k)  = 1 ./ GammarDistrib(1,1,(n0+opt.nObserv)/2,2 ./(n0 .* sigmaSqu0(k) + chain(k,opt.nCol+1,i)));
            sigmaChain(i,k) = sigmaSqu(k)';
        end
        
%         Temperature dynamics       
        Temperatures = temperatureDynamics(i, states, Temperatures, sigmaSqu, opt); 
        
        
    end  % for i = 1:opt.nsamples
    

    for kk = 1: opt.Nchain
        for ii = 1:opt.nCol+1
            for jj = 1:opt.nsamples
                Population{kk}.samples(jj,ii) = chain(kk, ii, jj);
            end
        end
        Population{kk}.beta = beta(kk);
    end
    
    id = floor(0.3*opt.nsamples);
    plotSamples = zeros(id, opt.nCol+1);    
    
    for k = 1:id
        for j = 1: opt.nCol+1
            plotSamples(k, j) = Population{1}.samples(k+(opt.nsamples-id), j);
        end
    end
    
    
    [yValue, row]         = min(Population{1}.samples(:,opt.nCol+1));
    xValue                = Population{1}.samples(row,1:opt.nCol);
    
    result.NumChain       = opt.Nchain;
    result.optTime        = etime(clock,startTime)/3600;
    result.convergence    = R;
    result.accepted       = fix(opt.accepted/opt.nsamples*100);
    
    result.xValue         = xValue;
    result.yValue         = yValue;
    result.chain          = chain;
    result.index          = opt.nsamples;
    result.population     = Population;
    result.plotSamples    = plotSamples;
    result.sigmaChain     = sigmaChain; 
    result.Temperatures   = Temperatures(1:opt.nsamples, :);
    
    save(sprintf('result_%3d.mat', fix(rand*1000)), 'result');
    fprintf('Markov chain simulation finished and the result saved as result.mat\n');
    
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function y = getParamOptions(options, par, default)

    if isfield(options, par)
        y = getfield(options, par);
    elseif nargin > 2
        y = default;
    else
        error('Need value for parameter %s', par)
    end
    
end    

function [initChain, MetricTensor] = initChainGenerator(FUNC, beta, opt)

    initChain = rand(opt.Nchain, opt.nCol+1);
    MetricTensor = cell(1, opt.Nchain);
    
    for k = 1: opt.nCol
        initChain(:,k) = opt.bounds(1,k) + initChain(:,k) .* (opt.bounds(2,k) - opt.bounds(1,k));
    end
 
    initChain = Constraints(initChain, opt);
    
    evalChain = ParameterTransformation(initChain, opt);
    
    for j = 1: opt.Nchain
        
        [Res, Jac] = feval(FUNC, evalChain(j, 1:opt.nCol));
        Jac = JacobianChainRule(Jac, initChain(j, :), opt);
        
        initChain(j,opt.nCol+1) = Res' * Res;
        Sigma2 = (initChain(j, opt.nCol+1) / (opt.nObserv - opt.nCol));
        
        MetricTensor{j}.G = beta(j) .* (Jac' * (1/Sigma2) * Jac);
        MetricTensor{j}.invG = inv(MetricTensor{j}.G + eye(opt.nCol)*1e-10);
        MetricTensor{j}.GradL = -Jac' * Res / Sigma2;
        
        [R, p] = chol( MetricTensor{j}.invG );
        if p == 0
            MetricTensor{j}.sqrtInvG = R;
        else
            [U,S,V] = svd( MetricTensor{j}.invG );
            S = diag(S); S(S<1e-10) = 1e-10;
            MetricTensor{j}.sqrtInvG = triu( U * diag(sqrt(S)) * V' );
        end  
        
    end
    
end

function [states, MetricTensor, opt] = PT_mRMMALA_sampler(FUNC, states, MetricTensor, sigmaSqu, beta, opt)

    
    for j = 1: opt.Nchain        
        
%         proposal = states(j,1:opt.nCol) + 0.5 * opt.epsilon^2 * (MetricTensor{j}.G \...
%             MetricTensor{j}.GradL)'+ opt.epsilon * randn(1,opt.nCol) * chol(MetricTensor{j}.invG);
                
        proposal = states(j,1:opt.nCol) + 0.5 * opt.epsilon^2 * (MetricTensor{j}.G \...
            MetricTensor{j}.GradL)'+ opt.epsilon * randn(1,opt.nCol) * MetricTensor{j}.sqrtInvG;
            
%         for ii = 1: opt.nCol
%             if proposal(ii) > opt.bounds(2,ii)
%                 proposal(ii) = rand*opt.bounds(2,ii);
%             elseif proposal(ii) < opt.bounds(1,ii)
%                 proposal(ii) = rand*(opt.bounds(1,ii)+1e-5);
%             end
%         end
        
%         DATA.it       = j;
%         DATA.opt      = opt;
%         DATA.states   = states;
%         DATA.G        = MetricTensor{j}.G;
%         DATA.invG     = MetricTensor{j}.invG;
%         DATA.GradL    = MetricTensor{j}.GradL;
%         DATA.cholInvG = MetricTensor{j}.cholInvG;

        proposal = Constraints(proposal, opt);
        
        evalChain = ParameterTransformation(proposal, opt);

        [newRes, newJac] = feval(FUNC, evalChain);
        
        newJac = JacobianChainRule(newJac, proposal, opt);
        
        newSS = newRes' * newRes;               
        SS    = states(j,opt.nCol+1);
        
        rho = (exp( -0.5*(newSS - SS) / sigmaSqu(j)))^beta(j);
        
        if rand <= min(1, rho)
            
            states(j, 1:opt.nCol) = proposal;
            states(j, opt.nCol+1) = newSS;
            
            MetricTensor{j}.G = beta(j) .* (newJac' * (1/sigmaSqu(j)) * newJac);
            MetricTensor{j}.invG = inv(MetricTensor{j}.G + eye(opt.nCol)*1e-10);
            MetricTensor{j}.GradL = -newJac' * newRes / sigmaSqu(j);
            
            [R, p] = chol( MetricTensor{j}.invG );
            if p == 0
                MetricTensor{j}.sqrtInvG = R;
            else
                [U,S,V] = svd( MetricTensor{j}.invG );
                S = diag(S); S(S<1e-10) = 1e-10;
                MetricTensor{j}.sqrtInvG = triu( U * diag(sqrt(S)) * V' );
            end
            
            if j == 1
                opt.accepted = opt.accepted + 1;
            end
            
        end
    end
    
end

function Temperatures = temperatureDynamics(t, states, Temperatures, sigmaSqu, opt)

    t0 = 1e3; nu = 100;
    beta = 1 ./ Temperatures(t, :);

    for i = 2: opt.Nchain
        
        b = i - 1;
        if i == opt.Nchain
            c = 1;
        else
            c = i + 1;
        end
	
        SSa = states(i, opt.nCol+1);
        SSb = states(b, opt.nCol+1);
        SSc = states(c, opt.nCol+1);

        rho_ab = min(1, (exp(-0.5*(SSa-SSb)/sigmaSqu(i)))^(beta(b)-beta(i)) );
        rho_ca = min(1, (exp(-0.5*(SSc-SSa)/sigmaSqu(c)))^(beta(i)-beta(c)) );

        differential = t0/(nu*(t+t0)) * (rho_ab - rho_ca);
    
        Temperatures(t+1, i) = Temperatures(t+1, i-1) + exp(log(Temperatures(t, i)-Temperatures(t, i-1)) + differential);

    end
    

end

function R = GelmanR_statistic(idx, chain, opt)

    % split each chain into half and check all the resulting half-sequences
    index = floor(0.5*idx); 
    eachChain       = zeros(index, opt.nCol);
    betweenMean     = zeros(opt.Nchain, opt.nCol);
    withinVariance  = zeros(opt.Nchain, opt.nCol);   
    
%     mean and variance of each half-sequence chain
    for i = 1: opt.Nchain
        for j = 1: opt.nCol
            for k = 1: index
                eachChain(k,j) = chain(i,j,k+index);
            end
        end
        betweenMean(i,:)    = mean(eachChain);
        withinVariance(i,:) = var(eachChain);
    end
 
%     between-sequence variance
    Sum = 0;
    for i = 1:opt.Nchain
       Sum = Sum + (betweenMean(i,:)-mean(betweenMean)).^2;
    end
    B = Sum ./ (opt.Nchain-1);

%     within-sequence variance
    Sum = 0;
    for i = 1:opt.Nchain
        Sum = Sum + withinVariance(i,:);
    end
    W = Sum ./ opt.Nchain;

%     convergence diagnostics
    R = sqrt(1 + B ./ W);
    
end

function y = GammarDistrib(m,n,a,b)
%GammarDistrib random deviates from gamma distribution
% 
%  GAMMAR_MT(M,N,A,B) returns a M*N matrix of random deviates from the Gamma
%  distribution with shape parameter A and scale parameter B:
%
%  p(x|A,B) = B^-A/gamma(A)*x^(A-1)*exp(-x/B)
%
%  Uses method of Marsaglia and Tsang (2000)

% G. Marsaglia and W. W. Tsang:
% A Simple Method for Generating Gamma Variables,
% ACM Transactions on Mathematical Software, Vol. 26, No. 3,
% September 2000, 363-372.


    if nargin < 4, b=1; end
    y = zeros(m,n);
    for j=1:n
        for i=1:m
            y(i,j) = gammar(a,b);
        end
    end
end
%
function y=gammar(a,b)

    if a<1
        y = gammar(1+a,b)*rand(1)^(1/a);
    else
        d = a-1/3;
        c = 1/sqrt(9*d);
        while(1)
            while(1)
                x = randn(1);
                v = 1+c*x;
                if v > 0, break, end
            end
                v = v^3;
                u = rand(1);
                if u < 1-0.0331*x^4, break, end
                if log(u) < 0.5*x^2+d*(1-v+log(v)), break, end
        end
        
        y = b*d*v;
        
    end
    
end

function evalChain = ParameterTransformation(initChain, opt)

    evalChain = initChain(:, 1:opt.nCol);
    
    for i = opt.idxParam
%         evalChain(:, i) = log( exp(evalChain(:, i+1)) .* exp(evalChain(:, i)) );
        evalChain(:, i) = evalChain(:, i+1) .* evalChain(:, i);
    end

end

function Jac_theta = JacobianChainRule(Jac_psi, parameter, opt)

    nabla_psi = eye(opt.nCol);
    
    for i = opt.idxParam
        nabla_psi(i, i) = parameter(i+1);
        nabla_psi(i, i+1) = parameter(i);
    end
    
    Jac_theta = Jac_psi * nabla_psi;

end

function initChain = Constraints(initChain, opt)
    
    [R, ~] = size(initChain);
    
    for i = 1: R
        for j = 1: opt.nCol
            if initChain(i,j) > opt.bounds(2,j) || initChain(i,j) < opt.bounds(1,j)
                initChain(i,j) = opt.bounds(1,j) + (opt.bounds(2,j)-opt.bounds(1,j))*rand;
            end
        end
    end


    for i = 1:R
        if initChain(i, opt.idxConst(1)) > initChain(i, opt.idxConst(2))
            initChain(i, opt.idxConst(1)) = initChain(i, opt.idxConst(2)) * rand;
        end
    end
%     nu_1 < nu_2
    for i = 1:R
        if initChain(i, opt.idxConst(1)+1) > initChain(i, opt.idxConst(2)+1)
            initChain(i, opt.idxConst(1)+1) = initChain(i, opt.idxConst(2)+1) * rand;
        end
    end
%     sigma_1 < sigma_2

%          
%    for j = opt.idxConst(1)-1
%         for i = 1:R
%             if initChain(i,j) > initChain(i, opt.idxConst(2)) ...
%                     || initChain(i, j) < initChain(i, opt.idxConst(1))
%                 initChain(i,j) = initChain(i, opt.idxConst(1)) + ...
%                     ( initChain(i,opt.idxConst(2)) - initChain(i,opt.idxConst(1)) ) * rand;
%             end
%         end
%    end
% %     sigma_1 < nu_1 < nu_2
%      
%    for j = opt.idxConst(2)+1
%         for i = 1:R
%             if initChain(i, j) > initChain(i, opt.idxConst(2)) ...
%                     || initChain(i, j) < initChain(i, opt.idxConst(1))
%                 initChain(i, j) = initChain(i, opt.idxConst(1)) + ...
%                     ( initChain(i,opt.idxConst(2)) - initChain(i,opt.idxConst(1)) ) * rand;
%             end
%         end
%    end
%     sigma_1 < sigma_2 < nu_2

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