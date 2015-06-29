
classdef BiStericMassActionBinding < BindingModel
    %BISTERICMASSACTIONBINDING Represents the BiSMA (Spreading Steric Mass Action) isotherm by providing its parameters and helper functions
    % Provides the parameters of the BiSMA isotherm along with the methods to validate and convert them to
    % the types specified in the CADET file format.
    %
    % Copyright: © 2008-2015 Eric von Lieres, Joel Andersson, Andreas Püttmann, Sebastian Schnittert, Samuel Leweke
    %            See the license note at the end of the file.
    
    methods
        
        function obj = BiStericMassActionBinding()
            %BISTERICMASSACTIONADSORPTION Constructs a BiStericMassAction object
            obj.name = 'BI_STERIC_MASS_ACTION';
            obj.parameters = cell(10,1);

            obj.parameters{1} = BindingModel.createParameter('BISMA_KA1', 'KA1', true);
            obj.parameters{2} = BindingModel.createParameter('BISMA_KD1', 'KD1', true);
            obj.parameters{3} = BindingModel.createParameter('BISMA_KA2', 'KA2', true);
            obj.parameters{4} = BindingModel.createParameter('BISMA_KD2', 'KD2', true);
            obj.parameters{5} = BindingModel.createParameter('BISMA_NU1', 'NU1', true);
            obj.parameters{6} = BindingModel.createParameter('BISMA_NU2', 'NU2', true);
            obj.parameters{7} = BindingModel.createParameter('BISMA_SIGMA1', 'SIGMA1', true);
            obj.parameters{8} = BindingModel.createParameter('BISMA_SIGMA2', 'SIGMA2', true);
            obj.parameters{9} = BindingModel.createParameter('BISMA_LAMBDA1', 'LAMBDA1', false);
            obj.parameters{10} = BindingModel.createParameter('BISMA_LAMBDA2', 'LAMBDA2', false);
        end
                
        function ok = checkParameters(obj, params, nComponents)
            %CHECKPARAMETERS Checks the values of the given parameters for plausibility
            %
            % Parameters: 
            %   - params: Struct with parameters as fields
            %
            % Returns: True if the values are ok, otherwise false

            if (mod(nComponents, 2) ~= 0)
                disp(['For emulated second bound state the number of components must be even (got ' num2str(nComponents) ')'])
                ok = false;
            else
                ok = true;
            end

            nRealComps = nComponents / 2;

            ok = BindingModel.checkNonnegativeVector(params.BISMA_KA1, nRealComps, 'BISMA_KA1') && ok;
            ok = BindingModel.checkNonnegativeVector(params.BISMA_KA2, nRealComps, 'BISMA_KA2') && ok;
            ok = BindingModel.checkNonnegativeVector(params.BISMA_NU1, nRealComps, 'BISMA_NU1') && ok;
            ok = BindingModel.checkNonnegativeVector(params.BISMA_SIGMA1, nRealComps, 'BISMA_SIGMA1') && ok;
            ok = BindingModel.checkNonnegativeVector(params.BISMA_NU2, nRealComps, 'BISMA_NU2') && ok;
            ok = BindingModel.checkNonnegativeVector(params.BISMA_SIGMA2, nRealComps, 'BISMA_SIGMA2') && ok;
            ok = BindingModel.checkNonnegativeVector(params.BISMA_LAMBDA1, 1, 'BISMA_LAMBDA1') && ok;
            ok = BindingModel.checkNonnegativeVector(params.BISMA_LAMBDA2, 1, 'BISMA_LAMBDA2') && ok;
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
