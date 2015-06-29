
classdef MultiStateStericMassActionBinding < BindingModel
    %MULTISTATESTERICMASSACTIONBINDING Represents the Multi-State Steric Mass Action isotherm by providing its parameters and helper functions
    % Provides the parameters of the Multi-State Steric Mass Action isotherm along with the methods to validate and convert them to
    % the types specified in the CADET file format.
    %
    % Copyright: © 2008-2015 Eric von Lieres, Joel Andersson, Andreas Püttmann, Sebastian Schnittert, Samuel Leweke
    %            See the license note at the end of the file.
    
    methods
        
        function obj = MultiStateStericMassActionBinding()
            %MULTISTATESTERICMASSACTIONADSORPTION Constructs a MultiStateStericMassAction object
            obj.name = 'MULTISTATE_STERIC_MASS_ACTION';
            obj.parameters = cell(7,1);

            obj.parameters{1} = BindingModel.createParameter('MSSMA_KA', 'KA', true);
            obj.parameters{2} = BindingModel.createParameter('MSSMA_KD', 'KD', true);
            obj.parameters{3} = BindingModel.createParameter('MSSMA_NU', 'NU', true);
            obj.parameters{4} = BindingModel.createParameter('MSSMA_SIGMA', 'SIGMA', true);
            obj.parameters{5} = BindingModel.createParameter('MSSMA_LAMBDA', 'LAMBDA', false);
            obj.parameters{6} = BindingModel.createParameter('MSSMA_RATE', 'RATE', true);
            obj.parameters{7} = BindingModel.createParameter('MSSMA_STATES', 'STATES', false);
        end

        function ok = checkParameters(obj, params, nComponents)
            %CHECKPARAMETERS Checks the values of the given parameters for plausibility
            %
            % Parameters: 
            %   - params: Struct with parameters as fields
            %
            % Returns: True if the values are ok, otherwise false

            if (params.MSSMA_STATES <= 0) || (params.MSSMA_STATES ~= int32(params.MSSMA_STATES))
                disp(['Number of bound states must be a positive integer (got ' num2str(params.MSSMA_STATES) ')'])
                ok = false;
            end

            if (mod(nComponents - 1, params.MSSMA_STATES) ~= 0)
                disp(['For emulated bound states the number of components must be 1 + nRealComponents * nBoundStates (got ' num2str(nComponents) ')'])
                ok = false;
            else
                ok = true;
            end

            nRealComps = (nComponents - 1) / params.MSSMA_STATES;

            ok = BindingModel.checkNonnegativeVector(params.MSSMA_KA, nRealComps * params.MSSMA_STATES, 'MSSMA_KA') && ok;
            ok = BindingModel.checkNonnegativeVector(params.MSSMA_KD, nRealComps * params.MSSMA_STATES, 'MSSMA_KD') && ok;
            ok = BindingModel.checkNonnegativeVector(params.MSSMA_NU, nRealComps * params.MSSMA_STATES, 'MSSMA_NU') && ok;
            ok = BindingModel.checkNonnegativeVector(params.MSSMA_SIGMA, nRealComps * params.MSSMA_STATES, 'MSSMA_SIGMA') && ok;
            ok = BindingModel.checkNonnegativeVector(params.MSSMA_LAMBDA, 1, 'MSSMA_LAMBDA') && ok;
            ok = BindingModel.checkNonnegativeVector(params.MSSMA_RATE, nRealComps * params.MSSMA_STATES^2, 'MSSMA_RATE') && ok;
        end
        
        function params = convertParametersToFile(obj, params)
            %CONVERTPARAMETERSTOFILE Converts the values of the given parameters to the required types specified in the file format
            %
            % Parameters: 
            %   - params: Struct with parameters as fields
            %
            % Returns: The struct with converted parameter values

            params.MSSMA_STATES = int32(params.MSSMA_STATES);
        end

        function params = convertParametersFromFile(obj, params)
            %CONVERTPARAMETERSFROMFILE Converts the values of the given parameters from the required types specified in the file format to Matlab
            %
            % Parameters: 
            %   - params: Struct with parameters as fields
            %
            % Returns: The struct with converted parameter values

            params.MSSMA_STATES = double(params.MSSMA_STATES);
        end

    end

end

% =============================================================================
%  CADET - The Chromatography Analysis and Design Toolkit
%  
%  Copyright © 2008-2015: Eric von Lieres¹, Joel Andersson,
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
