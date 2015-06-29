
classdef SimpleMultiStateStericMassActionBinding < BindingModel
    %SIMPLEMULTISTATESTERICMASSACTIONBINDING Represents the Simplified Multi-State Steric Mass Action isotherm by providing its parameters and helper functions
    % Provides the parameters of the Simplified Multi-State Steric Mass Action isotherm along with the methods to validate and convert them to
    % the types specified in the CADET file format.
    %
    % Copyright: © 2008-2015 Eric von Lieres, Joel Andersson, Andreas Püttmann, Sebastian Schnittert, Samuel Leweke
    %            See the license note at the end of the file.
    
    methods
        
        function obj = SimpleMultiStateStericMassActionBinding()
            %SIMPLEMULTISTATESTERICMASSACTIONADSORPTION Constructs a SimpleMultiStateStericMassAction object
            obj.name = 'SIMPLE_MULTISTATE_STERIC_MASS_ACTION';
            obj.parameters = cell(16,1);

            obj.parameters{1} = BindingModel.createParameter('SMSSMA_KA', 'KA', true);
            obj.parameters{2} = BindingModel.createParameter('SMSSMA_KD', 'KD', true);
            obj.parameters{3} = BindingModel.createParameter('SMSSMA_NU_MIN', 'NU_MIN', true);
            obj.parameters{4} = BindingModel.createParameter('SMSSMA_NU_MAX', 'NU_MAX', true);
            obj.parameters{5} = BindingModel.createParameter('SMSSMA_NU_QUAD', 'NU_QUAD', true);
            obj.parameters{6} = BindingModel.createParameter('SMSSMA_SIGMA_MIN', 'SIGMA_MIN', true);
            obj.parameters{7} = BindingModel.createParameter('SMSSMA_SIGMA_MAX', 'SIGMA_MAX', true);
            obj.parameters{8} = BindingModel.createParameter('SMSSMA_SIGMA_QUAD', 'SIGMA_QUAD', true);
            obj.parameters{9} = BindingModel.createParameter('SMSSMA_KSW', 'KSW', true);
            obj.parameters{10} = BindingModel.createParameter('SMSSMA_KSW_LIN', 'KSW_LIN', true);
            obj.parameters{11} = BindingModel.createParameter('SMSSMA_KSW_QUAD', 'KSW_QUAD', true);
            obj.parameters{12} = BindingModel.createParameter('SMSSMA_KWS', 'KWS', true);
            obj.parameters{13} = BindingModel.createParameter('SMSSMA_KWS_LIN', 'KWS_LIN', true);
            obj.parameters{14} = BindingModel.createParameter('SMSSMA_KWS_QUAD', 'KWS_QUAD', true);
            obj.parameters{15} = BindingModel.createParameter('SMSSMA_LAMBDA', 'LAMBDA', false);
            obj.parameters{16} = BindingModel.createParameter('SMSSMA_STATES', 'STATES', false);
        end

        function ok = checkParameters(obj, params, nComponents)
            %CHECKPARAMETERS Checks the values of the given parameters for plausibility
            %
            % Parameters: 
            %   - params: Struct with parameters as fields
            %
            % Returns: True if the values are ok, otherwise false

            if (params.SMSSMA_STATES <= 0) || (params.SMSSMA_STATES ~= int32(params.SMSSMA_STATES))
                disp(['Number of bound states must be a positive integer (got ' num2str(params.SMSSMA_STATES) ')'])
                ok = false;
            end

            if (mod(nComponents - 1, params.SMSSMA_STATES) ~= 0)
                disp(['For emulated bound states the number of components must be 1 + nRealComponents * nBoundStates (got ' num2str(nComponents) ')'])
                ok = false;
            else
                ok = true;
            end

            nRealComps = (nComponents - 1) / params.SMSSMA_STATES;

            ok = BindingModel.checkNonnegativeVector(params.SMSSMA_KA, nRealComps * params.SMSSMA_STATES, 'SMSSMA_KA') && ok;
            ok = BindingModel.checkNonnegativeVector(params.SMSSMA_KD, nRealComps * params.SMSSMA_STATES, 'SMSSMA_KD') && ok;
            ok = BindingModel.checkNonnegativeVector(params.SMSSMA_NU_MIN, nRealComps, 'SMSSMA_NU_MIN') && ok;
            ok = BindingModel.checkNonnegativeVector(params.SMSSMA_NU_MAX, nRealComps, 'SMSSMA_NU_MAX') && ok;

            if (length(params.SMSSMA_NU_QUAD(:)) ~= nRealComps)
                ok = false;
                disp(['Error: SMSSMA_NU_QUAD has to be a vector of length ' num2str(nRealComps)]);
            end

            ok = BindingModel.checkNonnegativeVector(params.SMSSMA_SIGMA_MIN, nRealComps, 'SMSSMA_SIGMA_MIN') && ok;
            ok = BindingModel.checkNonnegativeVector(params.SMSSMA_SIGMA_MAX, nRealComps, 'SMSSMA_SIGMA_MAX') && ok;
            
            if (length(params.SMSSMA_SIGMA_QUAD(:)) ~= nRealComps)
                ok = false;
                disp(['Error: SMSSMA_SIGMA_QUAD has to be a vector of length ' num2str(nRealComps)]);
            end

            ok = BindingModel.checkNonnegativeVector(params.SMSSMA_KSW, nRealComps, 'SMSSMA_KSW') && ok;
            if (length(params.SMSSMA_KSW_LIN(:)) ~= nRealComps)
                ok = false;
                disp(['Error: SMSSMA_KSW_LIN has to be a vector of length ' num2str(nRealComps)]);
            end
            if (length(params.SMSSMA_KSW_QUAD(:)) ~= nRealComps)
                ok = false;
                disp(['Error: SMSSMA_KSW_QUAD has to be a vector of length ' num2str(nRealComps)]);
            end

            ok = BindingModel.checkNonnegativeVector(params.SMSSMA_KWS, nRealComps, 'SMSSMA_KWS') && ok;
            if (length(params.SMSSMA_KWS_LIN(:)) ~= nRealComps)
                ok = false;
                disp(['Error: SMSSMA_KWS_LIN has to be a vector of length ' num2str(nRealComps)]);
            end
            if (length(params.SMSSMA_KWS_QUAD(:)) ~= nRealComps)
                ok = false;
                disp(['Error: SMSSMA_KWS_QUAD has to be a vector of length ' num2str(nRealComps)]);
            end

            ok = BindingModel.checkNonnegativeVector(params.SMSSMA_LAMBDA, 1, 'SMSSMA_LAMBDA') && ok;
        end
        
        function params = convertParametersToFile(obj, params)
            %CONVERTPARAMETERSTOFILE Converts the values of the given parameters to the required types specified in the file format
            %
            % Parameters: 
            %   - params: Struct with parameters as fields
            %
            % Returns: The struct with converted parameter values

            params.SMSSMA_STATES = int32(params.SMSSMA_STATES);
        end

        function params = convertParametersFromFile(obj, params)
            %CONVERTPARAMETERSFROMFILE Converts the values of the given parameters from the required types specified in the file format to Matlab
            %
            % Parameters: 
            %   - params: Struct with parameters as fields
            %
            % Returns: The struct with converted parameter values

            params.SMSSMA_STATES = double(params.SMSSMA_STATES);
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
