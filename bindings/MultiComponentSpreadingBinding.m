
classdef MultiComponentSpreadingBinding < BindingModel
    %MULTICOMPONENTSPREADINGBINDING Represents the Multi Component Spreading isotherm by providing its parameters and helper functions
    % Provides the parameters of the Multi Component Spreading isotherm along with the methods to validate and convert them to
    % the types specified in the CADET file format.
    %
    % Copyright: © 2008-2015 Eric von Lieres, Joel Andersson, Andreas Püttmann, Sebastian Schnittert, Samuel Leweke
    %            See the license note at the end of the file.
    
    methods
        
        function obj = MultiComponentSpreadingBinding()
            %MULTICOMPONENTSPREADINGADSORPTION Constructs a MultiComponentSpreading object
            obj.name = 'MULTI_COMPONENT_SPREADING';
            obj.parameters = cell(8,1);

            obj.parameters{1} = BindingModel.createParameter('MCSPR_KA1', 'KA1', true);
            obj.parameters{2} = BindingModel.createParameter('MCSPR_KD1', 'KD1', true);
            obj.parameters{3} = BindingModel.createParameter('MCSPR_KA2', 'KA2', true);
            obj.parameters{4} = BindingModel.createParameter('MCSPR_KD2', 'KD2', true);
            obj.parameters{5} = BindingModel.createParameter('MCSPR_K12', 'K12', true);
            obj.parameters{6} = BindingModel.createParameter('MCSPR_K21', 'K21', true);
            obj.parameters{7} = BindingModel.createParameter('MCSPR_QMAX1', 'QMAX1', true);
            obj.parameters{8} = BindingModel.createParameter('MCSPR_QMAX2', 'QMAX2', true);
        end
                
        function ok = checkParameters(obj, params, nComponents)
            %CHECKPARAMETERS Checks the values of the given parameters for plausibility
            %
            % Parameters: 
            %   - params: Struct with parameters as fields
            %
            % Returns: True if the values are ok, otherwise false

            if (mod(nComponents, 2) ~= 0)
                disp(['For emulated second bound state the number of components must be divisible by 2 (got ' num2str(nComponents) ')'])
                ok = false;
            else
                ok = true;
            end

            ok = BindingModel.checkPositiveVector(params.MCSPR_QMAX1, nComponents / 2, 'MCSPR_QMAX1') && ok;
            ok = BindingModel.checkPositiveVector(params.MCSPR_QMAX2, nComponents / 2, 'MCSPR_QMAX2') && ok;
            ok = BindingModel.checkNonnegativeVector(params.MCSPR_KA1, nComponents / 2, 'MCSPR_KA1') && ok;
            ok = BindingModel.checkNonnegativeVector(params.MCSPR_KD1, nComponents / 2, 'MCSPR_KD1') && ok;
            ok = BindingModel.checkNonnegativeVector(params.MCSPR_KA2, nComponents / 2, 'MCSPR_KA2') && ok;
            ok = BindingModel.checkNonnegativeVector(params.MCSPR_KD2, nComponents / 2, 'MCSPR_KD2') && ok;
            ok = BindingModel.checkNonnegativeVector(params.MCSPR_K12, nComponents / 2, 'MCSPR_K12') && ok;
            ok = BindingModel.checkNonnegativeVector(params.MCSPR_K21, nComponents / 2, 'MCSPR_K21') && ok;
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
